# Tarteel 0.9.0-beta.2 — radio and offline audio upgrade

Application remains Flutter `apps/mobile`, package `app.tarteel.tarteel`, minSdk26.
Version `0.9.0-beta.2+91`; expected ARM64 split code2091 is checked in the APK.

## Functional changes

- Four packaged offline recordings: Makkah (197s), Madinah (187s), Shalqar in
  Kazakhstan (155s), and Fajr at Malmö Mosque, Sweden (248s). No Internet download
  is needed. Existing sample, chime and imported paths remain supported.
- Native Media3 asset allowlist accepts the new recordings. Per-prayer audio
  selection and preview reuse existing playback and scheduling engines.
- Imported sounds can be renamed without moving files or breaking prayer paths.
- A one-minute screen-off test uses the selected audio, with visible last native
  preparation time. Preparation does not certify audibility on a physical device.
- Offline About/Sources cards retain authors, sources, license URLs and conversion
  notices. Adapted Kazakhstan audio remains CC BY-SA4.0; others CC BY3.0.
  Field recordings may contain ambience. No unknown muezzin identity is invented.
- Original, locally drawn Islamic artwork/backdrops for radios and the player.
  Existing station pictures remain preferred. Nine visual references updated and
  inspected; reduced-motion behavior and playback controls remain unchanged.
- Local JSON export/import for favorites, appearance and prayer calculation
  settings. Favorites merge; credentials, audio paths, downloads/history/playlists
  are excluded. Restoring settings requires opt-in; restored prayer alarms are
  disabled until explicitly enabled. The file includes the saved prayer location.

## Non-duplicate radio catalog

Compared all223 existing stations (two pages) against177 MP3Quran provider rows.
URL mirrors, Arabic spelling and provider identifiers are checked. Two new
candidates were found:

- Shama'il Muhammadiyah, provider109083: four seconds of MP3 audio actually
  fetched, transcoded and probed successfully. Added with stable UUID
  `0cbaeaa3-dfee-5bc0-b05d-669585d1f60c`.
- Noreen Muhammad Siddiq, provider109084: endpoint returned404. Not added.

Neon stores supplemental metadata only; streams play from their original source.
Existing station IDs win when a supplemental duplicate is encountered, preserving
existing favorites/history. Separate cache and three-second timeout keep Neon
failure from discarding the existing/stale catalog. No old DB/source is moved.

Project `tarteel` (`calm-sky-72162812`), isolated test branch
`br-damp-fog-ba9v2abb`, production `br-wispy-paper-bahpwe0x`.
Public GET:
https://br-wispy-paper-bahpwe0x-tarteelcloud.compute.c-8.eu-central-1.aws.neon.tech/v1/radio/stations

The new table has unique source identifiers/stream keys and no public/client
write grants. GET only; POST/PUT/DELETE return405. Catalog reads coalesce/cache
for60seconds per isolate. This is not edge DDoS protection. No app secret is
required for deliberately public metadata. Backup authorization remains unchanged.

## Verification

- Cloud API unit suite:7 passed. New migration rerun successfully on the test
  branch. Public read/private mutation grants verified through PostgreSQL.
- Deployed test and production HTTPS checks passed: catalog GET, denied public
  writes, consent, backup CRUD/update, principal isolation, revision conflict,
  invalid tokens and revocation. Test backups deleted and credentials revoked.
- Local Flutter suite:179 tests passed. Analyze: no errors/warnings;10 existing
  informational lints. Nine visual changes inspected; full regression suite passed.
  Native asset decoding and actual screen-off Madinah playback tests are added
  to the existing API26/API36 CI matrix. Their execution must pass before any
  claim about native acceptance for this candidate.
- `scripts/tarteel/verify_audio_assets.py` checks six packaged assets and provenance;
  APK inspection additionally requires the four new recordings.

## Signing continuity

The beta.1 test APK's temporary key is unavailable. It cannot receive an update
signed with a replacement key. The original2074 key is also unavailable here.
Neither compatibility is claimed. Do not uninstall an existing app to test.

A permanent **preview-only**3072-bitRSA identity has been generated and backed up
privately with its credentials, outside git. Its certificate SHA256 is:
`5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8`.
Future preview APKs must reuse that key and raise the actual split version code.
Production verification continues to require the original2074 certificate; no
new certificate is substituted into the production release gate.

## User-supplied recordings (2026-10-24)

The owner supplied `adhan_recordings.zip` and explicitly authorized inclusion.
Five distinct original MP3 files are bundled unchanged: Makkah201s,
Madinah96s, Egypt183s, AbdulBasit206s, Minshawi235s. Names and PrayTimes source
links follow the provided README. No third-party Creative Commons license or
independently verified muezzin/location is asserted for this supplied collection.
All five are selectable, previewable and accepted by native alarm playback.
Existing prayer selections and paths remain unchanged. Android instrumentation
adds five-file readability plus actual screen-off playback of the supplied MP3.
The packaged manifest now covers11 sounds; APK inspection requires all of them.
