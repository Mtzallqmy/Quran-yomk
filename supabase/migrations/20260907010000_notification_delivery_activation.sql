-- Activate server-side notification dispatch without placing a privileged key
-- in any client. The cron bearer is generated and retained in Vault.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

alter table app.notification_preferences
  add column memorization_review boolean not null default true,
  add column personal_reminders boolean not null default true;

alter table app.admin_notifications drop constraint admin_notifications_type_check;
alter table app.admin_notifications add constraint admin_notifications_type_check
  check(type in ('admin_announcements','content_updates','quran_content','radio',
    'prayer_related','adhkar','memorization_review','personal_reminders',
    'important_system'));

create or replace function app.prepare_notification_deliveries(p_notification_id uuid)
returns integer language plpgsql volatile security definer set search_path='' as $$
declare n app.admin_notifications; inserted integer;
begin
  select * into n from app.admin_notifications where id=p_notification_id and status='sending' for update;
  if n.id is null then raise exception 'notification is not sending'; end if;
  insert into app.notification_deliveries(notification_id,device_id)
  select n.id,d.id from app.user_devices d
  left join app.notification_preferences p on p.device_id=d.id
  where d.revoked_at is null and d.notifications_enabled
    and case n.target_type
      when 'all' then true
      when 'user' then d.user_id=(n.target_filters->>'user_id')::uuid
      when 'device' then d.id=(n.target_filters->>'device_id')::uuid
      when 'segment' then
        (not(n.target_filters?'platform') or d.platform=n.target_filters->>'platform') and
        (not(n.target_filters?'locale') or d.locale=n.target_filters->>'locale') and
        (not(n.target_filters?'app_version') or d.app_version=n.target_filters->>'app_version')
      else false end
    and case n.type
      when 'admin_announcements' then coalesce(p.admin_announcements,true)
      when 'content_updates' then coalesce(p.content_updates,true)
      when 'quran_content' then coalesce(p.quran_content,true)
      when 'radio' then coalesce(p.radio,true)
      when 'prayer_related' then coalesce(p.prayer_related,true)
      when 'adhkar' then coalesce(p.adhkar,true)
      when 'memorization_review' then coalesce(p.memorization_review,true)
      when 'personal_reminders' then coalesce(p.personal_reminders,true)
      when 'important_system' then coalesce(p.important_system,true)
      else false end
  on conflict(notification_id,device_id) do nothing;
  get diagnostics inserted=row_count;
  return inserted;
exception when invalid_text_representation then
  raise exception 'invalid target identifier';
end $$;

revoke all on function app.prepare_notification_deliveries(uuid) from public,anon,authenticated;
grant execute on function app.prepare_notification_deliveries(uuid) to service_role;

do $$
begin
  if not exists(select 1 from vault.secrets where name='notification_dispatch_url') then
    perform vault.create_secret(
      'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/notifications/dispatch',
      'notification_dispatch_url'
    );
  end if;
  if not exists(select 1 from vault.secrets where name='notification_cron_secret') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32),'hex'),
      'notification_cron_secret'
    );
  end if;
end;
$$;

create or replace function app.authorize_notification_dispatch(p_token text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(
    length(p_token)=64 and exists(
      select 1
      from vault.decrypted_secrets
      where name='notification_cron_secret'
        and extensions.digest(decrypted_secret,'sha256')=extensions.digest(p_token,'sha256')
    ),
    false
  );
$$;

create or replace function app.claim_notification(p_notification_id uuid)
returns setof app.admin_notifications
language sql
volatile
security definer
set search_path=''
as $$
  update app.admin_notifications n
  set status='sending',updated_at=now()
  where n.id=p_notification_id and n.status='scheduled' and n.scheduled_at<=now()
  returning n.*;
$$;

create or replace function app.notification_system_status()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'scheduler_active', exists(
      select 1 from cron.job where jobname='tarteel-notification-dispatch' and active
    ),
    'dispatch_url_configured', exists(
      select 1 from vault.secrets where name='notification_dispatch_url'
    ),
    'cron_secret_configured', exists(
      select 1 from vault.secrets where name='notification_cron_secret'
    )
  );
$$;

revoke all on function app.authorize_notification_dispatch(text),
  app.claim_notification(uuid),app.notification_system_status()
from public,anon,authenticated;
grant execute on function app.authorize_notification_dispatch(text),
  app.claim_notification(uuid),app.notification_system_status()
to service_role;

do $$
begin
  if exists(select 1 from cron.job where jobname='tarteel-notification-dispatch') then
    perform cron.unschedule('tarteel-notification-dispatch');
  end if;
  perform cron.schedule('tarteel-notification-dispatch','* * * * *',$job$
    select net.http_post(
      url:=u.decrypted_secret,
      headers:=jsonb_build_object(
        'content-type','application/json',
        'authorization','Bearer '||t.decrypted_secret
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=15000
    )
    from vault.decrypted_secrets u
    cross join vault.decrypted_secrets t
    where u.name='notification_dispatch_url'
      and t.name='notification_cron_secret'
  $job$);
end;
$$;
