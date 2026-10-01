# Stage 0 migration report — verified Tarteel release

## Baseline and preserved systems

The owner's APK is byte-identical to `v0.7.2-beta.72` at `402b6f8`.
The actual app already had real playback, Quran page/text reading, bookmarks,
provider catalog/details, radio/virtual radio, recording, offline downloads,
favorites, playlists, history, learning, prayer/adhan and Firebase push.
These implementations and their data sources, licenses, backend, flags and
storage keys are preserved. minSdk 26 and targetSdk 36 remain unchanged.
Flutter is canonical; no migration to the unrelated Compose scaffold occurs.

## UI changes

- Stable Home/Quran/Listen/Radio/Library destination IDs replace changing index
  semantics; hidden radio cannot reinterpret another destination.
- Dedicated lazy Quran index and full screen reader routes replace embedding
  the reader as a root tab. Tab state/scroll survives returning from details.
- Dashboard reads actual position/session/settings; fixed city and stale About
  version are removed. Missing data remains empty/unavailable.
- Personal library groups existing functionality; history gains exact resume.
- Reader controls adapt to small screens/font scaling, page jump uses a sheet,
  existing ayah interactions/assets/audio remain intact.
- Search is lazy, Arabic normalized, filterable and resilient to partial
  directory failures and stale requests; result taps open the actual content.
- Radio whole-card tap no longer starts playback accidentally.
- Catalog favorites use the existing FavoritesStore alongside legacy IDs.
- Material 3 indigo/teal/copper theme and licensed Arabic UI typography unify
  light/dark UI. Quran fonts/text/providers are not replaced.
- Full player adds Quran repeat/favorite/download actions through the existing
  services; positions and duration remain actual streams. No second engine.
- Disposal of feature/prayer listeners and constrained empty layouts fixed.

## Changed files and commits

Run `git diff --name-only 402b6f8..HEAD` for the complete version-controlled list.
Production changes are limited to `apps/mobile/lib`, UI font assets/pubspec,
font attribution, these docs and a debug-only validation workflow. New tests
are ui_fixture/ui_navigation/ui_player/ui_screenshot and golden PNGs; the
existing theme test now checks the new distinct semantic accents.

Local checkpoints (remote connector commits may have different SHAs):
897994f audit; 74b9d22 navigation; 526796a dashboard; 593cb91 theme/player shell;
c38bab9 search/radio tap; 21182b8 complete flows; 4818536 Arabic typography and
catalog favorites; 5c9ffdb full-player actions. Final validation evidence and
remote commit links are recorded in the PR and accompanying report.

## Classification of former UI values

REAL: existing provider Quran passages/assets, prayer calculation/settings,
playback position/duration, stored session/history, download state and identity.
FALLBACK: original settings defaults when the user has not configured a city;
these are read from settings, never duplicated as a fixed UI city.
MOCK: the unrelated Compose/main scaffold is isolated and not part of this APK.
The verified release's stale `0.3.0 (3)` About label was removed. Test-only
fixtures are not imported by lib/ or production startup.

## Remaining acceptance limits

Do not mark Stage 0 complete solely because widget tests pass. Real-device
Android API 26 and modern Android, TalkBack, native edge-to-edge behavior,
notification permissions, downloaded Quran pages and background live audio
need device verification. Local Gradle artifact access is restricted; GitHub
Actions is the build/lint fallback. No release, merge, provider/backend/schema
change or new religious-content feature is part of this UI stage.

The current Surah contract lacks revelation type/start page/start juz for list
rows; navigation resolves correct pages from existing passages without invented
metadata. The listening edition browser, radio on-air/list/filter UI, settings groups,
large-font navigation and reduced-motion reader buttons were completed in the
follow-up. Some unrelated preserved feature screens retain their previous
layouts. The existing download engine does not support a Wi-Fi-only setting,
so the UI does not present a nonfunctional switch.

## Follow-up validation

Additional regression tests cover explicit radio actions and real metadata,
active-radio pause using the existing engine, canonical/legacy favorite
consistency, distinct edition navigation and large-font settings/downloads.
Active-player and active-radio screenshot fixtures supplement the offline/idle
coverage. The CI workflow now embeds source SHA and starts the actual debug
APK on API 26/35 emulators; see the PR for final run results and artifact links.

The UI update advances the application to 0.7.3+73. Search scope is now persisted
in the existing SettingsStore with stable IDs and a disabled-radio fallback.

## Signing / in-place update limitation

The supplied baseline APK uses an Android Debug certificate, SHA256
fe12985a559ebffd9719fc9c5f487600a54d58e1ab9f63228225a063d9e7c709.
The existing Android release configuration uses each runner's debug signing
key; no original keystore is version-controlled. A newly generated runner
certificate does not permit an in-place update over that APK. Preserving
installed user data requires the original private signing key, supplied through
secure CI secrets, not a new key or an uninstall. This stage does not alter
Android signing or claim that an unrelated certificate is upgrade-compatible.
