# Offline repairs — Tarteel 0.7.4 / ARM64 versionCode 2074

Baseline: `stage-0-tarteel-ui-navigation` at `7d0db1100dbf3ecf8663120c29b586a486e6cd62`, matching user screenshot 0.7.3 (2073). Preserve application ID `app.tarteel.tarteel`, existing storage keys, current Flutter playback and catalogs. `main` is an incomplete Compose implementation and is not a release baseline.

## Changes

- Download real audio using bounded HTTPS redirects. Resume with Range/If-Range, check returned offset, restart when server ignores Range. Keep partial files after connection interruption. Validate size, MP3 signature and SHA-256 before atomic finalization.
- Search verified saved files before provider calls; restore downloaded media and listening progress without needing a catalog or CDN probe. Failed HEAD/no Content-Length no longer blocks a valid download.
- Live byte counts/progress, completed/offline labels, whole available audio-edition download, and controls for pause/resume/delete. Keep the existing provider and reciter identities.
- Native visible foreground transfers for Quran audio, Mushaf pages and permitted station recording. Interrupted process transfers remain paused and resumable at next launch; these are not a second download manager.
- Native offline AlarmManager schedules use the selected private file and a separate bounded prayer/personal-alarm audio service. Exact permission is requested when enabling audible alarms. Boot/time changes restore schedules without launching playback at boot. Prayer calculations remain offline; the existing 45-day prayer scheduling horizon refreshes when the app runs.
- Import and validate a phone audio file into private app storage, select bundled adhan or saved phone audio, and add daily personal alarms using independent times and files.
- Record personal recitation with user-granted microphone permission and a microphone foreground service. Save AAC/M4A with duration and size, play it through the existing player. Permitted station capture uses temporary files and visible recording status.
- Existing content attribution, feature gates and station recording policy remain enforced. Personal files are user-selected; nothing is uploaded.

## Validation

Workflow `.github/workflows/offline-repair-release.yml` formats/analyzes/tests source, requires a clean tree, builds release ARM64 plus native tests, verifies minSdk 26/versionCode 2074/signature/ABI, then runs API 26 and 35 emulator tests before publication. Any formatting/visual updates must be committed before a release can build.

No physical-device audio or manufacturer battery-policy acceptance can be claimed from emulator results. Test final APK on the user's device: download/restart/airplane-mode playback, recorded playback, selected adhan with screen off, personal alarm after reboot.

The old baseline used a runner-generated debug signing key with no committed or configured persistent signing key. Compatibility with installed 2073 signature is unverified. New internal-beta signing is cached for subsequent upgrades; production/store signing is a separate requirement. Do not uninstall the old app without preserving desired files. No existing user files or keys are deleted by these changes.
