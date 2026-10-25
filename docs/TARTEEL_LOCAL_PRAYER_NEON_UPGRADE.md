# Tarteel 0.7.4 (2074) — Local Prayer & Neon Upgrade

## Verified baseline (2026-10-23)
- **Installable application source:** `apps/mobile` (Flutter), branch `fix/offline-downloads-recording-alarms-2074`.
- **Existing app identity:** `app.tarteel.tarteel` — MUST NOT change.
- **Existing version:** `0.7.4+74`; arm64 split APK displays version code **2074**. Next arm64 build needs a code greater than 2074 to support in-place upgrade.
- `main/app` is a DIFFERENT Android/Kotlin project with application ID `app.quranyutla`, not an in-place upgrade path.
- Existing functional modules: `prayer_times.dart`, `prayer_reminders.dart`, `local_notifications.dart`, `adhan_audio.dart`, `adhan_library.dart`, native `LocalAlarmAudioService`/`LocalAudioAlarmReceiver`.
- Prayer calculations already use local `adhan_dart`, local settings and timezones; the upgrade should **improve and test**, not duplicate or discard these implementations.

## Required changes and gates
1. Keep radio streaming, Mushaf, reciters, audio service, downloads, playlists, favorites and existing persisted settings untouched unless tests demonstrate a regression.
2. Remove **cloud dependency for prayer time calculation and scheduling**; ensure prayer times, before/after reminders, countdown, adhan, and adhkar reminders work fully without internet. Do not remove the app's independent remote content/announcement notification capability unless explicitly desired.
3. Ship at least **two rights-cleared built-in offline audio assets** (one adhan, one dhikr/notification sample). Do not silently treat URLs to remote recordings as embedded audio. Store user-imported media privately and use appropriate Android SAF read/copy permissions.
4. Per-prayer choices (adhan/silent/notification/off), user-selected audio, preview, adjustable lead time, local city + manual coordinates, calculation method + corrections and DST/time-zone handling. Preserve old SharedPreferences keys through migration.
5. Make alarm delivery reliable for Android 8+: request notification/exact alarm access as applicable; handle boot, package replaced, timezone/time changes, Doze, Android 13+ channels, foreground-service limits, battery policy; show permission status and guidance without promising guaranteed execution on every OEM.
6. Separate Neon from all local alarm calculations. Create a **new isolated Neon project/branch** for new *non-prayer* cloud records as required; do not move existing radio catalog or overwrite Supabase/Firebase tables without backup and validated migration. Keep privileged Neon credentials server-side and use a scoped authenticated API.
7. Design polish: preserve Arabic RTL accessibility and existing core navigation; use established palette #243B6B, #2E9E9E, #C77955, #F8F6F1, #0E1726. Match dark mode, contrast, font scale and screen-reader labels.
8. Add deterministic unit/widget tests for prayer calculations (including midnight, DST, location changes, method changes), reminder IDs, rescheduling, cancellation, offline startup, alarms and prefs migration.
9. CI should build the *Flutter* `apps/mobile` Android APK (not root Kotlin `app`). Validate package `app.tarteel.tarteel`, arm64-v8a only, minSdk 26, matching signing certificate for in-place upgrade; verify versionCode > 2074. Prefer release signing via Actions secrets, not the default debug key.
10. **Release is blocked** until source tests, CI build, APK package/signature inspection and an actual Android install/upgrade & offline alert smoke test pass. Never label an unbuilt artifact as a release.

## Implementation workstream
- A. Baseline regression inventory and test harness.
- B. Prayer + adhkar local engine and permissions.
- C. Offline audio catalog and per-prayer preferences.
- D. UI/UX refinement.
- E. Isolated Neon schema/API for non-prayer cloud needs.
- F. GitHub Actions validation, installable beta release and upgrade documentation.

This file records verified facts and acceptance criteria; it does **not** assert any of the above features were completed by creating this branch.
