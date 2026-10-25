alter table app.user_devices
  add column consent_notice_version text,
  add column consented_at timestamptz;

-- No historical row is treated as proof of informed consent. Preserve the
-- registration and preference history, but retire the old provider token so
-- it cannot be used again until this installation explicitly opts in.
update app.user_devices
set fcm_token = 'revoked:' || gen_random_uuid()::text,
    notifications_enabled = false,
    revoked_at = coalesce(revoked_at, now()),
    consent_notice_version = null,
    consented_at = null;

alter table app.user_devices
  add constraint user_devices_consent_pair_check check (
    (consent_notice_version is null and consented_at is null)
    or
    (consent_notice_version is not null and consented_at is not null)
  ),
  add constraint user_devices_active_consent_check check (
    revoked_at is not null
    or (
      consent_notice_version = 'notifications-v1'
      and consented_at is not null
    )
  );

comment on column app.user_devices.consent_notice_version is
  'Version of the in-app privacy notice explicitly accepted before OS permission and token registration.';
comment on column app.user_devices.consented_at is
  'Client-recorded UTC time of explicit acceptance; cleared when the device registration is revoked.';

create or replace function app.grant_new_permission_to_super_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into app.role_permissions(role_id, permission_id)
  select role.id, new.id
  from app.roles as role
  where role.code = 'SUPER_ADMIN'
  on conflict do nothing;
  return new;
end
$$;

revoke all on function app.grant_new_permission_to_super_admin() from public, anon, authenticated;

drop trigger if exists permissions_grant_super_admin on app.permissions;
create trigger permissions_grant_super_admin
after insert on app.permissions
for each row execute function app.grant_new_permission_to_super_admin();

-- Synchronize existing permissions as well as future ones.
insert into app.role_permissions(role_id, permission_id)
select role.id, permission.id
from app.roles as role
cross join app.permissions as permission
where role.code = 'SUPER_ADMIN'
on conflict do nothing;
