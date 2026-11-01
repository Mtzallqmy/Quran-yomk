-- Keep the mobile and web admin session lookup independent of PostgREST
-- relationship embedding. Only the trusted notification backend may call it.
create or replace function app.admin_session_context(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select jsonb_build_object(
    'roles', coalesce((
      select jsonb_agg(distinct r.code order by r.code)
      from app.administrators a
      join app.administrator_roles ar on ar.administrator_id=a.id
      join app.roles r on r.id=ar.role_id
      where a.id=p_user_id and a.is_active and a.deleted_at is null
    ), '[]'::jsonb),
    'permissions', coalesce((
      select jsonb_agg(distinct p.code order by p.code)
      from app.administrators a
      join app.administrator_roles ar on ar.administrator_id=a.id
      join app.role_permissions rp on rp.role_id=ar.role_id
      join app.permissions p on p.id=rp.permission_id
      where a.id=p_user_id and a.is_active and a.deleted_at is null
    ), '[]'::jsonb)
  );
$$;

revoke all on function app.admin_session_context(uuid) from public, anon, authenticated;
grant execute on function app.admin_session_context(uuid) to service_role;
