alter table app.virtual_radio_schedule
  add column if not exists selection_mode text not null default 'FIXED';

do $$
begin
  if not exists(
    select 1 from pg_constraint
    where conrelid='app.virtual_radio_schedule'::regclass
      and conname='virtual_radio_schedule_selection_mode_check'
  ) then
    alter table app.virtual_radio_schedule
      add constraint virtual_radio_schedule_selection_mode_check
      check(selection_mode in ('FIXED','DAILY_ROTATION'));
  end if;
end $$;

update app.virtual_radio_schedule s
set selection_mode='DAILY_ROTATION',preferred_station_id=null,updated_at=now()
from app.virtual_radio_channels ch,app.categories c
where s.channel_id=ch.id and ch.slug='tarteel'
  and s.category_id=c.id and c.slug='RECITER';

update app.virtual_radio_schedule s
set selection_mode='FIXED',updated_at=now()
from app.virtual_radio_channels ch
where s.channel_id=ch.id and ch.slug='tarteel'
  and s.selection_mode<>'DAILY_ROTATION';

with slots as (
  select s.id,s.category_id,c.slug
  from app.virtual_radio_schedule s
  join app.virtual_radio_channels ch on ch.id=s.channel_id and ch.slug='tarteel'
  left join app.categories c on c.id=s.category_id
  where s.enabled=true
), ranked as (
  select sl.id schedule_id,st.id station_id,
    row_number() over(partition by sl.id order by
      case st.health_status when 'HEALTHY' then 0 when 'DEGRADED' then 1 else 2 end,
      st.sort_order,st.id) rn
  from slots sl
  join app.stations st on st.category_id=sl.category_id
  where st.station_source='EXTERNAL' and st.deleted_at is null and st.is_active=true
    and st.stream_url~*'^https://'
    and st.health_status in ('HEALTHY','DEGRADED')
    and st.availability_status in ('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE')
)
insert into app.virtual_radio_candidates(schedule_id,station_id,priority,weight,enabled)
select r.schedule_id,r.station_id,greatest(10,110-(r.rn::int*10)),1,true
from ranked r
join app.virtual_radio_schedule s on s.id=r.schedule_id
where r.rn <= case when s.selection_mode='DAILY_ROTATION' then 7 else 4 end
on conflict(schedule_id,station_id) do update set
  priority=excluded.priority,enabled=true,updated_at=now();

grant execute on function app.managed_radio_authorized(uuid,text) to authenticated;
grant select,insert,update,delete on app.virtual_radio_channels to authenticated;
grant select,insert,update,delete on app.virtual_radio_schedule to authenticated;
grant select,insert,update,delete on app.virtual_radio_candidates to authenticated;

drop policy if exists virtual_radio_channels_admin_select on app.virtual_radio_channels;
drop policy if exists virtual_radio_channels_admin_insert on app.virtual_radio_channels;
drop policy if exists virtual_radio_channels_admin_update on app.virtual_radio_channels;
drop policy if exists virtual_radio_channels_admin_delete on app.virtual_radio_channels;
create policy virtual_radio_channels_admin_select on app.virtual_radio_channels
for select to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.read'));
create policy virtual_radio_channels_admin_insert on app.virtual_radio_channels
for insert to authenticated with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_channels_admin_update on app.virtual_radio_channels
for update to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'))
with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_channels_admin_delete on app.virtual_radio_channels
for delete to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'));

drop policy if exists virtual_radio_schedule_admin_select on app.virtual_radio_schedule;
drop policy if exists virtual_radio_schedule_admin_insert on app.virtual_radio_schedule;
drop policy if exists virtual_radio_schedule_admin_update on app.virtual_radio_schedule;
drop policy if exists virtual_radio_schedule_admin_delete on app.virtual_radio_schedule;
create policy virtual_radio_schedule_admin_select on app.virtual_radio_schedule
for select to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.read'));
create policy virtual_radio_schedule_admin_insert on app.virtual_radio_schedule
for insert to authenticated with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_schedule_admin_update on app.virtual_radio_schedule
for update to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'))
with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_schedule_admin_delete on app.virtual_radio_schedule
for delete to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'));

drop policy if exists virtual_radio_candidates_admin_select on app.virtual_radio_candidates;
drop policy if exists virtual_radio_candidates_admin_insert on app.virtual_radio_candidates;
drop policy if exists virtual_radio_candidates_admin_update on app.virtual_radio_candidates;
drop policy if exists virtual_radio_candidates_admin_delete on app.virtual_radio_candidates;
create policy virtual_radio_candidates_admin_select on app.virtual_radio_candidates
for select to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.read'));
create policy virtual_radio_candidates_admin_insert on app.virtual_radio_candidates
for insert to authenticated with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_candidates_admin_update on app.virtual_radio_candidates
for update to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'))
with check(app.managed_radio_authorized(auth.uid(),'schedules.write'));
create policy virtual_radio_candidates_admin_delete on app.virtual_radio_candidates
for delete to authenticated using(app.managed_radio_authorized(auth.uid(),'schedules.write'));

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
  v_env text:=lower(coalesce(p_environment,'development'));
begin
  select * into v_channel from app.virtual_radio_channels
  where slug=p_slug and enabled=true limit 1;
  if v_channel.id is null then
    return jsonb_build_object('available',false,'error_code','VIRTUAL_CHANNEL_NOT_FOUND','server_time',p_now);
  end if;
  if not exists(select 1 from pg_catalog.pg_timezone_names where name=v_channel.timezone) then
    return jsonb_build_object('available',false,'error_code','INVALID_VIRTUAL_TIMEZONE',
      'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en),
      'server_time',p_now);
  end if;

  v_local:=p_now at time zone v_channel.timezone;
  v_date:=v_local::date;
  v_time:=v_local::time;
  v_dow:=extract(dow from v_local)::int;
  v_prev_dow:=(v_dow+6)%7;

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
  order by s.priority desc,s.start_time,s.id limit 1;

  if v_slot.id is null then
    return jsonb_build_object('available',false,'error_code','NO_VIRTUAL_SCHEDULE_SLOT',
      'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,
        'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone),
      'server_time',p_now);
  end if;

  if v_slot.start_time>v_slot.end_time and v_time<v_slot.end_time then v_start_date:=v_date-1; else v_start_date:=v_date; end if;
  v_end_date:=v_start_date+case when v_slot.start_time>v_slot.end_time then 1 else 0 end;
  v_started_at:=(v_start_date+v_slot.start_time) at time zone v_channel.timezone;
  v_ends_at:=(v_end_date+v_slot.end_time) at time zone v_channel.timezone;

  with candidate_base as (
    select vc.station_id,vc.priority,
      row_number() over(order by vc.priority desc,vc.station_id) as rn,
      count(*) over() as cnt
    from app.virtual_radio_candidates vc
    join app.stations cs on cs.id=vc.station_id
    where vc.schedule_id=v_slot.id and vc.enabled=true
      and cs.station_source='EXTERNAL' and cs.deleted_at is null and cs.is_active=true
      and cs.stream_url~*'^https://'
      and (cs.health_status='HEALTHY' or (v_slot.allow_degraded and cs.health_status='DEGRADED'))
      and (
        (v_env='development' and cs.availability_status in('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE'))
        or
        (v_env<>'development' and cs.availability_status='APPROVED_FOR_PUBLIC_RELEASE'
          and cs.production_enabled=true and cs.rights_status='APPROVED' and cs.commercial_use_status='ALLOWED')
      )
      and not(cs.id=any(coalesce(p_exclude_station_ids,'{}'::uuid[])))
  ), ranked as (
    select v_slot.preferred_station_id station_id,0 tier,1000000 candidate_priority
    where v_slot.preferred_station_id is not null and v_slot.selection_mode<>'DAILY_ROTATION'
    union all
    select cb.station_id,1,
      case when v_slot.selection_mode='DAILY_ROTATION' and cb.cnt>0 then
        1000000 - mod(
          (cb.rn::int-1) - mod((v_date-date '2026-01-01'),cb.cnt::int) + cb.cnt::int,
          cb.cnt::int
        )
      else cb.priority end
    from candidate_base cb
    union all
    select s.id,2,0 from app.stations s
    where v_slot.category_id is not null and v_slot.preferred_provider_id is not null
      and s.category_id=v_slot.category_id and s.provider_id=v_slot.preferred_provider_id
    union all
    select s.id,3,0 from app.stations s where v_slot.category_id is not null and s.category_id=v_slot.category_id
    union all
    select s.id,4,0 from app.stations s where v_slot.fallback_category_id is not null and s.category_id=v_slot.fallback_category_id
  ), dedup as (
    select station_id,min(tier) tier,max(candidate_priority) candidate_priority
    from ranked where station_id is not null group by station_id
  )
  select s.id,s.slug,s.name_ar,s.name_en,s.description,s.logo_url,c.slug category,
    s.stream_type,s.stream_url,s.health_status::text health_status,s.status::text station_status,
    s.availability_status,p.slug provider,p.name provider_name,s.attribution_required,s.attribution_text,
    s.integration_basis,s.terms_url,s.license_url,d.tier,d.candidate_priority
  into v_station
  from dedup d
  join app.stations s on s.id=d.station_id
  left join app.categories c on c.id=s.category_id
  left join app.content_providers p on p.id=s.provider_id
  where s.station_source='EXTERNAL' and s.deleted_at is null and s.is_active=true
    and s.stream_url~*'^https://'
    and not(s.id=any(coalesce(p_exclude_station_ids,'{}'::uuid[])))
    and (s.health_status='HEALTHY' or (v_slot.allow_degraded and s.health_status='DEGRADED'))
    and (
      (v_env='development' and s.availability_status in('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE'))
      or
      (v_env<>'development' and s.availability_status='APPROVED_FOR_PUBLIC_RELEASE'
        and s.production_enabled=true and s.rights_status='APPROVED' and s.commercial_use_status='ALLOWED')
    )
  order by case when s.health_status='HEALTHY' then 0 else 1 end,
    d.tier,d.candidate_priority desc,s.sort_order,s.id
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
      'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,
        'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone),
      'program',jsonb_build_object('id',v_slot.id,'title_ar',v_slot.program_title_ar,'title_en',v_slot.program_title_en,
        'subtitle_ar',v_slot.program_subtitle_ar,'subtitle_en',v_slot.program_subtitle_en,
        'category',(select c.slug from app.categories c where c.id=v_slot.category_id),
        'selection_mode',v_slot.selection_mode,'started_at',v_started_at,'ends_at',v_ends_at),
      'next_program',v_next,'next_change_at',v_ends_at,'server_time',p_now
    );
  end if;

  return jsonb_build_object(
    'available',true,
    'channel',jsonb_build_object('id',v_channel.id,'slug',v_channel.slug,'name_ar',v_channel.name_ar,'name_en',v_channel.name_en,
      'description_ar',v_channel.description_ar,'description_en',v_channel.description_en,
      'artwork_url',v_channel.artwork_url,'timezone',v_channel.timezone),
    'program',jsonb_build_object('id',v_slot.id,'title_ar',v_slot.program_title_ar,'title_en',v_slot.program_title_en,
      'subtitle_ar',v_slot.program_subtitle_ar,'subtitle_en',v_slot.program_subtitle_en,
      'category',(select c.slug from app.categories c where c.id=v_slot.category_id),
      'selection_mode',v_slot.selection_mode,'started_at',v_started_at,'ends_at',v_ends_at),
    'station',jsonb_build_object('id',v_station.id,'slug',v_station.slug,'name_ar',v_station.name_ar,'name_en',v_station.name_en,
      'description',v_station.description,'logo_url',v_station.logo_url,'category',v_station.category,
      'station_source','EXTERNAL','stream_type',v_station.stream_type,'playback_url',v_station.stream_url,
      'health_status',v_station.health_status,'provider',v_station.provider,'provider_name',v_station.provider_name,
      'integration_basis',v_station.integration_basis,
      'attribution',case when v_station.attribution_required then v_station.attribution_text else null end,
      'terms_url',v_station.terms_url,'license_url',v_station.license_url),
    'resolution',jsonb_build_object('schedule_id',v_slot.id,'selection_tier',v_station.tier,
      'selection_mode',v_slot.selection_mode,'selection_date',v_date,
      'excluded_station_ids',coalesce(to_jsonb(p_exclude_station_ids),'[]'::jsonb),'environment',v_env),
    'next_program',v_next,'next_change_at',v_ends_at,'server_time',p_now
  );
end;
$$;

revoke all on function app.resolve_virtual_radio(text,text,uuid[],timestamptz) from public,anon,authenticated;
grant execute on function app.resolve_virtual_radio(text,text,uuid[],timestamptz) to service_role;
