# Tarteel Islamic Suite integration

## Scope

This release extends the existing Flutter applications instead of replacing them. The user app remains the owner of UI, Riverpod services, notification scheduling, audio playback, SQLite content cache, Quran downloads, Firebase push, and Supabase integration.

## Upstream review

### Adhan Kotlin

- Repository: https://github.com/batoulapps/adhan-kotlin
- License: MIT.
- Integrated as the Android prayer/Qibla calculation engine through the published Maven artifact `com.batoulapps.adhan:adhan2:0.0.7`.
- No vendored source fork is required.
- Android API 26+ is already the Tarteel minimum, and core-library desugaring remains enabled.
- Supported calculation methods exposed by Tarteel: Muslim World League, Egyptian, Karachi, Umm al-Qura, Dubai, Qatar, Kuwait, Moon Sighting Committee, Singapore, North America/ISNA, and Turkey.
- Per-prayer minute adjustments and Shafi/Hanafi Asr modes are preserved.

### Hidaya

- Repository: https://github.com/BassamAlim/Hidaya
- License: GPL-3.0.
- Hidaya is used as a product/architecture reference only. Its GPL source files and bundled media are **not copied** into Tarteel in this integration.
- Concepts adopted independently include feature separation, offline-first local data, reboot-safe scheduling, and explicit download/file management.
- This avoids silently relicensing Tarteel or importing media whose separate distribution rights were not verified.

## Offline-first architecture

### Prayer engine

Android uses Adhan Kotlin through a small platform channel. Flutter keeps a compatible Dart fallback for tests and non-Android targets. All calculations happen on-device. Saudi presets select Umm al-Qura automatically; Makkah has a first-class preset.

### Local reminders

Prayer, adhkar, salawat, daily wird, and daily Quran reminders are scheduled locally. They do not require an administrator, Firebase message, Supabase request, or internet connection after scheduling. `flutter_local_notifications` handles persisted alarms and its boot receiver restores scheduled notifications after reboot. Workmanager periodically reconciles/replenishes schedules as an additional recovery path.

Remote Firebase notifications remain a separate channel for optional administration announcements and content/system updates.

### Quran, tafsir, hadith and adhkar content

The existing `IslamicContentRepository` remains authoritative. It verifies pinned downloads, stores them on-device, and indexes verified assets in SQLite. Quran audio keeps using the existing resumable local download manager. The integration deliberately does not add Room/DataStore beside existing Flutter persistence because that would duplicate storage responsibilities and create two sources of truth.

### Qibla and Hijri calendar

Qibla uses the same Adhan engine and configured coordinates. The Hijri screen offers an offline arithmetic conversion with a small user adjustment and clearly warns that official/local moon sighting can differ.

## Audio rights

The existing bundled `adhan.ogg` remains the only built-in adhan recording because its CC0 provenance is documented in `THIRD_PARTY_NOTICES.md`. No Hidaya adhan/reciter files are copied. Additional named muezzin recordings must be added only after a per-file rights record is available (license/permission, source URL, attribution, checksum).

## Release target

- User app package: `app.tarteel.tarteel`
- Admin app package: `app.tarteel.admin`
- Minimum Android: 8.0 / API 26
- Release artifacts: ARM64 (`arm64-v8a`) APKs
- Current signing remains internal/debug signing until production Play signing is supplied.
