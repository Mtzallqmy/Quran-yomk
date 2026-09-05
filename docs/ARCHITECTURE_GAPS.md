# Tarteel — Architecture Gaps

Updated 2026-09-05 after PRs #29–#42. This is the current repository status;
merged code is not proof that a running environment has been upgraded.
Historical phase reports retain their original scope and evidence.

## Closed implementation gaps

| Gap | Resolution | Evidence |
|---|---|---|
| GAP-DB-001 | Empty database applies all migrations and seed; RBAC, catalogs, RPC grants and atomic mutations validated; two rebuilds have identical schema. | #29, #36–#38; DB CI run 33998661750 passed, including 40 baseline assertions and concurrency tests on each rebuild. |
| GAP-UPSTREAM-001 | Bounded deadlines/body sizes, disabled redirects, status/JSON validation and private failures across Edge, Elysia, Admin and worker backends; stream probes use fixed HTTPS host allowlists. SQL provider ingestion accepts validated server payloads instead of unbounded HTTP calls. | #30–#36; Edge CI 33998661749 and service/Admin CI 33998661759 passed. |
| GAP-ADMIN-001 | Common mutation authentication, endpoint permissions, exact Origin, durable start/result audit, production Secure cookies, bounded request bodies; runtime config updates are atomic and permission checked. | #37; auth outage/privacy regressions in #40. MFA rollout remains an operational policy decision. |
| GAP-SEC-001 | Forward migration removes legacy client writes and authenticated access to privileged permission lookup; default function grants tightened. | #37; anonymous/authenticated denial and server paths covered by the DB baseline. Needed public read-only catalog RPCs remain callable. |
| GAP-RATE-001 | Every Admin limiter uses persistent PostgreSQL state; hashed identities, account/IP dimensions, fail-closed outages and lock-safe expiry cleanup. | #38; 32 independent connections admit exactly 5 requests, fresh connections remain limited, expiry resets, concurrent renewal survives cleanup. |
| GAP-CI-001 | Android formatting is check-only; deterministic tests and actual release builds are separate from live provider acceptance. | Existing Android hardening retained; #41 CI 33998990465 passed tests, Universal/ARM64 release builds and APK checks. |
| GAP-CI-002 (permissions) | Android defaults to read-only; release publication has job-scoped write permission. | Current Android workflow. Full action SHA pinning/SBOM coverage remains deferred maintenance. |
| GAP-OBS-001 (critical paths) | Request IDs, bounded dependency readiness, structured private errors; radio readiness requires distribution readiness and a live lease. Basic failure counters exist in Elysia/radio. | #39–#40; false-health, silent-200 and private-error regressions passed. |
| GAP-STARTUP-001 | Only audio setup and saved preferences precede runApp. Content/download/config work starts after first frame; offline operations share initialization. Mushaf page storage is lazy. | #41; startup, widget, playback/offline regressions and Android builds passed. |
| GAP-ADMIN-002 (review boundary) | Public reads extracted unchanged from api.ts; mutation guard/auth/HTTP/rate limits are separate modules. | #42; Admin CI 33999382817 passed. |
| GAP-DOCS-001 / GAP-DX-001 | Current status, evidence and root commands are documented. | This update; README and ENGINEERING_REVIEW.md. |

## Existing foundations retained

- GAP-QURAN-001: canonical v1 checksum/approval and runtime revision checks are
  implemented. See [Quran integrity](QURAN_INTEGRITY.md); canonical CI
  33994240490 passed. No Quran text was changed during this hardening.
- GAP-RECITER-001: the explicit-reciter contract and offline identity checks are
  implemented. See [identity contract](RECITER_IDENTITY.md); current Android
  and Elysia tests cover the retained behavior.
- GAP-RADIO-001: deterministic command/scheduler/ACK tests pass. Fresh real
  broadcast/soak acceptance is **waived by the owner**, not reported as passed.

## Open release verification

| ID | Priority | Remaining requirement |
|---|---|---|
| RELEASE-DEPLOY-001 | P1 security/operations | Reconcile the connected Supabase migration history and deploy the merged forward security/ingestion/rate changes with their callers. Live inspection on 2026-09-05 found older grants and function versions. Repository CI alone does not close this. |
| RELEASE-PROVIDER-001 | P1 availability | Deploy provider-sync and configure its Vault endpoint as documented in [the deployment runbook](PROVIDER_SYNC_DEPLOYMENT.md); verify the dispatch result. No token may enter a client or log. |
| RELEASE-HEALTH-001 | P1 operations | Deploy the new readiness handlers; the inspected deployed Edge health v5 still returned 200 on dependency failure. |
| RELEASE-RUNTIME-001 | Verification waived | Broadcast/soak acceptance is excluded from this release by explicit owner instruction. Deterministic radio tests remain required. |
| RELEASE-OPS-001 | Operational readiness | Verify deployed secret placement, backup restoration, environment classification and service configuration. No full production-readiness claim is made without this evidence. |

## Deferred work (not current P0/P1 defects)

GAP-API-001/002/003: further API/provider orchestration consolidation requires
caller evidence; preserve existing endpoints, reciter IDs and data-atomic RPCs.
GAP-MOBILE-001/ADMIN-002: broader screen/domain extraction is deferred without a
concrete maintenance or testing blocker. GAP-OBS-001: fleet-wide metrics/SLOs,
HA and retention need operational targets. GAP-PERF-001: optimize only against
measured problems. CODEOWNERS is not introduced without an established owner map.

No deployed migration is deleted or squashed as cleanup. Live databases must
never be reset to reproduce the isolated CI gate.
