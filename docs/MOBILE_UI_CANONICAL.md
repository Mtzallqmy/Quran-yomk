# Mobile UI canonical decision — Stage 0

Audited baseline: `main` at `73b6efac0018786ef1709105e9c81f58c9aa91c2` (2026-09-30).

## Decision

`app/` (Kotlin / Jetpack Compose, application ID `app.quranyutla`) is the canonical **future mobile UI development path**, following the requested Android-first decision. `settings.gradle.kts` includes only `:app`. The main-branch Android release workflow invokes Gradle `assembleRelease`. Android minimum remains 26; target remains 36.

This is not a claim that Compose is the current shipped application. The most recently published release `v0.7.2-beta.72` targets `402b6f8b680878871cd7924725893f6cd06bfca7` and its workflow `.github/workflows/android-release-apk.yml` builds Flutter in `apps/mobile` using `flutter build apk`. The release branch has no root `app/` tree. Release `v0.8.2-beta.82` at `d1f95cd2f2757e5f08971e403a43f1126756360a` also contains a substantially more capable Flutter implementation. Main is not a reconstruction of either shipped APK.

**Do not replace a shipped Flutter APK with the Compose scaffold.** Cutover requires a separate parity gate, valid application identity/signing, migration of existing user data and verified device acceptance. No release or cutover is authorized by this Stage 0 implementation.

## Compared implementations

| Area | Compose on main | Flutter on main | Flutter release reference |
|---|---|---|---|
| Build entry | Root Gradle `:app` | Separate Flutter pubspec | Flutter APK workflow |
| Surah index | Complete static 114-surah metadata | Dashboard scaffold | Real Quran repository |
| Reader | Repeated sample Al-Kahf text at every page | Same simulated page | Real 604-page assets / reader |
| Audio | StateFlow controller, no decoder/service | Riverpod state controller | just_audio / audio_service background engine |
| Downloads | Invented completed paths and sizes | Simulated progress | Real download/cache implementations |
| Account | Firebase Auth + Firestore adapters | Push service, Firebase options | Supabase/Firebase integrations |
| Search | Dialog; stations/reciters only | Separate screen | Real search implementation |
| Personal library | In-memory samples | In-memory samples | Persistent storage and playlists |
| Prayer / learning | Fixed times / sample records | Dedicated sample learning UI | Offline prayer alarms, curated content in beta 82 |

Compose-specific main features: Firebase email account UI and the Kotlin complete surah index. Flutter-main-only UI: settings/about/sources, full-player sheet, learning, notification service. Both main implementations duplicate home, reader, radio, reciters, favorites, downloads, playlists, brand/theme and simulated playback state. They are not integrated views of one runtime.

## Preserved reference and migration backlog

Keep `apps/mobile` unchanged, plus release tags/branches, for comparison and rollback. No parallel feature development on the main Flutter scaffold. Do not delete release code or merge unrelated release backend changes into a UI refactor.

Before Compose can replace released Flutter, migrate or expose the existing real audio engine/service, Quran assets and exact page/juz/hizb/ayah metadata, audio catalogs and rights gates, downloads/cache, offline playback, recording, persisted listening history, notification registration/background delivery, runtime configuration, user/account identity and data migration. These are **not implemented systems on main** and cannot honestly be claimed preserved through a Compose UI change.

## Baseline defects

Main has no `gradlew`, `gradlew.bat`, or wrapper JAR although CI invokes `./gradlew`. MainViewModel reads StateFlow objects as lists; calls nonexistent playback APIs; omits required PlaylistItem arguments; and initializes Firebase before checking configuration. Manifest has no INTERNET permission. UI opens seven bottom destinations, always shows a fake active mini player, repeats sample Quran text and fixed prayer times, and has no central navigation graph. Existing screenshots cover only Greeting.

Old `QuranHomeTab` is a dashboard + index + sample-content screen. Stage 0 removes its use as the production home; it is retained temporarily as reference until the dedicated shell is verified. The Kotlin/Flutter sample reader text must never be treated as canonical Quran content.
