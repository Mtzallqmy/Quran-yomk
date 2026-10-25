-- Managed Radio integration for Tarteel. Provider credentials stay in Edge Function secrets only.

create table if not exists app.managed_radio_configs (
  channel_id uuid primary key references app.virtual_radio_channels(id) on delete cascade,
  provider text not null default 'RADIO_CO' check (provider in ('RADIO_CO')),
  enabled boolean not null default false,
  station_external_id text,
  fixed_stream_url text,
  backup_playlist_external_id text,
  provider_status text,
  provider_source jsonb not null default '{}'::jsonb,
  provider_now_playing jsonb not null default '{}'::jsonb,
  last_provider_check_at timestamptz,
  last_sync_at timestamptz,
  last_sync_status text not null default 'NEVER' check (last_sync_status in ('NEVER','SUCCESS','FAILED','BLOCKED')),
  last_sync_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint managed_radio_fixed_stream_https check (fixed_stream_url is null or fixed_stream_url ~* '^https://')
);

create table if not exists app.managed_radio_sync_runs (
  id uuid primary key default gen_random_uuid(),
  channel_id uuid not null references app.virtual_radio_channels(id) on delete cascade,
  provider text not null,
  operation text not null check (operation in ('REFRESH_STATUS','SYNC_SCHEDULE','TEST_RELAY','REFRESH_NOW_PLAYING')),
  status text not null check (status in ('RUNNING','SUCCESS','FAILED','BLOCKED')),
  provider_request_id text,
  summary jsonb not null default '{}'::jsonb,
  error_code text,
  error_message text,
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists app.managed_radio_event_bindings (
  schedule_id uuid primary key references app.virtual_radio_schedule(id) on delete cascade,
  provider text not null default 'RADIO_CO',
  provider_event_id text,
  primary_relay_external_id text,
  secondary_relay_external_id text,
  backup_playlist_external_id text,
  provider_payload_hash text,
  last_synced_at timestamptz,
  last_sync_status text not null default 'NEVER' check (last_sync_status in ('NEVER','SUCCESS','FAILED','BLOCKED')),
  last_sync_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists managed_radio_sync_runs_channel_created_idx on app.managed_radio_sync_runs(channel_id,created_at desc);

alter table app.managed_radio_configs enable row level security;
alter table app.managed_radio_sync_runs enable row level security;
alter table app.managed_radio_event_bindings enable row level security;

drop trigger if exists trg_managed_radio_configs_updated_at on app.managed_radio_configs;
create trigger trg_managed_radio_configs_updated_at before update on app.managed_radio_configs for each row execute function app.set_updated_at();
drop trigger if exists trg_managed_radio_event_bindings_updated_at on app.managed_radio_event_bindings;
create trigger trg_managed_radio_event_bindings_updated_at before update on app.managed_radio_event_bindings for each row execute function app.set_updated_at();

insert into app.managed_radio_configs(channel_id,provider,enabled,last_sync_status)
select id,'RADIO_CO',false,'NEVER' from app.virtual_radio_channels where slug='tarteel'
on conflict(channel_id) do nothing;

create or replace function app.managed_radio_overview(p_slug text default 'tarteel')
returns jsonb language sql stable security definer set search_path='' as $$
  select jsonb_build_object(
    'channel',jsonb_build_object('id',c.id,'slug',c.slug,'name_ar',c.name_ar,'timezone',c.timezone),
    'provider',m.provider,
    'enabled',m.enabled,
    'configured',(m.station_external_id is not null and m.fixed_stream_url is not null),
    'station_external_id',m.station_external_id,
    'fixed_stream_url',m.fixed_stream_url,
    'backup_playlist_external_id',m.backup_playlist_external_id,
    'provider_status',m.provider_status,
    'provider_source',m.provider_source,
    'provider_now_playing',m.provider_now_playing,
    'last_provider_check_at',m.last_provider_check_at,
    'last_sync_at',m.last_sync_at,
    'last_sync_status',m.last_sync_status,
    'last_sync_error_code',m.last_sync_error_code
  )
  from app.virtual_radio_channels c
  join app.managed_radio_configs m on m.channel_id=c.id
  where c.slug=p_slug limit 1;
$$;

create or replace function public.tarteel_public_virtual_radio_managed(
  p_slug text default 'tarteel',p_environment text default 'development',
  p_exclude_station_ids uuid[] default '{}'::uuid[],p_now timestamptz default now()
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_base jsonb; v_cfg app.managed_radio_configs%rowtype; v_channel_id uuid; v_stream text; v_managed boolean:=false;
begin
  v_base:=app.resolve_virtual_radio(p_slug,p_environment,p_exclude_station_ids,p_now);
  select c.id into v_channel_id from app.virtual_radio_channels c where c.slug=p_slug limit 1;
  if v_channel_id is not null then select * into v_cfg from app.managed_radio_configs where channel_id=v_channel_id; end if;
  v_stream:=nullif(v_cfg.fixed_stream_url,'');
  v_managed:=coalesce(v_cfg.enabled,false) and v_stream is not null and v_stream~*'^https://';
  if v_managed then
    v_base:=jsonb_set(v_base,'{available}','true'::jsonb,true);
    v_base:=jsonb_set(v_base,'{mode}','"MANAGED"'::jsonb,true);
    v_base:=jsonb_set(v_base,'{playback}',jsonb_build_object('url',v_stream,'kind','MANAGED_RADIO','is_live',true,'seekable',false,'provider',v_cfg.provider),true);
  else
    v_base:=jsonb_set(v_base,'{mode}','"DIRECT_FALLBACK"'::jsonb,true);
    if coalesce(v_base->>'available','false')='true' then
      v_base:=jsonb_set(v_base,'{playback}',jsonb_build_object('url',v_base#>>'{station,playback_url}','kind','EXTERNAL_DIRECT','is_live',true,'seekable',false),true);
    end if;
  end if;
  v_base:=jsonb_set(v_base,'{managed_radio}',jsonb_build_object(
    'provider',coalesce(v_cfg.provider,'RADIO_CO'),'enabled',coalesce(v_cfg.enabled,false),
    'configured',(v_cfg.station_external_id is not null and v_stream is not null),
    'station_external_id',v_cfg.station_external_id,'fixed_stream_url',v_stream,
    'backup_playlist_external_id',v_cfg.backup_playlist_external_id,'provider_status',v_cfg.provider_status,
    'now_playing',coalesce(v_cfg.provider_now_playing,'{}'::jsonb),'last_provider_check_at',v_cfg.last_provider_check_at,
    'last_sync_at',v_cfg.last_sync_at,'last_sync_status',coalesce(v_cfg.last_sync_status,'NEVER'),'last_sync_error_code',v_cfg.last_sync_error_code
  ),true);
  return v_base;
end;
$$;

revoke all on function app.managed_radio_overview(text) from public,anon,authenticated;
grant execute on function app.managed_radio_overview(text) to service_role;
revoke all on function public.tarteel_public_virtual_radio_managed(text,text,uuid[],timestamptz) from public;
grant execute on function public.tarteel_public_virtual_radio_managed(text,text,uuid[],timestamptz) to anon,authenticated,service_role;

grant select,insert,update,delete on app.managed_radio_configs to service_role;
grant select,insert,update,delete on app.managed_radio_sync_runs to service_role;
grant select,insert,update,delete on app.managed_radio_event_bindings to service_role;
