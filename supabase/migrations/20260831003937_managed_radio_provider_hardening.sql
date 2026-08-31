-- Harden the existing managed-radio foundation without replacing legacy Virtual Radio.

alter table app.stations drop constraint if exists stations_redistribution_mode_check;
alter table app.stations add constraint stations_redistribution_mode_check
  check (redistribution_mode = any(array['DIRECT_EXTERNAL'::text,'PROVIDER_EMBED'::text,'MANAGED_RELAY'::text,'RESTRICTED'::text]));

alter table app.virtual_radio_schedule
  add column if not exists managed_secondary_station_id uuid references app.stations(id) on delete set null,
  add column if not exists managed_backup_playlist_external_id text,
  add column if not exists managed_sync_enabled boolean not null default true;

alter table app.managed_radio_configs
  add column if not exists sync_enabled boolean not null default false,
  add column if not exists last_sync_error_message text;

alter table app.managed_radio_event_bindings
  add column if not exists last_sync_error_message text;

alter table app.managed_radio_sync_runs drop constraint if exists managed_radio_sync_runs_operation_check;
alter table app.managed_radio_sync_runs add constraint managed_radio_sync_runs_operation_check
  check (operation in ('REFRESH_STATUS','SYNC_SCHEDULE','TEST_RELAY','REFRESH_NOW_PLAYING','FAILOVER'));

create index if not exists virtual_radio_schedule_managed_secondary_idx
  on app.virtual_radio_schedule(managed_secondary_station_id) where managed_secondary_station_id is not null;

-- Public station identity was verified against Radio.co Public API v2.
update app.managed_radio_configs m
set station_external_id='s047473980',
    fixed_stream_url='https://s4.radio.co/s047473980/listen',
    provider_status='offair',
    last_provider_check_at=now(),
    last_sync_status='BLOCKED',
    last_sync_error_code='RADIOCO_OAUTH_NOT_CONFIGURED',
    last_sync_error_message='Radio.co Studio API OAuth application credentials are not configured in the Edge Function runtime.',
    enabled=false,
    sync_enabled=false,
    updated_at=now()
from app.virtual_radio_channels c
where c.id=m.channel_id and c.slug='tarteel';

insert into app.managed_radio_event_bindings(schedule_id,provider,last_sync_status,last_sync_error_code,last_sync_error_message)
select s.id,'RADIO_CO',
       case when s.enabled and s.managed_sync_enabled then 'BLOCKED' else 'NEVER' end,
       case when s.enabled and s.managed_sync_enabled then 'RADIOCO_OAUTH_NOT_CONFIGURED' else null end,
       case when s.enabled and s.managed_sync_enabled then 'Studio API OAuth is required before provider schedule synchronization.' else null end
from app.virtual_radio_schedule s
join app.virtual_radio_channels c on c.id=s.channel_id
where c.slug='tarteel'
on conflict(schedule_id) do nothing;

create or replace function app.managed_radio_sync_manifest(p_slug text default 'tarteel')
returns jsonb language sql stable security definer set search_path='' as $$
with cfg as (
  select c.id channel_id,c.slug,c.name_ar,c.name_en,c.timezone,
         m.provider,m.enabled,m.sync_enabled,m.station_external_id,m.fixed_stream_url,
         m.backup_playlist_external_id,m.provider_status,m.provider_source,m.provider_now_playing,
         m.last_provider_check_at,m.last_sync_at,m.last_sync_status,m.last_sync_error_code
  from app.virtual_radio_channels c
  join app.managed_radio_configs m on m.channel_id=c.id
  where c.slug=p_slug limit 1
), slots as (
  select s.*,
    p.slug primary_slug,p.name_ar primary_name_ar,p.stream_url primary_stream_url,
    p.health_status::text primary_health_status,p.redistribution_mode primary_redistribution_mode,
    p.rights_status::text primary_rights_status,p.commercial_use_status::text primary_commercial_use_status,
    p.production_enabled primary_production_enabled,p.availability_status primary_availability_status,
    q.slug secondary_slug,q.name_ar secondary_name_ar,q.stream_url secondary_stream_url,
    q.health_status::text secondary_health_status,q.redistribution_mode secondary_redistribution_mode,
    q.rights_status::text secondary_rights_status,q.commercial_use_status::text secondary_commercial_use_status,
    q.production_enabled secondary_production_enabled,q.availability_status secondary_availability_status,
    b.provider_event_id,b.primary_relay_external_id,b.secondary_relay_external_id,b.backup_playlist_external_id binding_backup_playlist_external_id,
    b.provider_payload_hash,b.last_synced_at,b.last_sync_status binding_sync_status,b.last_sync_error_code binding_error_code,b.last_sync_error_message binding_error_message
  from app.virtual_radio_schedule s
  join cfg c on c.channel_id=s.channel_id
  left join app.stations p on p.id=s.preferred_station_id and p.deleted_at is null
  left join app.stations q on q.id=s.managed_secondary_station_id and q.deleted_at is null
  left join app.managed_radio_event_bindings b on b.schedule_id=s.id
)
select case when c.channel_id is null then jsonb_build_object('configured',false,'slug',p_slug)
else jsonb_build_object(
  'configured',true,
  'channel',jsonb_build_object(
    'id',c.channel_id,'slug',c.slug,'name_ar',c.name_ar,'name_en',c.name_en,'timezone',c.timezone,
    'provider',c.provider,'enabled',c.enabled,'sync_enabled',c.sync_enabled,
    'station_external_id',c.station_external_id,'fixed_stream_url',c.fixed_stream_url,
    'backup_playlist_external_id',c.backup_playlist_external_id,'provider_status',c.provider_status,
    'last_provider_check_at',c.last_provider_check_at,'last_sync_at',c.last_sync_at,
    'last_sync_status',c.last_sync_status,'last_sync_error_code',c.last_sync_error_code
  ),
  'schedules',coalesce((select jsonb_agg(jsonb_build_object(
    'id',s.id,'days_of_week',s.days_of_week,'start_time',s.start_time,'end_time',s.end_time,
    'program_title_ar',s.program_title_ar,'program_title_en',s.program_title_en,
    'enabled',s.enabled,'managed_sync_enabled',s.managed_sync_enabled,
    'backup_playlist_external_id',coalesce(s.managed_backup_playlist_external_id,c.backup_playlist_external_id),
    'primary',case when s.preferred_station_id is null then null else jsonb_build_object(
      'id',s.preferred_station_id,'slug',s.primary_slug,'name_ar',s.primary_name_ar,'stream_url',s.primary_stream_url,
      'health_status',s.primary_health_status,'redistribution_mode',s.primary_redistribution_mode,
      'rights_status',s.primary_rights_status,'commercial_use_status',s.primary_commercial_use_status,
      'production_enabled',s.primary_production_enabled,'availability_status',s.primary_availability_status,
      'relay_eligible',(s.primary_redistribution_mode='MANAGED_RELAY' and s.primary_rights_status='APPROVED'
        and s.primary_commercial_use_status='ALLOWED' and s.primary_production_enabled=true
        and s.primary_availability_status='APPROVED_FOR_PUBLIC_RELEASE' and s.primary_stream_url ~* '^https://')
    ) end,
    'secondary',case when s.managed_secondary_station_id is null then null else jsonb_build_object(
      'id',s.managed_secondary_station_id,'slug',s.secondary_slug,'name_ar',s.secondary_name_ar,'stream_url',s.secondary_stream_url,
      'health_status',s.secondary_health_status,'redistribution_mode',s.secondary_redistribution_mode,
      'rights_status',s.secondary_rights_status,'commercial_use_status',s.secondary_commercial_use_status,
      'production_enabled',s.secondary_production_enabled,'availability_status',s.secondary_availability_status,
      'relay_eligible',(s.secondary_redistribution_mode='MANAGED_RELAY' and s.secondary_rights_status='APPROVED'
        and s.secondary_commercial_use_status='ALLOWED' and s.secondary_production_enabled=true
        and s.secondary_availability_status='APPROVED_FOR_PUBLIC_RELEASE' and s.secondary_stream_url ~* '^https://')
    ) end,
    'binding',jsonb_build_object(
      'provider_event_id',s.provider_event_id,'primary_relay_external_id',s.primary_relay_external_id,
      'secondary_relay_external_id',s.secondary_relay_external_id,'backup_playlist_external_id',s.binding_backup_playlist_external_id,
      'provider_payload_hash',s.provider_payload_hash,'last_synced_at',s.last_synced_at,
      'last_sync_status',coalesce(s.binding_sync_status,'NEVER'),'last_sync_error_code',s.binding_error_code,
      'last_sync_error_message',s.binding_error_message)
  ) order by s.start_time,s.priority desc,s.id) from slots s),'[]'::jsonb)
) end
from (select 1) seed left join cfg c on true;
$$;

create or replace function public.tarteel_public_managed_radio_config(p_slug text default 'tarteel')
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce((select jsonb_build_object(
    'configured',(m.station_external_id is not null and m.fixed_stream_url is not null),
    'enabled',m.enabled,'provider',m.provider,'provider_station_id',m.station_external_id,
    'stream_url',m.fixed_stream_url,'provider_status',m.provider_status,
    'source',m.provider_source,'now_playing',m.provider_now_playing,
    'last_checked_at',m.last_provider_check_at,'last_sync_at',m.last_sync_at,
    'last_sync_status',m.last_sync_status,'last_sync_error_code',m.last_sync_error_code,
    'channel',jsonb_build_object('id',c.id,'slug',c.slug,'name_ar',c.name_ar,'name_en',c.name_en,'artwork_url',c.artwork_url,'timezone',c.timezone)
  ) from app.virtual_radio_channels c join app.managed_radio_configs m on m.channel_id=c.id where c.slug=p_slug limit 1),
  jsonb_build_object('configured',false,'enabled',false));
$$;

revoke all on function app.managed_radio_sync_manifest(text) from public,anon,authenticated;
grant execute on function app.managed_radio_sync_manifest(text) to service_role;
revoke all on function public.tarteel_public_managed_radio_config(text) from public;
grant execute on function public.tarteel_public_managed_radio_config(text) to anon,authenticated,service_role;

grant select,insert,update,delete on app.managed_radio_configs to service_role;
grant select,insert,update,delete on app.managed_radio_event_bindings to service_role;
grant select,insert,update,delete on app.managed_radio_sync_runs to service_role;
