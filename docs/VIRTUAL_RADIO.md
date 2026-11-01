# إذاعة ترتيل الافتراضية — Phase 11

## Architecture

Phase 11 intentionally runs without a permanent radio server:

```text
Flutter
  -> Tarteel Supabase Edge API
     -> PostgreSQL virtual schedule/resolver
        -> normalized external station
Flutter
  -> direct HTTPS stream operated by the external provider/broadcaster
```

There is no continuous audio proxy through Supabase. The dormant Icecast,
Liquidsoap and legacy Radio Engine remain in the repository for a possible
future owned-station phase, but Phase 11 does not start or depend on them.

## Virtual vs owned radio

`إذاعة ترتيل` / `Tarteel Radio` is a stable logical channel. It is not an
Icecast mount and it is not presented as a Tarteel-owned rebroadcast. The
server resolves the current editorial program to an eligible external source.
The audio notification keeps the Tarteel logical channel/program identity while
showing source attribution secondarily where appropriate.

## Data model

- `app.virtual_radio_channels`: logical channel identity, artwork, timezone and enable state.
- `app.virtual_radio_schedule`: recurring time ranges, program titles, desired/fallback category and preferred source.
- `app.virtual_radio_candidates`: explicit ordered fallback candidates for a slot.

The Phase 11 schedule is independent from the legacy `app.schedules` / radio
command/queue semantics.

## Time and schedule

The channel stores an IANA timezone. The Development channel uses `Asia/Aden`.
`app.resolve_virtual_radio` evaluates an authoritative server timestamp in that
timezone; the phone clock does not select the current program.

The seed Development schedule currently contains six editorial ranges covering
Quran, adhkar, reciters, tafsir and hadith. Operators can edit the schedule
through the Phase 11 Admin API/UI.

## Deterministic resolution

For the current slot, the resolver ranks sources in this order:

1. explicitly preferred station;
2. explicit enabled candidates ordered by priority;
3. healthy station matching desired category + preferred provider;
4. healthy station matching desired category;
5. healthy station matching fallback category.

`HEALTHY` is preferred before `DEGRADED`. Only HTTPS URLs are selected. In
Development, the station must be marked `PLAYABLE_IN_DEVELOPMENT` or
`APPROVED_FOR_PUBLIC_RELEASE`. Public-release resolution additionally requires
the existing rights/production gate.

## Failover

The listener can send up to eight failed Tarteel station IDs to:

`GET /virtual-radio/tarteel?failed_station_ids=<uuid,...>`

The server excludes those candidates and deterministically resolves another
source. Flutter keeps the logical `إذاعة ترتيل` identity, releases/switches the
physical URL through the same `TarteelAudioHandler`, and bounds retry/fallback
attempts. It never opens a second audible player.

## Schedule handoff

The response includes `next_change_at`. Flutter schedules a boundary refresh.
If the next program resolves to the same station, only metadata is updated. If
the source changes, the single centralized player switches once and preserves
the `audio_service` session.

## Public API response

The endpoint returns only listener-safe fields: logical channel, current
program, resolved station metadata/playback URL, next program/change time,
server time and a minimal resolution tier. Privileged database fields are not
returned.

## Flutter behavior

Phase 11 reuses:

- Riverpod and `servicesProvider`
- `TarteelRepository` / `TarteelApiClient`
- cache-first station catalog
- `FavoritesStore`
- `just_audio`
- `audio_service`
- `audio_session`
- one `TarteelAudioHandler`

Live streams have no seek/speed controls. The full player provides Play/Pause,
Stop, buffering state and local player gain (0–100%). Android system volume
buttons remain system/device volume.

## HTTP security

Android production keeps `usesCleartextTraffic="false"`. HTTP-only catalog
entries may remain auditable in the database, but the Flutter player rejects
plain HTTP. Tarteel does not globally weaken Android network policy to rescue an
insecure third-party stream.

## Future owned stream

The logical channel contract is intentionally stable. A future phase could
resolve `إذاعة ترتيل` to a Tarteel-owned stream instead of an external source
without redesigning listener navigation or favorites/media metadata.
