# TARTEEL — Managed Radio Integration

## Runtime architecture

`Supabase schedule/catalog → Tarteel Managed Radio Edge Function → Radio.co → fixed Tarteel stream → Flutter`

For the ordinary **إذاعات القرآن** catalog, Flutter continues to play approved external station URLs directly. Only the logical **إذاعة ترتيل** channel switches to the managed fixed stream when the provider configuration is enabled.

Phase 11 does **not** require a VPS, Icecast, or Liquidsoap. The previous radio-engine/Icecast implementation remains in the repository as dormant future infrastructure and is not deleted.

## Source of truth

Supabase remains the source of truth for:

- channel identity and timezone (`Asia/Aden`)
- program start/end time
- daily/weekly recurrence
- primary preferred relay station
- secondary candidate relays
- backup playlist provider ID
- enable/disable state
- sync status and provider bindings

The managed provider is playout infrastructure only.

## ManagedRadioService

The first adapter is `RadioCoManagedRadioService` in `supabase/functions/tarteel-managed-radio/index.ts`.

Public Radio.co reads used by the adapter:

- `GET https://public.radio.co/api/v2/{station}` — station information and streaming links
- `GET https://public.radio.co/stations/{station}/status` — station/source state
- `GET https://public.radio.co/api/v2/{station}/track/current` — Now Playing
- `GET https://public.radio.co/stations/{station}/embed/schedule` — provider schedule view

Write operations (`SYNC_SCHEDULE`, `TEST_RELAY`) are deliberately not tied to guessed or undocumented Studio API paths. Their exact write endpoint and authorization contract must be configured as Supabase Edge secrets after a Radio.co station/account is provisioned.

## Supabase Edge secrets

Provider credentials must exist only in the Edge runtime. Flutter must never receive them.

Required for public provider status/final stream discovery:

- `RADIOCO_STATION_ID`

Required before live provider mutations are allowed:

- `RADIOCO_STUDIO_AUTHORIZATION`
- `RADIOCO_STUDIO_SCHEDULE_SYNC_URL`
- `RADIOCO_STUDIO_RELAY_TEST_URL`

If those values are absent, the service returns a deterministic `BLOCKED` result (`RADIOCO_ACCOUNT_NOT_CONFIGURED` or `RADIOCO_STUDIO_API_NOT_CONFIGURED`) instead of claiming a successful relay or schedule sync.

## Fixed stream contract

When `app.managed_radio_configs.enabled=true` and an HTTPS `fixed_stream_url` is present:

- the public virtual-radio response uses `mode=MANAGED`
- `playback.kind=MANAGED_RADIO`
- `playback.seekable=false`
- Flutter receives the fixed managed URL as `station.playback_url`
- the selected external source is exposed separately as `relay_source` for administration/observability
- Flutter does not connect to the external relay source for **إذاعة ترتيل**

When the provider is not configured, development remains in `DIRECT_FALLBACK`; this is not considered managed-radio production acceptance.

## Fallback contract

Provider playout order is:

1. `PRIMARY_RELAY`
2. `SECONDARY_RELAY`
3. `BACKUP_PLAYLIST`

Supabase stores the authoritative schedule/candidates and provider binding metadata. The provider executes the actual transitions so all listeners hear the same output from one fixed stream URL.

## Admin

`/managed-radio` inside the existing Next.js admin exposes:

- provider/configuration status
- current and next program
- today schedule
- current editorial relay source
- fixed stream URL
- provider Now Playing
- recent sync/relay operations
- Refresh Status
- Refresh Now Playing
- Sync Schedule
- Test Relay

All mutations require the existing administrator session and `schedules.write` permission. Provider secrets do not enter browser JavaScript.

## Flutter

The existing `just_audio` + `audio_service` + `audio_session` + Riverpod player is reused. Live streams do not render a seek bar, and the logical media identity remains **إذاعة ترتيل** even when the managed provider changes relay source behind the fixed stream.

## Explicitly out of scope

Microphone / Live DJ activation is not started in this phase. The managed provider may support those features, but no microphone capture or live-DJ start command is implemented here.

## Current activation state

The Radio.co adapter, database contract, Edge Function, Admin integration, and Flutter fixed-stream contract are implemented. Live provider acceptance remains blocked until a real Radio.co station/account and its exact Studio write API authorization/endpoint contract are configured in Supabase Edge secrets.
