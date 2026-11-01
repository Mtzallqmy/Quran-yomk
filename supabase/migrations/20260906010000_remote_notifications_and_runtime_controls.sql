-- Remote notifications are delivered by a trusted Edge Function. Client roles
-- intentionally receive no direct table or function access in this migration.
insert into app.permissions (code, description) values
  ('notifications.read', 'Read notifications and delivery results'),
  ('notifications.send', 'Create and send notifications'),
  ('notifications.schedule', 'Schedule notifications'),
  ('notifications.cancel', 'Cancel scheduled notifications'),
  ('devices.read', 'Read bounded device metadata'),
  ('runtime_config.read', 'Read runtime configuration'),
  ('runtime_config.write', 'Manage whitelisted runtime configuration')
on conflict (code) do update set description=excluded.description;

insert into app.role_permissions (role_id,permission_id)
select r.id,p.id from app.roles r cross join app.permissions p
where r.code='SUPER_ADMIN' and p.code in (
  'notifications.read','notifications.send','notifications.schedule',
  'notifications.cancel','devices.read','runtime_config.read','runtime_config.write'
) on conflict do nothing;

create or replace function app.bootstrap_primary_super_admin()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if lower(new.email)='mtzallqmy@gmail.com' then
    insert into app.administrators(id,display_name,is_active) values(new.id,'Primary administrator',true)
    on conflict(id) do update set is_active=true,deleted_at=null;
    insert into app.administrator_roles(administrator_id,role_id)
    select new.id,id from app.roles where code='SUPER_ADMIN' on conflict do nothing;
  end if;
  return new;
end $$;
revoke all on function app.bootstrap_primary_super_admin() from public,anon,authenticated;
drop trigger if exists tarteel_primary_super_admin on auth.users;
create trigger tarteel_primary_super_admin after insert or update of email on auth.users
for each row execute function app.bootstrap_primary_super_admin();
insert into app.administrators(id,display_name,is_active)
select id,'Primary administrator',true from auth.users where lower(email)='mtzallqmy@gmail.com'
on conflict(id) do update set is_active=true,deleted_at=null;
insert into app.administrator_roles(administrator_id,role_id)
select u.id,r.id from auth.users u cross join app.roles r
where lower(u.email)='mtzallqmy@gmail.com' and r.code='SUPER_ADMIN' on conflict do nothing;

create table app.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  installation_id uuid not null unique,
  installation_secret_hash text not null check(length(installation_secret_hash)=64),
  fcm_token text not null unique check(length(fcm_token) between 20 and 4096),
  platform text not null check(platform in ('android','ios')),
  app_version text not null check(length(app_version) between 1 and 40),
  locale text not null default 'ar' check(length(locale) between 2 and 16),
  timezone text not null default 'Asia/Aden' check(length(timezone) between 1 and 80),
  notifications_enabled boolean not null default true,
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app.notification_preferences (
  device_id uuid primary key references app.user_devices(id) on delete cascade,
  admin_announcements boolean not null default true,
  content_updates boolean not null default true,
  quran_content boolean not null default true,
  radio boolean not null default true,
  prayer_related boolean not null default true,
  adhkar boolean not null default true,
  important_system boolean not null default true,
  updated_at timestamptz not null default now()
);

create table app.admin_notifications (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(title) between 1 and 120),
  body text not null check(length(body) between 1 and 500),
  type text not null check(type in ('admin_announcements','content_updates','quran_content','radio','prayer_related','adhkar','important_system')),
  payload jsonb not null default '{}'::jsonb check(jsonb_typeof(payload)='object' and pg_column_size(payload)<=4096),
  target_type text not null check(target_type in ('all','user','device','segment')),
  target_filters jsonb not null default '{}'::jsonb check(jsonb_typeof(target_filters)='object' and pg_column_size(target_filters)<=4096),
  scheduled_at timestamptz,
  status text not null default 'draft' check(status in ('draft','scheduled','sending','sent','partially_failed','failed','cancelled')),
  idempotency_key text not null unique check(length(idempotency_key) between 8 and 200),
  created_by uuid not null references app.administrators(id) on delete restrict,
  approved_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(),
  sent_at timestamptz,
  updated_at timestamptz not null default now()
);

create table app.notification_deliveries (
  id bigint generated always as identity primary key,
  notification_id uuid not null references app.admin_notifications(id) on delete cascade,
  device_id uuid not null references app.user_devices(id) on delete cascade,
  status text not null default 'pending' check(status in ('pending','accepted','failed','revoked')),
  provider_message_id text check(provider_message_id is null or length(provider_message_id)<=512),
  attempted_at timestamptz,
  provider_metadata jsonb not null default '{}'::jsonb check(pg_column_size(provider_metadata)<=2048),
  error_code text check(error_code is null or error_code ~ '^[A-Z0-9_]{1,80}$'),
  retry_count smallint not null default 0 check(retry_count between 0 and 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(notification_id,device_id)
);

create table app.in_app_announcements (
  id uuid primary key default gen_random_uuid(),
  title text not null check(length(title) between 1 and 120),
  body text not null check(length(body) between 1 and 500),
  priority smallint not null default 0 check(priority between 0 and 100),
  dismissible boolean not null default true,
  deep_link text check(deep_link is null or deep_link in ('/home','/prayer-times','/adhkar','/radio','/reciters','/quran','/library','/custom-reminders')),
  start_at timestamptz not null,
  end_at timestamptz not null check(end_at>start_at),
  is_active boolean not null default true,
  created_by uuid not null references app.administrators(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index user_devices_active_idx on app.user_devices(last_seen_at desc) where revoked_at is null and notifications_enabled;
create index user_devices_user_idx on app.user_devices(user_id) where revoked_at is null;
create index admin_notifications_due_idx on app.admin_notifications(scheduled_at) where status='scheduled';
create index notification_deliveries_status_idx on app.notification_deliveries(notification_id,status);
create index announcements_active_idx on app.in_app_announcements(priority desc,start_at,end_at) where is_active;

create trigger user_devices_updated_at before update on app.user_devices for each row execute function app.set_updated_at();
create trigger notification_preferences_updated_at before update on app.notification_preferences for each row execute function app.set_updated_at();
create trigger admin_notifications_updated_at before update on app.admin_notifications for each row execute function app.set_updated_at();
create trigger notification_deliveries_updated_at before update on app.notification_deliveries for each row execute function app.set_updated_at();
create trigger in_app_announcements_updated_at before update on app.in_app_announcements for each row execute function app.set_updated_at();

alter table app.user_devices enable row level security;
alter table app.notification_preferences enable row level security;
alter table app.admin_notifications enable row level security;
alter table app.notification_deliveries enable row level security;
alter table app.in_app_announcements enable row level security;

revoke all on app.user_devices,app.notification_preferences,app.admin_notifications,app.notification_deliveries,app.in_app_announcements from public,anon,authenticated;
grant select,insert,update,delete on app.user_devices,app.notification_preferences,app.admin_notifications,app.notification_deliveries,app.in_app_announcements to service_role;
grant usage,select on sequence app.notification_deliveries_id_seq to service_role;

create or replace function app.claim_due_notifications(p_limit integer default 10)
returns setof app.admin_notifications
language sql volatile security definer set search_path='' as $$
  update app.admin_notifications n set status='sending',updated_at=now()
  where n.id in (
    select id from app.admin_notifications
    where status='scheduled' and scheduled_at<=now()
    order by scheduled_at,id for update skip locked limit least(greatest(p_limit,1),50)
  ) returning n.*;
$$;

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
      when 'important_system' then coalesce(p.important_system,true)
      else false end
  on conflict(notification_id,device_id) do nothing;
  get diagnostics inserted=row_count;
  return inserted;
exception when invalid_text_representation then
  raise exception 'invalid target identifier';
end $$;

revoke all on function app.claim_due_notifications(integer),app.prepare_notification_deliveries(uuid) from public,anon,authenticated;
grant execute on function app.claim_due_notifications(integer),app.prepare_notification_deliveries(uuid) to service_role;

insert into app.app_config(key,value,value_type,is_public,description) values
  ('prayer_features_enabled','true','BOOLEAN',true,'Enable prayer features'),
  ('adhkar_enabled','true','BOOLEAN',true,'Enable Adhkar features'),
  ('maintenance_mode','false','BOOLEAN',true,'Enable maintenance notice'),
  ('maintenance_message','""','STRING',true,'Bounded maintenance notice'),
  ('announcement_banner','""','STRING',true,'Bounded in-app announcement'),
  ('recommended_android_version','"0.0.0"','STRING',true,'Recommended Android version')
on conflict(key) do nothing;

create or replace function app.update_runtime_config(p_updates jsonb,p_actor uuid,p_request_id uuid)
returns setof app.app_config language plpgsql security invoker set search_path='' as $$
declare affected integer; expected integer;
begin
  if not (app.managed_radio_authorized(p_actor,'runtime_config.write') or app.managed_radio_authorized(p_actor,'settings.write')) then
    raise exception 'Settings permission required' using errcode='42501';
  end if;
  if jsonb_typeof(p_updates) is distinct from 'object' or p_updates='{}'::jsonb then raise exception 'Invalid runtime configuration'; end if;
  if exists(select 1 from jsonb_object_keys(p_updates) k where k<>all(array[
    'radio_enabled','virtual_radio_enabled','virtual_radio_show_next_program','virtual_radio_allow_degraded_fallback',
    'virtual_radio_max_failed_sources','offline_downloads_enabled','mushaf_tajweed_enabled','elysia_api_enabled',
    'reciters_page_size','home_sections','content_manifest_version','content_manifest','minimum_android_version',
    'recommended_android_version','latest_android_version','prayer_features_enabled','adhkar_enabled',
    'maintenance_mode','maintenance_message','announcement_banner'])) then raise exception 'Runtime config key is not allowed'; end if;
  select count(*) into expected from jsonb_object_keys(p_updates);
  return query update app.app_config c set value=j.value,updated_by=p_actor from jsonb_each(p_updates) j where c.key=j.key returning c.*;
  get diagnostics affected=row_count;
  if affected<>expected then raise exception 'Runtime config key is not seeded'; end if;
  insert into app.audit_logs(actor_id,action,resource_type,request_id,metadata)
  values(p_actor,'runtime_config.update','app_config',p_request_id,jsonb_build_object('keys',(select jsonb_agg(k) from jsonb_object_keys(p_updates) k)));
end;
$$;
revoke all on function app.update_runtime_config(jsonb,uuid,uuid) from public,anon,authenticated;
grant execute on function app.update_runtime_config(jsonb,uuid,uuid) to service_role;

-- Scheduling remains server-side. The job is inert until the owner stores the
-- dispatch URL and random bearer token in Vault using these exact names.
create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;
do $$ begin
  if exists(select 1 from cron.job where jobname='tarteel-notification-dispatch') then
    perform cron.unschedule('tarteel-notification-dispatch');
  end if;
  perform cron.schedule('tarteel-notification-dispatch','* * * * *',$job$
    select net.http_post(
      url:=u.decrypted_secret,
      headers:=jsonb_build_object('content-type','application/json','authorization','Bearer '||t.decrypted_secret),
      body:='{}'::jsonb,
      timeout_milliseconds:=15000
    ) from vault.decrypted_secrets u cross join vault.decrypted_secrets t
    where u.name='notification_dispatch_url' and t.name='notification_cron_secret'
  $job$);
end $$;
