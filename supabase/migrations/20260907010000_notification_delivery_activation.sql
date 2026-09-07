-- Activate server-side notification dispatch without placing a privileged key
-- in any client. The cron bearer is generated and retained in Vault.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

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
