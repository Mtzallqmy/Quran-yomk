-- Expose only constrained read-only RPCs in the PostgREST public schema.
-- app.* tables remain private and are never granted to mobile clients.

create or replace function public.tarteel_public_station_catalog(
  p_environment text default 'production',
  p_source text default null,
  p_category text default null,
  p_provider text default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0,
  p_slug text default null
) returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb)
  from app.public_station_catalog(p_environment,p_source,p_category,p_provider,p_search,p_limit,p_offset,p_slug) x;
$$;

create or replace function public.tarteel_public_content_sources() returns jsonb
language sql stable security definer set search_path=''
as $$ select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from app.public_content_sources() x $$;

create or replace function public.tarteel_public_categories() returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_categories() $$;

create or replace function public.tarteel_public_surahs() returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_surahs() $$;

create or replace function public.tarteel_public_reciters(
  p_search text default null,p_limit integer default 30,p_offset integer default 0,p_id uuid default null
) returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_reciters(p_search,p_limit,p_offset,p_id) $$;

create or replace function public.tarteel_public_app_config() returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_app_config() $$;

create or replace function public.tarteel_public_now_playing(p_station_slug text) returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_now_playing(p_station_slug) $$;

create or replace function public.tarteel_public_reciter_tracks(p_reciter_id uuid) returns jsonb
language sql stable security definer set search_path=''
as $$ select app.public_reciter_tracks(p_reciter_id) $$;

revoke all on function public.tarteel_public_station_catalog(text,text,text,text,text,integer,integer,text) from public;
revoke all on function public.tarteel_public_content_sources() from public;
revoke all on function public.tarteel_public_categories() from public;
revoke all on function public.tarteel_public_surahs() from public;
revoke all on function public.tarteel_public_reciters(text,integer,integer,uuid) from public;
revoke all on function public.tarteel_public_app_config() from public;
revoke all on function public.tarteel_public_now_playing(text) from public;
revoke all on function public.tarteel_public_reciter_tracks(uuid) from public;

grant execute on function public.tarteel_public_station_catalog(text,text,text,text,text,integer,integer,text) to anon,authenticated,service_role;
grant execute on function public.tarteel_public_content_sources() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_categories() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_surahs() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_reciters(text,integer,integer,uuid) to anon,authenticated,service_role;
grant execute on function public.tarteel_public_app_config() to anon,authenticated,service_role;
grant execute on function public.tarteel_public_now_playing(text) to anon,authenticated,service_role;
grant execute on function public.tarteel_public_reciter_tracks(uuid) to anon,authenticated,service_role;
