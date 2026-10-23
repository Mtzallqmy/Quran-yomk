# Tarteel 0.9.0-beta.1 implementation and release gates

Verified application: Flutter `apps/mobile`, `app.tarteel.tarteel`, Android API26+.
Development branch: `feat/tarteel-local-prayer-neon-2074`.
Review: https://github.com/Mtzallqmy/Quran-yomk/pull/64

## Implemented

- Reused `adhan_dart`; local daily/7-day/30-day calendars, five calculation
  methods, Shafi/Hanafi Asr, manual times, corrections, coordinates and
  permission-gated location. Configured IANA zones and civil-day arithmetic
  preserve DST transitions. Civil Hijri dates are explicitly approximate.
- Per-prayer off/silent/notification/short-sound/adhan selection, local audio
  paths and player volume, before/after reminders, and the existing single
  morning/evening/sleep adhkar controller. Existing preference keys remain.
- Persisted AlarmManager schedules, boot/update/clock restoration, generation
  checks against stale/duplicate broadcasts, foreground playback with audio
  focus, bounded preparation wake lock and visible failure diagnostics.
- Permission diagnostics and a 20-second local test. Scheduled horizon is
  45 days, or 28 days when additional before/after reminders are selected;
  reopening Tarteel renews it. Force-stop/OEM restrictions can prevent delivery.
- Indigo/teal Islamic dashboard, geometric background, live countdown, RTL
  and large-text layouts. Existing radio, playback, downloads, Quran, search,
  playlists, history and local database engines remain in place.
- Two packaged offline sounds: existing CC0 adhan **sample** (~42 seconds),
  and an original CC0 1.25-second notification chime. A complete adhan can be
  imported from the phone. Manifest checksums and the reproducible generator
  are committed; no unverified full-length recording was added.
- Optional Neon favorites backup with explicit consent, installation-scoped
  secure-storage credential, API authorization, RLS, revision conflicts and
  deletion/revocation. No prayer/location/audio data is sent. Uninstalling may
  lose its credential; this is not account recovery or multi-device login.

## Verification

- Flutter format and analyze passed; analyze retains 10 informational lints,
  with no errors or warnings. Full suite: **169 tests passed**, both locally
  and on GitHub for code commit `44e3be3e5ab28cedbd982a72574f6511815c5b65`.
- Cloud API 5 tests, admin 18 tests/typecheck/production build, audio worker
  23 tests/build, radio engine 29 tests/build: passed. Elysia typecheck and
  canonical Quran checksum/integrity gates passed.
- Empty Supabase development database rebuilt and validated twice in CI.
  Three incompatible native-project historical SQL files were preserved
  byte-for-byte under `supabase/legacy/quran-yutla`; no remote DB reset or
  data migration was performed. Legacy admin config is retained under
  `docs/legacy-main` so it cannot shadow Tarteel's active configuration.
- Live production Neon HTTPS health, consent, CRUD, device isolation,
  stale-revision rejection, unknown-field rejection and revoked/forged token
  rejection passed. Test records were deleted. See TARTEEL_NEON_VERIFICATION.md.
- Existing content API smoke: stations HTTP200; Quran audio catalog HTTP200
  with **289 reciters**. The legacy `/reciters` endpoint returned no rows;
  the active Quran audio catalog endpoint remains populated.
- Android debug/native-test compilation and `lintDebug` passed in GitHub.
  ARM64 unsigned release compilation also passed: ~25.4 MB, actual split
  versionCode **2090**, `0.9.0-beta.1`, minSdk26, ARM64-only and both offline
  sounds verified by APK inspection. API26/API36 instrumentation passed:
  **8 native tests on each API (16 executions)**, including a real emulator
  screen-off local audio alarm, restoration, stale/duplicate protection and
  background microphone recording. Emulator success does not certify OEM
  behavior or a physical in-place upgrade from the signed 2074 APK.
  Unsigned artifacts cannot be installed as an update and are never published
  as a signed beta.
  Evidence: https://github.com/Mtzallqmy/Quran-yomk/actions/runs/40000394305

## Neon resources

Project `tarteel` / `calm-sky-72162812`, region `aws-eu-central-1`.
Production branch `br-wispy-paper-bahpwe0x`, isolated schema `tarteel_cloud`.
Public API: https://br-wispy-paper-bahpwe0x-tarteelcloud.compute.c-8.eu-central-1.aws.neon.tech/
Server DB credentials exist only in the Neon Function deployment environment.
Account defaults did not allow a custom suspend interval; 0.25 CU min/max,
`suspend_timeout_seconds=0`. No old Supabase/Firebase data was moved.

## Signing and publication

The published 2074 APK was inspected directly: package `app.tarteel.tarteel`,
version `0.7.4`, code `2074`, minSdk26. Its certificate SHA256 is:

`b93cac8e6b74a7aa33ebc0a151a778fd2bd3b8452badf0161b0ef78b862ac4b8`

GitHub signing preflight confirms that the original key is not available in
this branch's cache or configured Tarteel secrets. The original keystore is
required; generating another debug/release key cannot produce an in-place
update. Configure these repository Actions secrets with the matching key:

- `TARTEEL_KEYSTORE_BASE64`
- `TARTEEL_KEYSTORE_PASSWORD`
- `TARTEEL_KEY_ALIAS`
- `TARTEEL_KEY_PASSWORD`

Secrets settings: https://github.com/Mtzallqmy/Quran-yomk/settings/secrets/actions

The workflow inspects the **actual split APK** for version >2074, API26,
ARM64-only libraries, embedded audio, package ID and matching certificate.
`publish-beta.yml` additionally requires actual physical-device upgrade,
retained favorites and offline screen-off alarm results for the candidate's
exact source SHA and APK checksum. Physical-device upgrade/alert acceptance
has not been performed. No signed compatible beta or GitHub Release is claimed.

Main/Flutter unrelated histories were reconciled without replacing the root
native application's files. PR64 remains reviewable; merge/publication must
not be represented as complete while release and quality gates are blocked.
