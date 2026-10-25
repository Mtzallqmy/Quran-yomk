# External Quran Radio Providers

## Listener data path

Third-party catalogs are normalized server-side. Flutter never consumes a
provider-specific JSON schema:

```text
provider catalog -> privileged Tarteel sync -> PostgreSQL canonical stations
                -> Tarteel Edge API -> Flutter metadata
Flutter -> direct external HTTPS stream
```

The upstream provider is therefore replaceable without rebuilding the Radio UI.
Favorites continue to store stable Tarteel station UUIDs.

## Islamic Radio API

- Repository: `https://github.com/uthumany/islamic-radio-api`
- Upstream inventory: `client/public/api/stations.json`
- Tarteel provider slug: `islamic-radio-api`
- Integration basis: `PUBLIC_API`
- Synchronization: `app.sync_islamic_radio_api_stations()` in the trusted Supabase runtime
- Cadence: daily Supabase Cron plus authorized manual Admin sync
- Listener access: normalized Tarteel catalog only

The upstream README states that its API/catalog is provided under CC0-1.0. In
Tarteel this is recorded as the catalog-metadata license. It is deliberately not
interpreted as ownership of, or CC0 licensing for, every radio broadcast listed
inside that catalog.

### Synchronization rules

Each row is validated independently. Missing optional values do not fail the
whole run. Rows without an ID, display name, or HTTP(S) stream URL are counted as
invalid/skipped.

Deduplication order:

1. existing `(provider, external ID)` mapping;
2. canonicalized stream URL against existing external stations;
3. create a new Tarteel station only when neither identity exists.

`provider_station_records` preserves provenance and raw provider metadata, so a
single canonical Tarteel station can be referenced by several providers.
Removed upstream records are marked missing conservatively; stations are not
blindly deleted.

### Category normalization

Provider genres/names are mapped into the accepted Tarteel categories only:
`QURAN_GENERAL`, `RECITER`, `TAFSEER`, `HADITH`, `SEERAH`, `SAHABAH`, `ADHKAR`,
`RUQYAH`, `FATWA`, `QURAN_TRANSLATION`, `QURAN_SURAH`, `LIVE_TV_AUDIO`, `OTHER`.
Original genres remain in provider metadata.

### Stream types and health

The synchronizer uses upstream metadata/URL evidence for initial stream type and
does not convert `unknown` to MP3 without evidence. Release acceptance performs
bounded `curl`/`ffprobe` probing outside listener devices. Existing centralized
health fields remain authoritative for runtime catalog/Virtual Radio selection.

Plain HTTP streams remain catalog evidence but are not playable in the Android
release because global cleartext traffic is disabled.

## Existing providers preserved

Phase 11 does not replace the previously accepted Qurango, MP3Quran, Holol or
Radiojar records. When Islamic Radio API lists the same underlying stream, its
provider record is attached to the existing canonical Tarteel station rather
than creating a second listener card.

## Operational evidence

Every sync writes a `provider_sync_runs` record including timestamps and counts.
The Admin Phase 11 view exposes the provider, latest run, normalized record
count, HTTP-only count, missing count and a privileged **Sync Now** action.
