# Tarteel0.9.1-beta.1 (preview, actual ARM64 split code2092)

Target remains apps/mobile, app.tarteel.tarteel, Android8/API26+, ARM64. Root app/ is unchanged.

## Implemented

- Native alarm diagnostics now include the next future alarm, its chosen sound/silent mode, system alarm volume, DND state, manufacturer and a bounded24-event local history. It distinguishes reception, service start, file readiness, completion, stale delivery and errors. File readiness is not a guarantee that a speaker was audible. No location or imported private file path enters the history.
- Quran study selects any surah/ayah range from the existing repository/cache. It uses the existing repetition, gradual hiding, self-assessment and review engine. Stable range keys reopen custom review passages after restart. Searching normalizes diacritics/alef for matching only; the displayed Quran text remains unchanged. Bookmarks and page navigation use the existing stores.
- The current audio handler now advances its queue on completion, supports a study gap without depending on a reader widget being open, cancels pending progression on pause/source change/seek, and stops at the actual end of a surah. Local recordings can be appended after recitations using the same player and media session. Queue selection is visible in the full player. Repeat state follows the actual player, and choosing a new queue clears the old single-track loop.
- Device-only resume markers distinguish media/edition IDs, omit short/completed items, tolerate corrupt data and cap storage at80 items. Existing favorite, download, reading and settings keys are retained.
- The optional QuranEnc pane loads only on user expansion. It displays translator description, publisher, source/terms, version, unchanged translation text and footnotes. A source outage does not block Quran reading, prayer calculation, alarms or the primary radio/recitation catalogs.

## Isolated content backend

New project tarteel-content (`proud-mountain-00920668`), organization org-rough-bird-14728233, database tarteel_db. No existing project was deleted or migrated. Validation branch br-long-lab-baz0k116; main br-curly-salad-bajy1evn. The previous dedicated tarteel cloud backup/radio supplement service stays in place.

Tables in tarteel_catalog: providers, entities, provider_items, media_endpoints, sync_runs, identity_aliases, api_budgets; public_catalog is a read-only, rights-filtered view. Migrations001/002 are additive and replayed on validation before main. Sync transactions serialize canonical mapping/alias writes with a PostgreSQL advisory lock. Unique constraints/UPSERT also prevent concurrent duplicate insertion. Distinct recording identities include narration, edition and URL fingerprint; names alone do not merge entities. Conflicting existing provider/URL identities are quarantined. Translation versions retain separate provider mappings; previous versions remain stored but inactive.

Observed baseline:223 public stations and289 reciter editions. This is a server/shipped-provider inventory; the personal database on the user's phone is inaccessible and preserved unchanged. MP3Quran yielded709 records:708 matched existing app content, one unhealthy radio rejected. Zero additional radios/reciters/audio editions were claimed. QuranEnc added76 translation metadata editions; a second sync added0. First/second results for test and main are committed in docs/tarteel-content-beta3. No Quran text was replaced or GPL/image assets copied. Six other sources remain explicitly disabled pending credentials, per-item rights or verification.

Server connections verify TLS certificates. The public API assumes a read-only role, has no write routes and bounds translation proxy traffic. Admin sync requires a separate server-only bearer secret. Database credentials and that secret exist only in Neon Function environment variables, never in Flutter build defines or git. The GitHub connector exposes no Secrets write operation; that limitation was not worked around by committing credentials.

## Verification / release gates

Local checks:188 Flutter tests (including the real audio handler driven through simulated native events, mixed local/remote progression and cancellation),33 UI goldens, no analyze errors/warnings (ten existing information lints), seven existing cloud tests and nine content tests. All eleven audio checksums/provenance records pass. The canonical Quran checksum tests remain enabled.

Live checks: two syncs each on validation/main, public catalog read, a seven-verse translation read with version1.1.2, anonymous admin rejection, public write rejection, read-only role permissions and exclusion of an unapproved fixture. Two simultaneous DB transactions returned the same entity ID. Fixtures remained on validation only.

Android native compilation, lint, API26/API36 instrumentation and the final release APK are verified by the Actions run linked in PR64 when complete; do not infer those results from the local checks above. Physical-phone audible playback, manufacturer battery behavior and upgrade acceptance remain manual tests.

The preview must reuse the backed-up beta2 signing identity (SHA2565e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8). It can be a cryptographically compatible update to beta2/code2091. It cannot update original2074 or the old beta1 certificate. Original2074 verification remains in the production release pipeline; this preview does not bypass it or claim a production-compatible release.
