create or replace function app.managed_radio_authorized(p_user_id uuid,p_permission text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(
    select 1
    from app.administrators a
    join app.administrator_roles ar on ar.administrator_id=a.id
    join app.role_permissions rp on rp.role_id=ar.role_id
    join app.permissions p on p.id=rp.permission_id
    where a.id=p_user_id and a.is_active=true and a.deleted_at is null and p.code=p_permission
  );
$$;
revoke all on function app.managed_radio_authorized(uuid,text) from public,anon,authenticated;
grant execute on function app.managed_radio_authorized(uuid,text) to service_role;
