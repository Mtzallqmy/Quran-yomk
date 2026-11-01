-- FCM acceptance is not proof that Android displayed a notification. Keep
-- each application lifecycle milestone independently timestamped.
alter table app.notification_deliveries
  add column accepted_at timestamptz,
  add column received_at timestamptz,
  add column displayed_at timestamptz,
  add column opened_at timestamptz,
  drop constraint notification_deliveries_status_check;

update app.notification_deliveries
set status = case status
  when 'pending' then 'scheduled'
  when 'accepted' then 'accepted_by_fcm'
  else status
end,
accepted_at = case
  when status = 'accepted' then coalesce(attempted_at, updated_at)
  else accepted_at
end;

alter table app.notification_deliveries
  add constraint notification_deliveries_status_check check (
    status in (
      'scheduled', 'processing', 'accepted_by_fcm', 'received_by_app',
      'displayed', 'opened', 'failed', 'revoked'
    )
  ),
  alter column status set default 'scheduled',
  add constraint notification_deliveries_receipt_order_check check (
    (displayed_at is null or received_at is null or displayed_at >= received_at)
    and (opened_at is null or displayed_at is null or opened_at >= displayed_at)
  );

create index notification_deliveries_device_idx
  on app.notification_deliveries(device_id);

alter table app.in_app_announcements
  drop constraint in_app_announcements_deep_link_check,
  add constraint in_app_announcements_deep_link_check check (
    deep_link is null or deep_link in (
      '/', '/home', '/prayer-times', '/adhkar', '/radio', '/reciters',
      '/quran', '/library', '/custom-reminders'
    )
  );

insert into app.permissions(code, description) values
  ('announcements.read', 'Read in-app announcement campaigns'),
  ('announcements.write', 'Create and manage in-app announcement campaigns')
on conflict(code) do update set description = excluded.description;

insert into app.role_permissions(role_id, permission_id)
select role.id, permission.id
from app.roles as role
cross join app.permissions as permission
where role.code = 'SUPER_ADMIN'
  and permission.code in ('announcements.read', 'announcements.write')
on conflict do nothing;

insert into app.app_config(key, value, value_type, is_public, description) values
  ('minimum_android_version', '"0.5.3"', 'STRING', true, 'Minimum supported Android version'),
  ('recommended_android_version', '"0.6.0"', 'STRING', true, 'Recommended Android version'),
  ('latest_android_version', '"0.6.0"', 'STRING', true, 'Latest Android version'),
  ('android_update_url', '"https://github.com/Mtzallqmy/Quran-yomk/releases/latest"', 'URL', true, 'Android update destination'),
  ('android_update_message', '"يتوفر إصدار أحدث من ترتيل."', 'STRING', true, 'Android update prompt')
on conflict(key) do update set
  value = excluded.value,
  value_type = excluded.value_type,
  is_public = excluded.is_public,
  description = excluded.description;

create or replace function app.update_runtime_config(
  p_updates jsonb,
  p_actor uuid,
  p_request_id uuid
)
returns setof app.app_config
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected integer;
  expected integer;
begin
  if not (
    app.managed_radio_authorized(p_actor, 'runtime_config.write')
    or app.managed_radio_authorized(p_actor, 'settings.write')
  ) then
    raise exception 'Settings permission required' using errcode = '42501';
  end if;
  if jsonb_typeof(p_updates) is distinct from 'object' or p_updates = '{}'::jsonb then
    raise exception 'Invalid runtime configuration';
  end if;
  if exists(
    select 1
    from jsonb_object_keys(p_updates) key
    where key <> all(array[
      'radio_enabled', 'virtual_radio_enabled',
      'virtual_radio_show_next_program',
      'virtual_radio_allow_degraded_fallback',
      'virtual_radio_max_failed_sources', 'offline_downloads_enabled',
      'mushaf_tajweed_enabled', 'elysia_api_enabled', 'reciters_page_size',
      'home_sections', 'content_manifest_version', 'content_manifest',
      'minimum_android_version', 'recommended_android_version',
      'latest_android_version', 'android_update_url',
      'android_update_message', 'prayer_features_enabled', 'adhkar_enabled',
      'maintenance_mode', 'maintenance_message', 'announcement_banner'
    ])
  ) then
    raise exception 'Runtime config key is not allowed';
  end if;
  select count(*) into expected from jsonb_object_keys(p_updates);
  return query
    update app.app_config config
    set value = item.value, updated_by = p_actor
    from jsonb_each(p_updates) item
    where config.key = item.key
    returning config.*;
  get diagnostics affected = row_count;
  if affected <> expected then
    raise exception 'Runtime config key is not seeded';
  end if;
  insert into app.audit_logs(
    actor_id, action, resource_type, request_id, metadata
  ) values (
    p_actor, 'runtime_config.update', 'app_config', p_request_id,
    jsonb_build_object(
      'keys', (select jsonb_agg(key) from jsonb_object_keys(p_updates) key)
    )
  );
end;
$$;

revoke all on function app.update_runtime_config(jsonb, uuid, uuid)
  from public, anon, authenticated;
grant execute on function app.update_runtime_config(jsonb, uuid, uuid)
  to service_role;
