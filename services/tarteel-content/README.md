# Optional Tarteel content catalog

Project `tarteel-content` (`proud-mountain-00920668`), database `tarteel_db`.
Production branch `br-curly-salad-bajy1evn`; isolated validation branch `br-long-lab-baz0k116`.

Read API: `https://br-curly-salad-bajy1evn-tarteelcontent.compute.c-8.eu-central-1.aws.neon.tech/v1/catalog`.
`GET /v1/translations/:key/:surah` checks the current provider version and retains publisher, translator description, version, source, footnotes and terms. Quran text in the existing application is never replaced. The public API sets a read-only database role and exposes only approved supplements. No public write route exists.

`POST /admin/sync` requires a server-only `SYNC_TOKEN` in the Authorization bearer header. It performs idempotent transactions, a database advisory lock, canonical provider mappings, source isolation, retry/backoff, rights checks and restricted stream health checks. Failed upstreams do not delete existing rows. The client does not receive this token or database credentials. Connection certificates are verified by `pg` (`rejectUnauthorized: true`). `TARTEEL_DATABASE_URL` points to tarteel_db; the injected default URL may otherwise select a different database.

Apply database/neon/001_tarteel_additive_catalog.sql then002_content_sync.sql with a direct migration connection, first on an isolated branch. These migrations are additive and repeatable. Admin credentials are deployed only through Neon Function environment variables. GitHub Secrets writes are not exposed by the connected GitHub tools; no credentials are checked into git to work around that limitation.

`npm ci && npm test && npm run build`; deploy the bundled dist/index.mjs as index.mjs in a ZIP. Dist and node_modules are ignored. Provider policies are in src/registry.mjs. Quran Foundation needs developer credentials/Content Sync permission; Archive, Islamic Radio API and asset sources need per-item rights. Disabled sources are intentionally not imported.

The dated baseline contains the public server catalog (223 stations and289 reciter editions), not personal phone data. It prevents treating pre-existing dynamic MP3Quran content as new. A new MP3Quran edition is checked against provider IDs and its preview URL; names alone never authorize merging. Radio URL alias collisions between existing mapped entities are rejected rather than silently merging their data. Different recording identities include narration, edition and source URL fingerprint.

Verified first/second sync results are in docs/tarteel-content-beta3. Both validation and production added76 translation metadata editions, then zero on repeat. MP3Quran709 records were discovered:708 already represented by the app, one unhealthy radio rejected, zero new radio/reciter editions. The previous Shama'il supplement remains served by the existing cloud API. Its data and authenticated backups were not moved.
