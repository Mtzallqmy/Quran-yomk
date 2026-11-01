-- Phase 11 Virtual Tarteel Radio.
-- This is logical schedule/source resolution only. It does not enqueue audio,
-- call the legacy Radio Engine, proxy streams, or create an owned broadcast.

create table if not exists app.virtual_radio_channels(
  id uuid primary key default gen_random_uuid(),
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  name_ar text not null,
  name_en text,
  description_ar text,
  description_en text,
  artwork_url text,
  timezone text not null default 'Asia/Aden',
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists app.virtual_radio_schedule(
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references app.virtual_radio_channels(id) on delete cascade,
  days_of_week smallint[] not null default array[0,1,2,3,4,5,6]::smallint[],
  start_time time not null,
  end_time time not null,
  program_title_ar text not null,
  program_title_en text,
  program_subtitle_ar text,
  program_subtitle_en text,
  category_id uuid references app.categories(id) on delete restrict,
  fallback_category_id uuid references app.categories(id) on delete restrict,
  preferred_provider_id uuid references app.content_providers(id) on delete set null,
  preferred_station_id uuid references app.stations(id) on delete set null,
  allow_degraded boolean not null default true,
  enabled boolean not null default true,
  priority integer not null default 100 check (priority>=0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint virtual_radio_schedule_days_check check (
    cardinality(days_of_week) between 1 and 7
    and days_of_week <@ array[0,1,2,3,4,5,6]::smallint[]
  ),
  constraint virtual_radio_schedule_time_check check (start_time<>end_time)
);

create table if not exists app.virtual_radio_candidates(
  id uuid primary key default gen_random_uuid(),
  schedule_id uuid not null references app.virtual_radio_schedule(id) on delete cascade,
  station_id uuid not null references app.stations(id) on delete cascade,
  priority integer not null default 100 check (priority>=0),
  weight integer not null default 1 check (weight between 1 and 1000),
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint virtual_radio_candidates_unique unique(schedule_id,station_id)
);

create index if not exists virtual_radio_schedule_channel_enabled_idx
  on app.virtual_radio_schedule(channel_id,enabled,start_time,end_time,priority desc);
create index if not exists virtual_radio_candidates_schedule_enabled_idx
  on app.virtual_radio_candidates(schedule_id,enabled,priority desc);

drop trigger if exists trg_virtual_radio_channels_updated_at on app.virtual_radio_channels;
create trigger trg_virtual_radio_channels_updated_at before update on app.virtual_radio_channels
for each row execute function app.set_updated_at();
drop trigger if exists trg_virtual_radio_schedule_updated_at on app.virtual_radio_schedule;
create trigger trg_virtual_radio_schedule_updated_at before update on app.virtual_radio_schedule
for each row execute function app.set_updated_at();
drop trigger if exists trg_virtual_radio_candidates_updated_at on app.virtual_radio_candidates;
create trigger trg_virtual_radio_candidates_updated_at before update on app.virtual_radio_candidates
for each row execute function app.set_updated_at();

alter table app.virtual_radio_channels enable row level security;
alter table app.virtual_radio_schedule enable row level security;
alter table app.virtual_radio_candidates enable row level security;

insert into app.virtual_radio_channels(
  slug,name_ar,name_en,description_ar,description_en,timezone,enabled
) values(
  'tarteel','إذاعة ترتيل','Tarteel Radio',
  'قناة افتراضية من ترتيل تختار بثًا خارجيًا متاحًا وفق جدول تحريري وصحة المصدر، دون إعادة بث الصوت عبر خوادم ترتيل.',
  'A curated virtual Tarteel channel that resolves a healthy external stream by schedule without proxying or rebroadcasting audio.',
  'Asia/Aden',true
)
on conflict(slug) do update set
  name_ar=excluded.name_ar,name_en=excluded.name_en,
  description_ar=excluded.description_ar,description_en=excluded.description_en,
  timezone=excluded.timezone,updated_at=now();

create or replace function app.resolve_virtual_radio(
  p_slug text,
  p_environment text default 'development',
  p_exclude_station_ids uuid[] default '{}'::uuid[],
  p_now timestamptz default now()
)
returns jsonb
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_channel app.virtual_radio_channels%rowtype;
  v_slot app.virtual_radio_schedule%rowtype;
  v_station record;
  v_local timestamp;
  v_date date;
  v_time time;
  v_dow int;
  v_prev_dow int;
  v_start_date date;
  v_end_date date;
  v_started_at timestamptz;
  v_ends_at timestamptz;
  v_next jsonb;
  v_env text := lower(coalesce(p_environment,'development'));
begin
  select * into v_channel from app.virtual_radio_channels
  where slug=p_slug and enabled=true limit 1;
  if v_channel.id is null then
    return jsonb_build_object('available',false,'error_code','VIRTUAL_CHANNEL_NOT_FOUND','server_time',p_now);
  end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=v_channel.timezone) then
    return jsonb_build_object('available',false,'error_code','INVALID_VIRTUAL_TIMEZONE','server_time',p_now);
  end if;

  v_local := p_now at time zone v_channel.timezone;
  v_date := v_local::date;
  v_time := v_local::time;
  v_dow := extract(dow from v_local)::int;
  v_prev_dow := (v_dow+6)%7;

  select s.* into v_slot
  from app.virtual_radio_schedule s
  where s.channel_id=v_channel.id and s.enabled=true and (
    (s.start_time<s.end_time and v_dow=any(s.days_of_week) and v_time>=s.start_time and v_time<s.end_time)
    or
    (s.start_time>s.end_time and (
      (v_dow=any(s.days_of_week) and v_time>=s.start_time)
      or (v_prev_dow=any(s.days_of_week) and v_time<s.end_time)
    ))
  )
  order by s.priority desc,s.start_time,s.id
  limit 1;

  if v_slot.id is null then
    return jsonb_build_object(
      'available',false,'error_code','NO_VIRTUAL_SCHEDULE_SLOT',
      'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone),
      'server_time',p_now
    );
  end if;

  if v_slot.start_time>v_slot.end_time and v_time<v_slot.end_time then v_start_date:=v_date-1; else v_start_date:=v_date; end if;
  v_end_date:=v_start_date+case when v_slot.start_time>v_slot.end_time then 1 else 0 end;
  v_started_at:=(v_start_date+v_slot.start_time) at time zone v_channel.timezone;
  v_ends_at:=(v_end_date+v_slot.end_time) at time zone v_channel.timezone;

  with ranked as (
    select v_slot.preferred_station_id station_id,0 tier,1000000 candidate_priority where v_slot.preferred_station_id is not null
    union all
    select vc.station_id,1,vc.priority from app.virtual_radio_candidates vc where vc.schedule_id=v_slot.id and vc.enabled=true
    union all
    select s.id,2,0 from app.stations s where v_slot.category_id is not null and v_slot.preferred_provider_id is not null and s.category_id=v_slot.category_id and s.provider_id=v_slot.preferred_provider_id
    union all
    select s.id,3,0 from app.stations s where v_slot.category_id is not null and s.category_id=v_slot.category_id
    union all
    select s.id,4,0 from app.stations s where v_slot.fallback_category_id is not null and s.category_id=v_slot.fallback_category_id
  ), dedup as (
    select station_id,min(tier) tier,max(candidate_priority) candidate_priority
    from ranked where station_id is not null group by station_id
  )
  select s.id,s.slug,s.name_ar,s.name_en,s.description,s.logo_url,c.slug category,
    s.stream_type,s.stream_url,s.health_status::text health_status,s.availability_status,
    p.slug provider,p.name provider_name,s.attribution_required,s.attribution_text,
    s.integration_basis,s.terms_url,s.license_url,d.tier,d.candidate_priority
  into v_station
  from dedup d join app.stations s on s.id=d.station_id
  left join app.categories c on c.id=s.category_id
  left join app.content_providers p on p.id=s.provider_id
  where s.station_source='EXTERNAL' and s.deleted_at is null and s.is_active=true
    and s.stream_url~*'^https://'
    and not(s.id=any(coalesce(p_exclude_station_ids,'{}'::uuid[])))
    and (s.health_status='HEALTHY' or (v_slot.allow_degraded and s.health_status='DEGRADED'))
    and (
      (v_env='development' and s.availability_status in('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE'))
      or (v_env<>'development' and s.availability_status='APPROVED_FOR_PUBLIC_RELEASE'
          and s.production_enabled=true and s.rights_status='APPROVED' and s.commercial_use_status='ALLOWED')
    )
  order by case when s.health_status='HEALTHY' then 0 else 1 end,d.tier,d.candidate_priority desc,s.sort_order,s.id
  limit 1;

  select jsonb_build_object('title_ar',x.program_title_ar,'title_en',x.program_title_en,'starts_at',x.starts_at)
  into v_next
  from (
    select s.program_title_ar,s.program_title_en,((g.d::date+s.start_time) at time zone v_channel.timezone) starts_at
    from app.virtual_radio_schedule s
    cross join lateral generate_series(v_start_date,v_start_date+8,interval '1 day') g(d)
    where s.channel_id=v_channel.id and s.enabled=true
      and extract(dow from g.d)::int=any(s.days_of_week)
      and ((g.d::date+s.start_time) at time zone v_channel.timezone)>=v_ends_at
    order by starts_at,s.priority desc,s.id limit 1
  ) x;

  if v_station.id is null then
    return jsonb_build_object(
      'available',false,'error_code','NO_VIRTUAL_SOURCE_AVAILABLE',
      'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone),
      'program',jsonb_build_object('id',v_slot.id,'title_ar',v_slot.program_title_ar,'title_en',v_slot.program_title_en,'subtitle_ar',v_slot.program_subtitle_ar,'subtitle_en',v_slot.program_subtitle_en,'started_at',v_started_at,'ends_at',v_ends_at),
      'next_program',v_next,'next_change_at',v_ends_at,'server_time',p_now
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'channel',jsonb_build_object(
      'id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,
      'description_ar',v_channel.description_ar,'description_en',v_channel.description_en,
      'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone
    ),
    'program',jsonb_build_object(
      'id',v_slot.id,'title_ar',v_slot.program_title_ar,'title_en',v_slot.program_title_en,
      'subtitle_ar',v_slot.program_subtitle_ar,'subtitle_en',v_slot.program_subtitle_en,
      'category',(select c.slug from app.categories c where c.id=v_slot.category_id),
      'started_at',v_started_at,'ends_at',v_ends_at
    ),
    'station',jsonb_build_object(
      'id',v_station.id,'slug',v_station.slug,'name_ar',v_station.name_ar,'name_en',v_station.name_en,
      'description',v_station.description,'logo_url',v_station.logo_url,'category',v_station.category,
      'station_source','EXTERNAL','stream_type',v_station.stream_type,'playback_url',v_station.stream_url,
      'health_status',v_station.health_status,'provider',v_station.provider,'provider_name',v_station.provider_name,
      'integration_basis',v_station.integration_basis,
      'attribution',case when v_station.attribution_required then v_station.attribution_text else null end,
      'terms_url',v_station.terms_url,'license_url',v_station.license_url
    ),
    'resolution',jsonb_build_object(
      'schedule_id',v_slot.id,'selection_tier',v_station.tier,
      'excluded_station_ids',coalesce(to_jsonb(p_exclude_station_ids),'[]'::jsonb),'environment',v_env
    ),
    'next_program',v_next,'next_change_at',v_ends_at,'server_time',p_now
  );
end;
$$;

create or replace function app.virtual_radio_preview(
  p_slug text default 'tarteel',p_hours integer default 24,
  p_environment text default 'development',p_from timestamptz default now()
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_rows jsonb:='[]'::jsonb; v_cursor timestamptz:=p_from;
  v_until timestamptz:=p_from+make_interval(hours=>greatest(1,least(p_hours,168)));
  v_resolution jsonb; v_next timestamptz; v_guard int:=0;
begin
  while v_cursor<v_until and v_guard<64 loop
    v_guard:=v_guard+1;
    v_resolution:=app.resolve_virtual_radio(p_slug,p_environment,'{}'::uuid[],v_cursor);
    v_rows:=v_rows||jsonb_build_array(v_resolution);
    v_next:=nullif(v_resolution->>'next_change_at','')::timestamptz;
    if v_next is null or v_next<=v_cursor then exit; end if;
    v_cursor:=v_next+interval '1 second';
  end loop;
  return v_rows;
end;
$$;

create or replace function public.tarteel_public_virtual_radio(
  p_slug text default 'tarteel',p_environment text default 'development',
  p_exclude_station_ids uuid[] default '{}'::uuid[],p_now timestamptz default now()
) returns jsonb language sql stable security definer set search_path='' as $$
  select app.resolve_virtual_radio(p_slug,p_environment,p_exclude_station_ids,p_now);
$$;

revoke all on function app.resolve_virtual_radio(text,text,uuid[],timestamptz) from public,anon,authenticated;
revoke all on function app.virtual_radio_preview(text,integer,text,timestamptz) from public,anon,authenticated;
grant execute on function app.resolve_virtual_radio(text,text,uuid[],timestamptz) to service_role;
grant execute on function app.virtual_radio_preview(text,integer,text,timestamptz) to service_role;
revoke all on function public.tarteel_public_virtual_radio(text,text,uuid[],timestamptz) from public;
grant execute on function public.tarteel_public_virtual_radio(text,text,uuid[],timestamptz) to anon,authenticated,service_role;
