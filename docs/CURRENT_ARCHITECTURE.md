# Tarteel — Current Architecture

Status: **As implemented**, audited from `feature/reciter-offline-ux-remote-updates` at `ea2be74220b59900104d92a3199eed9deb1570c2` plus the connected DEVELOPMENT Supabase project on 2026-09-02.

This document records the current system. It is not a target architecture and does not authorize refactors by itself.

## 1. System context

Tarteel is a monorepo containing:

- `apps/mobile`: Flutter listener application.
- `apps/admin`: Next.js administration application and server routes.
- `supabase`: PostgreSQL migrations/tests plus Supabase Edge Functions.
- `services/radio-engine`: long-running TypeScript radio control/runtime service.
- `services/audio-worker`: server-side audio processing worker using FFmpeg/ffprobe.
- `services/tarteel-api-elysia`: optional Elysia/Bun API layer introduced as a compatibility/BFF experiment.
- `packages/api-types`: TypeScript API/storage/audio-processing contracts.
- `infrastructure/icecast` and `infrastructure/liquidsoap`: managed radio playout infrastructure.
- `.github/workflows`: Android release, Mushaf assets, Elysia, radio real-E2E and historical phase workflows.

## 2. Current public application path

The Flutter application currently uses the Supabase Edge Function as its default public API:

```text
Flutter Mobile
    |
    v
Supabase Edge Function: tarteel-api
    |
    +--> PostgreSQL/PostgREST RPCs
    +--> AlQuran Cloud for live Quran text/Tajweed requests
    +--> MP3Quran for reciter/track discovery
    |
    +--> direct external stream/audio URLs returned to Flutter
```

`TarteelApiClient.productionBaseUrl` points to `/functions/v1/tarteel-api`. The mobile client carries a Supabase **publishable** key as a public client credential; it is not treated as a server secret.

The Edge Function is currently the de-facto public contract because the production Flutter client calls it directly. Elysia is not yet the canonical public API.

## 3. Mobile composition and startup

`apps/mobile/lib/main.dart` currently initializes multiple services before `runApp`, including:

- central `TarteelAudioHandler` and audio session;
- SharedPreferences;
- Mushaf page repository;
- Islamic content repository;
- offline clip service;
- Quran download service;
- Quran audio providers/repository;
- settings/favorites/playback history/playlists;
- remote config service.

`AppServices` is the current composition container. Remote Config refresh is already non-blocking after construction, but multiple repositories that are not strictly necessary for the first frame are still awaited before the UI starts.

The central audible player remains `PlaybackPort` / `TarteelAudioHandler`; Quran, radio and offline playback should continue to use it.

## 4. Quran data flow

Current text flow:

```text
Flutter Mushaf/Text UI
    |
    v
Supabase tarteel-api /quran/{surah|juz|page}/N
    |
    +--> live AlQuran Cloud quran-uthmani
    +--> live AlQuran Cloud quran-tajweed
    |
    v
Normalized verse DTO
```

The current implementation normalizes `surah_number`, `ayah_number`, `verse_key`, page/juz/ruku and text fields, but the approved Quran text is **not yet a pinned, versioned canonical dataset**. This is a P0 integrity gap documented separately in the audit.

## 5. Mushaf page flow

The image-based Mushaf has two editions:

- `MADINAH_HAFS_SVG`: QuranPedia SVG source pinned in code to a Git revision.
- `MADINAH_TAJWEED_QCF_V4`: generated WebP pages with bounds metadata.

The mobile `MushafPageRepository` is local-first:

```text
Local validated page/cache
    |
    +-- missing --> immutable/versioned Supabase Storage path
                      |
                      +-- compatibility fallback assets when configured
```

The repository uses per-file/pack SHA-256 validation when manifests/checksum data are available and supports full offline packs. Page count is fixed at 604.

## 6. Quran audio flow

There are currently three implementations touching Quran provider logic:

1. Flutter `QuranAudioRepository` and provider adapters.
2. Supabase Edge `tarteel-api/quran.ts` for MP3Quran public reciter/track endpoints.
3. Optional Elysia API for Quran reciter discovery/audio resolution.

Flutter behavior:

```text
Selected reciter + Surah/Ayah
    |
    v
QuranAudioRepository
    |
    +--> selected provider only when reciter is explicit
    |
    +--> verified local download, if present
    |        OR
    +--> direct provider streaming URL
    v
TarteelAudioHandler
```

The Flutter repository now rejects resolved media whose reciter identity differs from the explicit selection. Downloads are direct provider -> device and are validated locally; external audio is not automatically re-hosted in Supabase Storage.

## 7. Offline audio flow

`QuranDownloadService` stores task metadata locally and downloads to application documents storage.

Identity/cache lookup uses a storage key containing provider, reciter identity, bitrate, surah and optional ayah. Completed files require local SHA-256 validation before reuse. Resume uses HTTP Range where supported, with redirect bounds and network timeouts.

Offline library, recent playback and playlists are local-first. They persist reciter/provider identity metadata so the UI can group content by the selected reciter.

## 8. Radio catalog and virtual radio flow

Listener-side external/virtual radio is separate from the owned internal Icecast runtime.

Public virtual-radio resolver path:

```text
Flutter
  -> tarteel-api
  -> app.resolve_virtual_radio / public RPC layer
  -> schedule/candidate selection
  -> selected external station URL
  -> Flutter streams provider directly
```

The current DEVELOPMENT database has RLS enabled on `app.virtual_radio_channels`, `app.virtual_radio_schedule`, and `app.virtual_radio_candidates`. Their authenticated policies invoke `app.managed_radio_authorized(...)` for `schedules.read` / `schedules.write`; there is no anonymous write policy in the audited state.

## 9. Managed internal radio runtime

The internal radio path is:

```text
Scheduler / persisted occurrence
    -> claim with fencing
    -> persistent queue materialization
    -> command/effect processing
    -> Radio Engine
    -> Liquidsoap
    -> Icecast fixed mount
    -> listener/decoder
    -> Liquidsoap playout ACK
    -> PostgreSQL play history + now playing
```

Implemented components exist in `services/radio-engine` for scheduler loops, queue management, commands, leases/fencing, source control, ACK handling, recovery and health checks.

Phase 6 proved the database protection path and the real Liquidsoap/Icecast audio path, including two listeners and a 30-minute soak, but **not in one single secret-backed coordinator runtime**. That integration closure remains open.

## 10. Audio worker flow

`services/audio-worker` is a separate server-side processing worker:

```text
PostgreSQL processing job
    -> lease/claim
    -> local temp workspace
    -> FFmpeg / ffprobe
    -> processed variant/storage result
    -> attempt/job state
```

It uses a server-only Supabase secret key and explicit worker lease, heartbeat, timeout and retry configuration.

## 11. Admin flow

Current admin path:

```text
Browser
  -> Next.js Admin server routes
  -> Supabase Auth session cookies
  -> server-side administrator/role/permission lookup
  -> Next.js admin business/API layer and/or Supabase RPC / Edge Function
  -> database / managed radio control plane
```

Admin session cookies are HttpOnly, SameSite=Lax and conditionally Secure in production configuration. Access tokens are refreshed server-side from a refresh cookie. Authorization is checked server-side using administrator membership, roles and permissions.

Mutation routes inspected for Runtime Config and Managed Radio call same-origin validation and a rate limiter. The current limiter is process-local memory and therefore is not sufficient as the final production limiter for horizontally scaled sensitive routes.

## 12. Runtime configuration

Runtime configuration is stored in `app.app_config` and exposed through the public API only for public keys. The mobile `RemoteConfigService` uses cached values and refreshes non-blockingly.

The admin runtime-config route uses an explicit allow-list and validates the content manifest. The manifest is non-executable; code/script/eval-style fields are rejected. This mechanism is intended for feature flags, ordering and content metadata—not remote Dart/code execution.

## 13. Database ownership

Current schemas include:

- `app`: roles, permissions, administrators, Quran metadata, stations/providers, media/processing, schedules, runtime config, audit/system logs, virtual/managed radio configuration.
- `radio`: schedule occurrences, commands, leases, queue entries/effects, engine state, now playing, events and play history.

The connected DEVELOPMENT database had RLS enabled for every audited application/radio table returned by the database inventory. Public reads are primarily mediated by SECURITY DEFINER functions/RPCs and the Edge API. SECURITY DEFINER functions therefore require continued grant/search-path/regression review.

Migrations are historical and append-only. No migration is to be deleted or squashed as part of hardening without a deployment-specific migration plan.

## 14. External providers

Current important external providers include:

- AlQuran Cloud / Islamic Network: Quran text/Tajweed and Quran audio.
- MP3Quran: reciters, moshaf/riwayah metadata and audio servers.
- external radio providers represented in the catalog.
- Supabase Storage for Tarteel-owned/versioned application assets and Mushaf packs where rights/provenance gates permit.

Rights policy remains: a public URL does not imply redistribution permission. Direct provider URLs remain the default for third-party Quran audio unless re-hosting rights are explicitly approved.

## 15. API surfaces and duplication observed

Current API/control surfaces are:

- Supabase Edge `tarteel-api`: de-facto public mobile API.
- Supabase Edge managed-radio functions.
- Next.js Admin API routes.
- PostgreSQL RPC/SECURITY DEFINER functions.
- optional Elysia API.

Important business logic is duplicated across some of these layers, especially Quran reciter/provider normalization and identity representation. No API surface is removed by this audit.

## 16. CI/CD flow

Current workflows include Android release, Elysia validation, Mushaf asset production, real Icecast/radio phase validation and beta publishing.

The Android workflow currently combines:

- formatting (mutating `dart format`);
- static analysis/tests;
- live external provider tests;
- APK build/ABI/minSdk validation;
- Android 8 emulator acceptance;
- artifact/release operations.

This is functional but not yet separated into deterministic PR CI, external-provider CI and release CI.

## 17. Environment-variable ownership

Server-secret variables include Supabase secret keys and Icecast source/admin credentials. Publishable Supabase keys are public client credentials, not secrets.

Important variable groups:

- Mobile build-time: public API/asset base URLs and publishable key.
- Admin: Supabase URL, publishable key, server secret key, cookie security and radio public configuration.
- Audio Worker: Supabase server secret, worker identity/lease/timeouts, FFmpeg paths.
- Radio Engine: Supabase server secret, station/engine identity, Liquidsoap/Icecast credentials and runtime timing settings.

Secrets must remain server-side and must not be placed in APK artifacts.

## 18. Domain ownership map

| Domain | Current primary owner | Secondary/compatibility surfaces |
|---|---|---|
| Listener UI/state | Flutter | — |
| Audible playback | Flutter `TarteelAudioHandler` | Android media service integration |
| Public catalog API | Supabase `tarteel-api` | PostgreSQL public RPCs |
| Quran text | Supabase Quran Edge adapter + AlQuran Cloud | Flutter consumes normalized DTO |
| Quran audio | Flutter providers/repository | Supabase Quran endpoints; Elysia duplicate path |
| Offline Quran audio | Flutter download service | external provider CDN |
| Mushaf pages | Flutter Mushaf repository | Supabase Storage/versioned asset pipeline |
| Admin auth/RBAC | Next.js server + Supabase Auth/RBAC tables | PostgreSQL permissions |
| Runtime config | `app.app_config` | Next.js Admin route + public Edge endpoint |
| External radio catalog | Supabase/PostgreSQL | Edge public API |
| Internal managed radio | Radio Engine | PostgreSQL radio/app schemas |
| Playout | Liquidsoap + Icecast | Radio Engine control/ACK |
| Media processing | Audio Worker | PostgreSQL + Storage |
| Optional API consolidation | Elysia | currently non-canonical |

## 19. Audit conclusion

The repository is a mature multi-component system and should be consolidated incrementally. The largest architecture fact to preserve is that the current production mobile contract is still the Supabase Edge API, while Elysia is parallel/optional. The highest-risk integrity fact is that Quran text is still read live from a mutable external API. The largest radio readiness gap is the missing single-runtime secret-backed Phase 6B acceptance.

No architecture change is authorized by this document; follow-up changes require dedicated ADRs/PRs and compatibility tests.
