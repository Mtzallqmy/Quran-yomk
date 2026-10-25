# Optional Tarteel library backup

This isolated API stores **only** explicitly submitted favorite station, reciter
and track identifiers. It does not calculate prayer times, schedule alarms, read
location, move existing Supabase/Firebase records, or upload audio. The Flutter
Settings screen has no background/startup network work; requests start only after
the user chooses consent or a backup/restore action.

## Deployed resources

- Neon project: `tarteel` / `calm-sky-72162812`, `aws-eu-central-1`, PostgreSQL 17.
- Production branch: `br-wispy-paper-bahpwe0x`.
- Development branch: `br-still-wildflower-baulgbyz`.
- Production API: `https://br-wispy-paper-bahpwe0x-tarteelcloud.compute.c-8.eu-central-1.aws.neon.tech/`.
- Flutter build definition: `TARTEEL_CLOUD_BASE_URL` = the API URL above. This is
  public configuration, **not a credential**.
- Server credential: `TARTEEL_DATABASE_URL` in the Neon Function deployment
  environment only. The account's automatic `DATABASE_URL` omitted the password;
  the explicit server-only override was required and tested. Never put either
  connection string in Flutter, APKs, Actions logs, or committed files.

The account accepted 0.25 CU min/max but rejected a custom suspend interval. The
project reports the account default `suspend_timeout_seconds=0`; no claim is made
that automatic suspension is active.

## Identity and permissions

This feature uses a separate per-installation capability, not a user account.
`POST /v1/devices` with `{"consent":"favorites-backup-v1"}` returns a random
256-bit bearer credential once. Its SHA-256 hash is stored server-side; Flutter
stores the credential in `flutter_secure_storage`. It is never compiled into the
APK. Existing push registration credentials and providers are unchanged.

Authenticated endpoints are `GET/PUT /v1/library-backup` and `DELETE /v1/device`.
There is no caller-supplied user/device id for backup access. Parameterized queries
resolve the principal from the token hash. Every backup transaction switches to
`tarteel_cloud_client` (NOLOGIN, NOBYPASSRLS), sets a transaction-local principal,
and enforces RLS ownership. The credential table is inaccessible to that role.
Anonymous/forged/revoked tokens cannot read or write backups.

PUT requires an expected `revision` (0 for the first save). Conflicts return 409;
the client does not retry by overwriting a concurrent revision. Restore validates
all rows before merging into existing local favorites. It never clears them.
DELETE removes the backup, then revokes the credential. There is no account-based
recovery or cross-device restoration: uninstalling the app may lose its device
key. The screen states this limitation before consent.

Payloads are bounded (64 KiB HTTP body, 60 KiB JSON, 500 identifiers/category,
200 characters/id). Unknown payload fields, including prayer/location fields,
are rejected. Postgres-backed quotas span all function isolates: 20 registration
attempts/minute globally, 60 authenticated operations/minute per credential.
These admission limits do not provide edge DDoS protection; the public native
Function URL still receives rejected invocations.

## Build, tests and redeploy

```sh
npm ci --ignore-scripts
npm test
npm run build
# Root archive must contain dist/index.mjs renamed to index.mjs:
zip -j function.zip dist/index.mjs
# With authenticated Neon CLI; server-only env must already be configured:
neon functions deploy tarteelcloud --src dist --no-bundle \
  --project-id calm-sky-72162812 --branch br-wispy-paper-bahpwe0x
```

Apply `migrations/001_optional_library_backup.sql` through a direct administrative
connection first on a development Neon branch. The migration is transactional
and repeatable; no existing app tables/sources are changed. The API uses a pooled
connection and a maximum of five clients per isolate.

```sh
TARTEEL_CLOUD_BASE_URL=https://br-still-wildflower-baulgbyz-tarteelcloud.compute.c-8.eu-central-1.aws.neon.tech/ \
  node test/live-acceptance.mjs
```

The live acceptance script creates two disposable credential identities, checks
CRUD/isolation/conflict/rejection, and removes its backups/revokes its credentials.
It prints no credentials or response payloads. Unit tests run without Neon.
