# Tarteel Android release acceptance

This release phase produces installable Android APK artifacts only. It does not
publish to Google Play and does not use Play App Signing.

## Automated release gates

- Flutter dependency resolution
- Dart format check (read-only)
- `flutter analyze`
- unit and widget tests
- dedicated Mushaf model, persistence, and Tajweed integrity tests
- live Tarteel Quran API acceptance
- unified Quran audio repository/provider and download-contract tests
- live AlQuran Cloud surah/ayah and MP3Quran audio-byte probes
- universal release APK build
- ARM64 release APK build
- APK manifest inspection with Android `aapt`
- native library inspection from the APK ZIP contents
- SHA-256, byte size, version, SDK, and ABI evidence

The release job fails unless `minSdk` is exactly 26 and both APKs contain
`lib/arm64-v8a/` native libraries. The ARM64 APK also fails if it contains a
different native ABI.

## Device acceptance checklist

The following checks require an Android 8.0+ device or emulator and must not be
reported as completed merely because the APK built:

- install the release APK
- launch the application
- open the Mushaf
- load an SVG Mushaf page
- load a Tajweed WebP page
- zoom and swipe between pages
- download an offline pack
- open the Mushaf without network access
- play a surah with a selected reciter
- play one ayah when the selected edition supports ayah audio
- switch reciter, riwayah/moshaf, and an available bitrate
- download a surah, pause/resume it, and play the verified local file offline
- delete the downloaded surah and retry a failed download
- continue audio playback in the background
- switch between normal and Tajweed Mushaf modes
- restore the last page after restarting the app

GitHub-hosted Ubuntu runners do not provide a physical Android 8 device. The
workflow therefore records physical-device acceptance as **NOT RUN** and never
claims otherwise. A tester must record the device model, Android version, APK
SHA-256, and result for every item above when a suitable device is available.
