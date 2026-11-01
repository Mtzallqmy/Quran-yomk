-- Phase 9/10 public mobile catalog.
-- Keep app tables private. Only these read-only SECURITY DEFINER functions are callable by client roles.

create or replace function app.public_categories()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'parent_id',c.parent_id,'slug',c.slug,'name_ar',c.name_ar,'name_en',c.name_en,
    'description',c.description,'icon_key',c.icon_key,'sort_order',c.sort_order
  ) order by c.sort_order,c.name_ar),'[]'::jsonb)
  from app.categories c
  where c.deleted_at is null and c.is_active=true;
$$;

create or replace function app.public_surahs()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',s.id,'number',s.number,'name_ar',s.name_ar,'name_en',s.name_en,'ayah_count',s.ayah_count
  ) order by s.number),'[]'::jsonb)
  from app.surahs s;
$$;

create or replace function app.public_reciters(
  p_search text default null,
  p_limit integer default 30,
  p_offset integer default 0,
  p_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'slug',r.slug,'name_ar',r.name_ar,'name_en',r.name_en,'image_url',r.image_url,
    'country',r.country,'rewaya',r.rewaya,'description',r.description
  ) order by r.name_ar),'[]'::jsonb)
  from (
    select x.* from app.reciters x
    where x.deleted_at is null and x.is_active=true
      and (p_id is null or x.id=p_id)
      and (p_search is null or btrim(p_search)='' or x.name_ar ilike '%'||p_search||'%' or coalesce(x.name_en,'') ilike '%'||p_search||'%')
    order by x.name_ar
    limit greatest(1,least(coalesce(p_limit,30),100))
    offset greatest(coalesce(p_offset,0),0)
  ) r;
$$;

create or replace function app.public_app_config()
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_object_agg(c.key,c.value),'{}'::jsonb)
  from app.app_config c
  where c.is_public=true;
$$;

create or replace function app.public_now_playing(p_station_slug text)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce((
    select jsonb_build_object(
      'station',jsonb_build_object('id',s.id,'slug',s.slug,'name_ar',s.name_ar,'name_en',s.name_en),
      'media',case when n.media_id is null then null else jsonb_build_object('id',n.media_id) end,
      'title',n.title,'subtitle',n.artist,'started_at',n.started_at,'expected_end_at',n.expected_end_at,
      'source',coalesce(n.source_type,n.mode::text),'is_live',true,'server_time',now()
    )
    from app.stations s
    left join radio.now_playing n on n.station_id=s.id
    where s.slug=p_station_slug and s.deleted_at is null and s.station_source='INTERNAL'
    limit 1
  ),'{}'::jsonb);
$$;

create or replace function app.public_reciter_tracks(p_reciter_id uuid)
returns jsonb
language sql
stable
security definer
set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'surah',jsonb_build_object('id',s.id,'number',s.number,'name_ar',s.name_ar,'name_en',s.name_en,'ayah_count',s.ayah_count),
    'track',jsonb_build_object('id',t.id,'media_id',t.media_id,'duration_ms',t.duration_ms,'quality',t.quality,
      'rewaya',t.rewaya,'format',t.format,'bitrate_kbps',t.bitrate_kbps,'playback_url',t.audio_url)
  ) order by s.number),'[]'::jsonb)
  from app.reciter_tracks t
  join app.surahs s on s.id=t.surah_id
  where t.reciter_id=p_reciter_id and t.is_active=true;
$$;

revoke all on function app.public_categories() from public;
revoke all on function app.public_surahs() from public;
revoke all on function app.public_reciters(text,integer,integer,uuid) from public;
revoke all on function app.public_app_config() from public;
revoke all on function app.public_now_playing(text) from public;
revoke all on function app.public_reciter_tracks(uuid) from public;

grant execute on function app.public_categories() to anon,authenticated,service_role;
grant execute on function app.public_surahs() to anon,authenticated,service_role;
grant execute on function app.public_reciters(text,integer,integer,uuid) to anon,authenticated,service_role;
grant execute on function app.public_app_config() to anon,authenticated,service_role;
grant execute on function app.public_now_playing(text) to anon,authenticated,service_role;
grant execute on function app.public_reciter_tracks(uuid) to anon,authenticated,service_role;
