# Mobile canonical — verified release

The Android app supplied by the owner is **Flutter**, under `apps/mobile/`.
Its published baseline is tag `v0.7.2-beta.72`, commit
`402b6f8b680878871cd7924725893f6cd06bfca7`.

The uploaded APK exactly matches the release arm64 artifact:
SHA-256 `056983462aeaef3dc01c996c3ced47c70b4dd19ee9eded5c93284edfdc111617`.
Package: `app.tarteel.tarteel`; version: `0.7.2`; build: `2072`;
minSdk: 26; targetSdk: 36. The About screen's `0.3.0 (3)` is stale UI text.

## Architectural decision

Keep this working Flutter application canonical. The owner's identification of
the working APK takes precedence over the conditional proposal to use Compose
if root Gradle builds the current released app. Do not migrate the real player,
downloads, Quran providers, notifications, Firebase or storage to the scaffold.

`main` (`73b6efac0018786ef1709105e9c81f58c9aa91c2`) has unrelated Git history.
Its root `settings.gradle.kts` includes `:app`, a Compose scaffold. Its apparent
Flutter application is also a scaffold. Those trees are not the released APK.
Compose uses placeholder Quran/audio/download state; the verified Flutter tree
contains the real just_audio/audio_service playback, Quran page assets, offline
downloads, Quran playlists, prayer calculations, Firebase push and feature flags.
Do not remove either historical tree during Stage 0. No feature migration into
Compose is authorized or necessary for this release.

## Building the actual APK

Use Flutter 3.47.2, run `flutter pub get` in `apps/mobile`, then the existing
Android build workflow. Root Gradle builds the scaffold, not this release.
A UI debug build is `flutter build apk --debug`; release signing and publishing
remain governed by the existing workflow. This stage preserves minSdk/targetSdk.

## Git isolation

The audit-only branch `stage-0-ui-navigation-consolidation` belongs to `main`.
Implementation uses `stage-0-tarteel-ui-navigation` from the verified release to
avoid a destructive unrelated-history merge. Any PR must target the verified
release lineage, not silently replace `main` and its backend trees.
