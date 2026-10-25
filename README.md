# ترتيل (Tarteel)

Quran radio and audio monorepo: Flutter mobile, Next.js Admin, Supabase
PostgreSQL/Edge Functions, optional Elysia API, audio worker and Liquidsoap radio
engine. Scheduler, offline downloads and Admin are implemented.

Status: critical repository hardening merged through PR #42. Deterministic
Android, database, Admin, Edge and service gates passed on the relevant changes.
Production deployment reconciliation remains open; broadcast/soak tests are
waived by the owner for this release, not reported as passed.

## Components

| Path | Responsibility |
|---|---|
| `apps/mobile` | Flutter playback, Quran, Mushaf, preferences and offline storage |
| `apps/admin` | Next.js Admin, server authentication/permissions/audit and public compatibility routes |
| `supabase` | Forward migrations, seeds, database tests and Edge APIs |
| `services/tarteel-api-elysia` | Optional bounded proxy to canonical public APIs |
| `services/audio-worker` | Leased audio processing jobs and private storage access |
| `services/radio-engine` | Scheduler/command coordination, fencing and Liquidsoap/Icecast playback |
| `data/quran/canonical` | Approved immutable Quran dataset and manifest |

## Commands from repository root

Use Node 24, Python 3, Flutter 3.47.2 and Java 17; Bun for Elysia. Database tests
require Docker and Supabase CLI 2.116.0. Worker tests also require FFmpeg/ffprobe.
Copy component environment examples and configure server credentials outside
version control. Never put service-role or provider secrets in clients.

```sh
# Admin
npm --prefix apps/admin ci
npm --prefix apps/admin run dev
npm --prefix apps/admin test
npm --prefix apps/admin run typecheck
npm --prefix apps/admin run build

# Deterministic Edge HTTP failure cases (no live providers)
node --test supabase/functions/_shared/*.test.mjs

# Audio worker and radio engine unit tests
npm --prefix services/audio-worker ci
npm --prefix services/audio-worker test
npm --prefix services/radio-engine ci
npm --prefix services/radio-engine test
# Start configured services:
npm --prefix services/audio-worker start
npm --prefix services/radio-engine start

# Optional Elysia API
(cd services/tarteel-api-elysia && bun install --frozen-lockfile && bun test)
(cd services/tarteel-api-elysia && bun run dev)

# Flutter
(cd apps/mobile && flutter pub get && flutter analyze --no-fatal-infos && flutter test)
(cd apps/mobile && flutter run)
(cd apps/mobile && flutter build apk --release)

# Canonical Quran checks: never refresh the approved dataset implicitly
node scripts/quran-integrity/validate.mjs --version 1
node --test scripts/quran-integrity/*.test.mjs

# Isolated LOCAL database only; reset destroys local test data
supabase start
supabase db reset --local
supabase test db supabase/tests/baseline.sql
python3 supabase/tests/rate_limit_concurrency.py
supabase stop --no-backup
```

The full two-rebuild gate (including legacy SQL assertions and schema drift)
is defined in `.github/workflows/supabase-empty-db.yml`. Android CI checks
formatting without mutation, runs deterministic tests and builds Universal and
ARM64 release APKs. Live provider checks use their separate workflow.

## Current references

- [Architecture gaps and closure evidence](docs/ARCHITECTURE_GAPS.md)
- [Engineering review and deployment limits](docs/ENGINEERING_REVIEW.md)
- [Current architecture](docs/CURRENT_ARCHITECTURE.md)
- [Provider sync deployment](docs/PROVIDER_SYNC_DEPLOYMENT.md)
- [Quran integrity](docs/QURAN_INTEGRITY.md)
- [Reciter identity](docs/RECITER_IDENTITY.md)
- [Android release acceptance](docs/ANDROID_RELEASE_ACCEPTANCE.md)

Phase reports under `docs/` retain historical evidence and their original scope;
they do not certify the currently deployed environment. Existing endpoints,
persisted identities and approved Quran text remain compatibility boundaries.
