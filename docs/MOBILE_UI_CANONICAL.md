# Mobile UI audit — corrected after the working APK reference

Audit date: 2026-09-30. Requested repository: Mtzallqmy/Quran-yomk.
Main baseline: 73b6efac0018786ef1709105e9c81f58c9aa91c2.

## Confirmed working application

The user supplied the About screen of the application they want developed.
It shows Tarteel / ترتيل and Android package app.tarteel.tarteel.
This matches the real Flutter application's Android namespace and applicationId in apps/mobile/android/app/build.gradle.kts on release history.
It does not match root Compose app.quranyutla.

The displayed "0.3.0 (3)" is NOT reliable build identification:
apps/mobile/lib/src/screens/about.dart hardcodes l10n.versionLabel('0.3.0 (3)').
The exact same string remains in v0.7.2-beta.72 and release/islamic-suite-72 (beta 82).
Do not select a baseline solely from this screenshot. Read the APK manifest's versionName/versionCode, signing certificate and assets before matching it to repository commits.

## Canonical decision

The user's latest instruction selects the working application, not the main-branch Compose scaffold.
Preserve Flutter as the current canonical runtime for this Stage 0 until the working APK is matched.
Do not replace it with Compose, create another application, change package/signing identity, or remove its real engines.
Any future technology cutover needs a documented parity gate and separate authorization.

Compose changes explored locally before this clarification are isolated on stage-0-compose-isolated-experiment and are NOT uploaded as this stage's implementation.
This remote branch contains audit documentation only. Stage 0 is not complete and no APK has been built or published.

## Build and release evidence

- Root settings.gradle.kts on main includes only :app; Compose minSdk 26, targetSdk 36.
- Root main Android release workflow calls ./gradlew assembleRelease, but main lacks wrapper scripts/JAR.
- Actual published Flutter release v0.7.2-beta.72 targets 402b6f8b680878871cd7924725893f6cd06bfca7.
- Its .github/workflows/android-release-apk.yml builds apps/mobile with flutter build apk.
- Real Flutter source contains TarteelAudioHandler extending BaseAudioHandler and a just_audio AudioPlayer, real download/cache modules and mushaf page storage.
- Main's Compose and Flutter core/features scaffolds instead contain sample stations, simulated downloads and sample Quran text.
- main and the published release history have no merge-base. Comparing main to v0.7.2-beta.72 changes 664 files. Blindly merging or copying this branch would mix unrelated backend and application histories.

## Comparison

| Capability | Compose on main | Flutter on main | Working-release Flutter history |
|---|---|---|---|
| App ID | app.quranyutla | Separate scaffold | app.tarteel.tarteel |
| Quran reader | Repeated sample text | Simulated sample page | Actual page assets and storage |
| Audio | StateFlow only | Riverpod state only | just_audio / audio_service |
| Downloads | Fake paths/progress | Simulated progress | Real download and cache modules |
| Accounts | Firebase Auth/Firestore | Firebase push service | Release-specific Firebase/Supabase wiring |
| Surah index | Complete Kotlin metadata | Dashboard | Actual Quran repository |
| Search/settings/player | Partial/scaffold | Separate sample screens | Actual release screens |

## Next prerequisite

Obtain the APK that is currently installed (or its original download link).
Inspect it without changing it. Match applicationId, manifest version, signature and packaged Flutter assets to a commit.
Then create Stage 0 changes on that actual lineage, keep backend/providers/content unchanged, retain the existing audio/download/storage systems, and decide the safe review base before opening an implementation PR.

No Compose, Flutter or Roborazzi verification is claimed successful. An attempted Compose Gradle build failed resolving the foojay settings plugin in this environment. This is not validation of the user's working Flutter application.
