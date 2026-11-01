-- Backward-compatible public alias: all Tarteel virtual radio callers now receive the managed-aware contract.
create or replace function public.tarteel_public_virtual_radio(
  p_slug text default 'tarteel',
  p_environment text default 'development',
  p_exclude_station_ids uuid[] default '{}'::uuid[],
  p_now timestamptz default now()
) returns jsonb language sql stable security definer set search_path='' as $$
  select public.tarteel_public_virtual_radio_managed(p_slug,p_environment,p_exclude_station_ids,p_now);
$$;
revoke all on function public.tarteel_public_virtual_radio(text,text,uuid[],timestamptz) from public;
grant execute on function public.tarteel_public_virtual_radio(text,text,uuid[],timestamptz) to anon,authenticated,service_role;
