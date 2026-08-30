create or replace function app.validate_timezone_name(p_timezone text)
returns boolean
language sql
stable
security definer
set search_path=''
as $$
  select exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone);
$$;

revoke all on function app.validate_timezone_name(text) from public,anon,authenticated;
grant execute on function app.validate_timezone_name(text) to service_role;
