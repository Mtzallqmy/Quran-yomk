-- DESIGN ARTIFACT ONLY. Convert to ordered Supabase migrations after approval.
create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

create schema if not exists app;
create schema if not exists radio;
create schema if not exists api;

create type app.media_status as enum ('UPLOADING','PROCESSING','READY','FAILED','ARCHIVED');
create type app.station_status as enum ('ONLINE','DEGRADED','OFFLINE','MAINTENANCE');
create type app.schedule_type as enum ('ONE_TIME','DAILY','WEEKLY');
create type app.content_type as enum ('MEDIA','PLAYLIST','PROGRAM');
create type app.interrupt_policy as enum ('FINISH_CURRENT','INTERRUPT','PLAY_NEXT');
create type app.priority_level as enum ('LOW','NORMAL','HIGH','EMERGENCY','LIVE');
create type radio.command_type as enum ('PLAY_NOW','PLAY_NEXT','SKIP','STOP_AFTER_CURRENT','RESUME_AUTO','START_LIVE','STOP_LIVE');
create type radio.command_status as enum ('PENDING','PROCESSING','COMPLETED','FAILED','CANCELLED');
create type radio.engine_mode as enum ('STARTING','AUTO','SCHEDULED','MANUAL','LIVE','RECOVERING','ERROR','STOPPED');
create type radio.occurrence_status as enum ('PENDING','CLAIMED','PLAYING','COMPLETED','SKIPPED','FAILED','CANCELLED');

create function app.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;
revoke all on function app.set_updated_at() from public, anon, authenticated;

create table app.roles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z_]+$'),
  name text not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table app.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[a-z]+([.:_-][a-z]+)*$'),
  description text not null,
  created_at timestamptz not null default now()
);
create table app.role_permissions (
  role_id uuid not null references app.roles(id) on delete cascade,
  permission_id uuid not null references app.permissions(id) on delete cascade,
  created_at timestamptz not null default now(), primary key (role_id, permission_id)
);
create table app.administrators (
  id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null, is_active boolean not null default true,
  last_login_at timestamptz, created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table app.administrator_roles (
  administrator_id uuid not null references app.administrators(id) on delete cascade,
  role_id uuid not null references app.roles(id) on delete restrict,
  granted_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), primary key (administrator_id, role_id)
);

create table app.categories (
  id uuid primary key default gen_random_uuid(), parent_id uuid references app.categories(id) on delete restrict,
  slug text not null unique, name_ar text not null, name_en text,
  is_active boolean not null default true, sort_order integer not null default 0,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table app.reciters (
  id uuid primary key default gen_random_uuid(), name_ar text not null, name_en text,
  image_url text, country text, rewaya text, description text,
  search_name_ar text, search_name_en text, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table app.surahs (
  id smallint primary key, number smallint not null unique check (number between 1 and 114),
  name_ar text not null, name_en text not null, ayah_count smallint not null check (ayah_count > 0),
  created_at timestamptz not null default now(), check (id = number)
);
create table app.media (
  id uuid primary key default gen_random_uuid(), title text not null, description text,
  category_id uuid references app.categories(id) on delete restrict,
  reciter_id uuid references app.reciters(id) on delete set null,
  original_path text not null unique, processed_path text unique,
  duration_ms bigint check (duration_ms > 0), format text, bitrate_kbps integer check (bitrate_kbps > 0),
  sample_rate_hz integer check (sample_rate_hz > 0), channels smallint check (channels between 1 and 8),
  file_size_bytes bigint not null check (file_size_bytes > 0), sha256 text check (sha256 ~ '^[0-9a-f]{64}$'),
  status app.media_status not null default 'UPLOADING', processing_profile_version text,
  metadata jsonb not null default '{}'::jsonb, failure_code text, failure_message text,
  created_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  check ((status <> 'READY') or (processed_path is not null and duration_ms is not null and sha256 is not null))
);
create table app.media_processing_jobs (
  id uuid primary key default gen_random_uuid(), media_id uuid not null references app.media(id) on delete cascade,
  idempotency_key text not null unique, status app.media_status not null,
  attempts smallint not null default 0 check (attempts >= 0), profile_version text not null,
  claimed_by text, claimed_at timestamptz, heartbeat_at timestamptz,
  error_code text, error_message text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table app.reciter_tracks (
  id uuid primary key default gen_random_uuid(), reciter_id uuid not null references app.reciters(id) on delete restrict,
  surah_id smallint not null references app.surahs(id) on delete restrict,
  media_id uuid references app.media(id) on delete restrict, audio_url text,
  duration_ms bigint check (duration_ms > 0), quality text not null,
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (media_id is not null or audio_url is not null), unique (reciter_id, surah_id, quality)
);

create table app.stations (
  id uuid primary key default gen_random_uuid(), name_ar text not null, name_en text,
  slug text not null unique check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'), description text, logo_url text,
  stream_url text not null, fallback_stream_url text, timezone text not null,
  status app.station_status not null default 'OFFLINE', default_playlist_id uuid,
  is_active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table app.playlists (
  id uuid primary key default gen_random_uuid(), station_id uuid not null references app.stations(id) on delete restrict,
  name text not null, description text, shuffle boolean not null default false, repeat boolean not null default true,
  is_active boolean not null default true, version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  unique (station_id, name), unique (station_id, id)
);
alter table app.stations add constraint stations_default_playlist_fk
  foreign key (id, default_playlist_id) references app.playlists(station_id, id);
create table app.playlist_items (
  id uuid primary key default gen_random_uuid(), playlist_id uuid not null references app.playlists(id) on delete cascade,
  media_id uuid not null references app.media(id) on delete restrict,
  position integer not null check (position >= 0), weight integer not null default 1 check (weight > 0),
  created_at timestamptz not null default now(), unique (playlist_id, position)
);
create table app.programs (
  id uuid primary key default gen_random_uuid(), station_id uuid not null references app.stations(id) on delete restrict,
  name text not null, description text, is_active boolean not null default true,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  unique (station_id, id)
);
create table app.program_items (
  id uuid primary key default gen_random_uuid(), program_id uuid not null references app.programs(id) on delete cascade,
  media_id uuid not null references app.media(id) on delete restrict, position integer not null check (position >= 0),
  created_at timestamptz not null default now(), unique (program_id, position)
);

create table app.schedules (
  id uuid primary key default gen_random_uuid(), station_id uuid not null references app.stations(id) on delete restrict,
  name text not null, content_type app.content_type not null,
  media_id uuid references app.media(id) on delete restrict, playlist_id uuid,
  program_id uuid, schedule_type app.schedule_type not null,
  start_date date not null, end_date date, start_time time not null, days_of_week smallint[], timezone text not null,
  priority app.priority_level not null default 'NORMAL', interrupt_policy app.interrupt_policy not null default 'FINISH_CURRENT',
  enabled boolean not null default true, next_run_at timestamptz, version integer not null default 1 check (version > 0),
  created_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  check (end_date is null or end_date >= start_date),
  check (days_of_week is null or days_of_week <@ array[0,1,2,3,4,5,6]::smallint[]),
  check ((content_type='MEDIA' and media_id is not null and playlist_id is null and program_id is null)
      or (content_type='PLAYLIST' and playlist_id is not null and media_id is null and program_id is null)
      or (content_type='PROGRAM' and program_id is not null and media_id is null and playlist_id is null)),
  check ((schedule_type='ONE_TIME' and end_date is null and days_of_week is null)
      or (schedule_type='DAILY' and days_of_week is null)
      or (schedule_type='WEEKLY' and days_of_week is not null and cardinality(days_of_week) > 0)),
  foreign key (station_id, playlist_id) references app.playlists(station_id, id) on delete restrict,
  foreign key (station_id, program_id) references app.programs(station_id, id) on delete restrict
);
create table app.schedule_templates (
  id uuid primary key default gen_random_uuid(), station_id uuid not null references app.stations(id) on delete restrict,
  code text not null, name text not null, active_from date, active_to date, is_active boolean not null default false,
  version integer not null default 1, created_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  unique (station_id, code, version), check (active_to is null or active_from is null or active_to >= active_from)
);
create table app.schedule_template_items (
  id uuid primary key default gen_random_uuid(), template_id uuid not null references app.schedule_templates(id) on delete cascade,
  definition jsonb not null, position integer not null check (position >= 0), created_at timestamptz not null default now(),
  unique (template_id, position)
);

create table radio.schedule_occurrences (
  id uuid primary key default gen_random_uuid(), schedule_id uuid not null references app.schedules(id) on delete restrict,
  station_id uuid not null references app.stations(id) on delete restrict, occurrence_key text not null,
  scheduled_for timestamptz not null, local_date date not null, local_time time not null, timezone text not null, fold smallint not null default 0,
  priority app.priority_level not null, interrupt_policy app.interrupt_policy not null,
  status radio.occurrence_status not null default 'PENDING', claimed_by text, claimed_at timestamptz,
  started_at timestamptz, finished_at timestamptz, result jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique (schedule_id, occurrence_key)
);
create table radio.radio_commands (
  id uuid primary key default gen_random_uuid(), station_id uuid not null references app.stations(id) on delete restrict,
  command_type radio.command_type not null, payload jsonb not null default '{}'::jsonb,
  priority app.priority_level not null default 'NORMAL', status radio.command_status not null default 'PENDING',
  idempotency_key text not null, created_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), claimed_by text, claimed_at timestamptz,
  executed_at timestamptz, error_code text, error_message text, updated_at timestamptz not null default now(),
  unique (station_id, idempotency_key)
);
create table radio.station_leases (
  station_id uuid primary key references app.stations(id) on delete cascade,
  owner_id text not null, fencing_token bigint not null check (fencing_token > 0),
  acquired_at timestamptz not null, renewed_at timestamptz not null, expires_at timestamptz not null,
  check (expires_at > renewed_at)
);
create table radio.engine_states (
  station_id uuid primary key references app.stations(id) on delete cascade,
  mode radio.engine_mode not null, previous_valid_mode radio.engine_mode,
  fencing_token bigint not null, revision bigint not null default 1,
  current_source_type text, current_source_id uuid, current_queue_item_id uuid,
  position_ms bigint check (position_ms is null or position_ms >= 0),
  state_data jsonb not null default '{}'::jsonb, last_checkpoint_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create table radio.queue_snapshots (
  station_id uuid primary key references app.stations(id) on delete cascade,
  revision bigint not null, fencing_token bigint not null, snapshot jsonb not null,
  checksum text not null, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table radio.now_playing (
  station_id uuid primary key references app.stations(id) on delete cascade,
  mode radio.engine_mode not null, status app.station_status not null,
  media_id uuid references app.media(id) on delete set null, title text, artist text,
  started_at timestamptz, expected_end_at timestamptz, duration_ms bigint,
  next_media_id uuid references app.media(id) on delete set null, next_title text,
  revision bigint not null, updated_at timestamptz not null default now()
);
create table radio.radio_events (
  id bigint generated always as identity primary key, station_id uuid not null references app.stations(id) on delete restrict,
  event_type text not null, command_id uuid references radio.radio_commands(id) on delete set null,
  occurrence_id uuid references radio.schedule_occurrences(id) on delete set null,
  media_id uuid references app.media(id) on delete set null, fencing_token bigint,
  data jsonb not null default '{}'::jsonb, occurred_at timestamptz not null default now()
);
create table radio.play_history (
  id bigint generated always as identity primary key, station_id uuid not null references app.stations(id) on delete restrict,
  media_id uuid references app.media(id) on delete set null, source_type text not null, source_id uuid,
  started_at timestamptz not null, ended_at timestamptz, result text, played_ms bigint,
  command_id uuid references radio.radio_commands(id) on delete set null,
  occurrence_id uuid references radio.schedule_occurrences(id) on delete set null,
  created_at timestamptz not null default now()
);

create table app.app_config (
  key text primary key, value jsonb not null, is_public boolean not null default false,
  description text, updated_by uuid references app.administrators(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table app.audit_logs (
  id bigint generated always as identity primary key, actor_id uuid references app.administrators(id) on delete set null,
  action text not null, resource_type text not null, resource_id text,
  request_id uuid, ip_hash text, metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create table app.system_logs (
  id bigint generated always as identity primary key, timestamp timestamptz not null default now(),
  service text not null, level text not null check (level in ('DEBUG','INFO','WARN','ERROR','FATAL')),
  station_id uuid references app.stations(id) on delete set null, event text not null,
  request_id uuid, command_id uuid, media_id uuid, message text not null, error jsonb, fields jsonb not null default '{}'::jsonb
);
create table app.service_heartbeats (
  service_instance_id text primary key, service text not null, station_id uuid references app.stations(id) on delete cascade,
  status text not null, version text not null, details jsonb not null default '{}'::jsonb,
  started_at timestamptz not null, last_seen_at timestamptz not null
);
create table app.station_metrics_minute (
  station_id uuid not null references app.stations(id) on delete cascade, bucket_at timestamptz not null,
  current_listeners integer not null default 0, peak_listeners integer not null default 0,
  stream_errors integer not null default 0, buffering_reports integer not null default 0,
  primary key (station_id, bucket_at)
);

create index media_filter_idx on app.media (status, category_id, reciter_id, created_at desc) where deleted_at is null;
create index reciters_search_ar_idx on app.reciters using gin (search_name_ar gin_trgm_ops) where deleted_at is null;
create index playlist_items_order_idx on app.playlist_items (playlist_id, position);
create index schedules_due_idx on app.schedules (next_run_at, priority) where enabled and deleted_at is null;
create index occurrences_due_idx on radio.schedule_occurrences (station_id, scheduled_for, priority) where status='PENDING';
create index commands_pending_idx on radio.radio_commands (station_id, priority desc, created_at, id) where status='PENDING';
create index events_station_time_idx on radio.radio_events (station_id, occurred_at desc);
create index play_history_station_time_idx on radio.play_history (station_id, started_at desc);
create index audit_resource_idx on app.audit_logs (resource_type, resource_id, created_at desc);
create index logs_service_time_idx on app.system_logs (service, timestamp desc);

do $$ declare r record; begin
  for r in
    select table_schema, table_name from information_schema.columns
    where column_name = 'updated_at' and table_schema in ('app','radio')
  loop
    execute format('create trigger set_updated_at before update on %I.%I for each row execute function app.set_updated_at()',
      r.table_schema, r.table_name);
  end loop;
end $$;

do $$ declare r record; begin
  for r in select schemaname, tablename from pg_tables where schemaname in ('app','radio') loop
    execute format('alter table %I.%I enable row level security', r.schemaname, r.tablename);
  end loop;
end $$;

-- Intentionally no anon/authenticated grants here. API projections and exact
-- policies are separate reviewed migrations after approval.
