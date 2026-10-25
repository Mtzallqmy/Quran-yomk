-- Provider-owned Quran audio metadata only. Audio bytes remain on the
-- provider CDN and are never copied into Supabase Storage by this feature.
create table public.quran_audio_sources (
  id uuid primary key default gen_random_uuid(),
  reciter text not null check (length(trim(reciter)) > 0),
  riwayah text,
  surah smallint not null check (surah between 1 and 114),
  ayah integer check (ayah is null or ayah between 1 and 6236),
  provider text not null check (provider in ('ALQURAN_CLOUD', 'MP3QURAN')),
  edition text not null check (edition ~ '^[A-Za-z0-9._-]+$'),
  bitrate integer check (bitrate is null or bitrate between 16 and 512),
  playback_url text not null check (playback_url ~ '^https://'),
  download_url text not null check (download_url ~ '^https://'),
  expected_size bigint check (expected_size is null or expected_size > 0),
  checksum text check (checksum is null or checksum ~ '^[0-9a-f]{64}$'),
  rehosting_allowed boolean not null default false,
  rights_status app.rights_status not null default 'REVIEW_REQUIRED',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index quran_audio_sources_identity_uidx
on public.quran_audio_sources (
  provider,
  edition,
  surah,
  coalesce(ayah, 0),
  coalesce(bitrate, 0)
);

create index quran_audio_sources_catalog_idx
on public.quran_audio_sources (surah, provider, edition, bitrate)
where rights_status = 'APPROVED';

create trigger quran_audio_sources_updated_at
before update on public.quran_audio_sources
for each row execute function app.set_updated_at();

alter table public.quran_audio_sources enable row level security;

create policy quran_audio_sources_public_read
on public.quran_audio_sources
for select
to anon, authenticated
using (rights_status = 'APPROVED');

revoke all on table public.quran_audio_sources from public, anon, authenticated;
grant select on table public.quran_audio_sources to anon, authenticated;
grant all on table public.quran_audio_sources to service_role;

comment on table public.quran_audio_sources is
  'Metadata pointers to provider-hosted Quran audio; contains no audio blobs.';
comment on column public.quran_audio_sources.rehosting_allowed is
  'False unless the provider has explicitly documented redistribution rights.';
