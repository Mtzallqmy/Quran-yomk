# Tarteel — Phase 1 Full Repository Audit

Audit base: `ea2be74220b59900104d92a3199eed9deb1570c2` (`feature/reciter-offline-ux-remote-updates`) plus the connected DEVELOPMENT Supabase project inspected on 2026-09-02.

Scope: inventory and risk classification only. No architecture or production behavior was changed in Phase 1.

## 1. Repository inventory

### Applications
- `apps/mobile` — Flutter listener, Mushaf, Quran audio/downloads, radio, offline content, runtime config.
- `apps/admin` — Next.js administration UI and server API routes.

### Long-running/server services
- `services/radio-engine` — scheduler, persistent queue, commands, fencing, Liquidsoap control, ACK/history/now-playing.
- `services/audio-worker` — FFmpeg/ffprobe audio-processing worker.
- `services/tarteel-api-elysia` — optional Bun/Elysia BFF/API, currently non-canonical.

### Backend/data
- `supabase/migrations` — append-only schema evolution.
- `supabase/functions/tarteel-api` — current mobile public Edge API.
- `supabase/functions/managed-radio` and `tarteel-managed-radio` — radio/control integrations.
- `supabase/tests` — database/security/integration validation.
- `packages/api-types` — TypeScript contracts for public/admin/storage/audio-processing APIs.

### Infrastructure
- `infrastructure/liquidsoap`
- `infrastructure/icecast`

### CI/release
- Android release APK workflow.
- Elysia validation workflow.
- Mushaf asset workflow.
- Phase 5B/6 real Icecast/radio workflows.
- bootstrap/integration workflow.
- beta publishing workflow.

## 2. Evidence-backed findings

### AUD-P0-001 — Quran text is live mutable upstream data
**Severity: P0 Critical**

Current behavior: `/quran/{surah|juz|page}` fetches `quran-uthmani` and `quran-tajweed` from AlQuran Cloud at request time and directly normalizes the returned text for the client.

Risk: the text seen by users can change when the upstream response changes, without an explicit Tarteel dataset version, pinned revision, approved checksum or review gate.

Required target: versioned canonical Quran dataset with source/revision/schema/checksum/verification metadata and fail-closed integrity tests. Live external Quran text must not silently replace approved production text.

Do not use AI/fuzzy matching to repair discrepancies.

### AUD-P0-002 — Radio Phase 6B combined-runtime proof is still open
**Severity: P0 High**

Current behavior: Phase 6 proved real Liquidsoap/Icecast streaming and protected Supabase writes, but in separate trusted executions.

Risk: the exact production coordinator sequence has not been demonstrated in one secret-backed runtime:

`occurrence claim -> queue -> command/effect -> Radio Engine -> Liquidsoap -> Icecast -> ACK -> history/now playing`.

Required target: a narrow Phase 6B acceptance run with explicit evidence and failure cases. No redesign is required.

### AUD-P0-003 — Reciter identity is enforced in Flutter but contracts are not canonical across layers
**Severity: P0 High**

Positive evidence: Flutter restricts an explicit reciter to its selected provider and rejects a resolved identity mismatch; regression tests cover silent substitution.

Gap: equivalent concepts have multiple serializations. Example MP3Quran identifiers differ between current Edge and mobile/Elysia representations. Provider normalization also exists independently in Flutter, Supabase Edge and Elysia.

Risk: cross-layer restore/cache/API migration can reintroduce the exact wrong-reciter class of defect even though local Flutter resolution is now strict.

Required target: one versioned reciter identity contract plus compatibility parsers/adapters; tests across download, recent playback, favorites, search, playlists and API boundaries.

### AUD-P0-004 — RLS historical warning is closed in current DEVELOPMENT state, but needs a permanent regression gate
**Severity: P0 verification / no open data exposure observed**

Current database evidence: `app.virtual_radio_channels`, `app.virtual_radio_schedule`, and `app.virtual_radio_candidates` now have RLS enabled. Authenticated policies call `app.managed_radio_authorized(auth.uid(), 'schedules.read|write')`. No anonymous write policy was observed.

Risk: security could regress through a future migration; SECURITY DEFINER functions remain a sensitive boundary.

Required target: retain RLS, add deterministic policy/grant tests and review SECURITY DEFINER search paths/execution grants during database hardening. Do not remove or weaken current policies.

### AUD-P1-001 — No canonical API direction is implemented yet
**Severity: P1 High**

Current behavior:
- Flutter production URL targets Supabase Edge `tarteel-api`.
- Elysia proxies some Edge endpoints but independently implements Quran resolver/provider logic.
- Next.js Admin has its own APIs.
- significant behavior exists in PostgreSQL RPCs.

Risk: contract drift and duplicated business rules.

Required target: ADR identifying Canonical Public API and Canonical Admin API while preserving existing clients with compatibility adapters.

### AUD-P1-002 — Quran/provider logic is duplicated
**Severity: P1 High**

Provider discovery/resolution/normalization exists in Flutter, Supabase Quran Edge code and Elysia.

Risk: different identities, fallback rules, validation and error behavior.

Required target: consolidate domain rules behind one contract without creating another backend. Keep client-side local/offline selection where it genuinely belongs.

### AUD-P1-003 — Admin rate limiting is process-local
**Severity: P1 High**

Current limiter uses a module-level `Map<string, Bucket>`. Runtime Config and Managed Radio mutations call it after server-side authorization and same-origin validation.

Risk: counters are lost on process restart and are not shared across horizontally scaled instances.

Required target: distributed/upstream enforcement chosen from existing infrastructure, with endpoint/user/IP dimensions and `Retry-After` where appropriate. Do not introduce Redis without an evidence-based need.

### AUD-P1-004 — Admin security is partly hardened but sensitive-action audit/MFA requirements need closure
**Severity: P1 High**

Positive evidence:
- HttpOnly cookies;
- SameSite=Lax;
- configurable Secure flag;
- refresh flow;
- server-side RBAC/permissions;
- structured errors;
- same-origin checks on inspected mutation routes.

Open review:
- prove same-origin/CSRF protection on every mutation path;
- ensure all sensitive mutations write structured audit records;
- define MFA requirement/readiness for `SUPER_ADMIN` and `RADIO_MANAGER`;
- verify logout/session revocation edge cases;
- verify reason/old/new values for critical changes.

### AUD-P1-005 — SECURITY DEFINER/public RPC surface needs systematic review
**Severity: P1 High**

The live database contains multiple SECURITY DEFINER functions for public catalogs/config, virtual radio, managed radio and provider sync.

Risk: unsafe `search_path`, excessive EXECUTE grants or business logic trapped in privileged RPCs can bypass intended API controls.

Required target: enumerate every function, owner, `search_path`, grants, callers and tests. Do not blindly convert or delete functions.

### AUD-P1-006 — CI combines deterministic, live-provider and release concerns
**Severity: P1 Medium/High**

Current Android workflow runs formatter mutations (`dart format`), tests, live external provider acceptance and APK release gates in one workflow and grants `contents: write` globally.

Risk: nondeterministic provider outage blocks internal PR validation; CI can change workspace formatting; permissions exceed least privilege for many steps.

Required target: deterministic PR CI, separate External Provider CI, Integration CI and Release CI. Formatting must be check-only. Release-only jobs receive write permission.

### AUD-P1-007 — Public/Elysia upstream hardening is inconsistent
**Severity: P1 Medium/High**

Supabase Quran adapter has explicit request timeout. Elysia independently calls providers without the same complete timeout/response-size/redirect/circuit-breaker policy.

Required target: common upstream policy for HTTPS, timeout, redirect bound, response-size bound, validation, cache, request ID and structured provider errors.

### AUD-P1-008 — Database baseline reproducibility is not yet proven by one explicit empty-DB gate
**Severity: P1 Medium/High**

The repo has a substantial historical migration chain and database test assets. The hardening mandate requires an explicit `empty DB -> all migrations -> seed -> validation` result and a duplicate-function/grant/index/constraint audit.

Required target: database baseline report and reproducible CI gate; no migration deletion/squash on the deployed environment.

### AUD-P2-001 — Flutter startup waits for non-critical services
**Severity: P2 Medium**

Multiple repositories/services initialize before `runApp`, including Mushaf/content/offline/download services.

Risk: unnecessary time-to-first-frame and larger startup failure surface.

Required target: classify critical vs deferred initialization, render a stable shell first, then lazy/background initialize non-critical features with readiness states and startup timing instrumentation.

### AUD-P2-002 — Flutter feature boundaries are weak in several large files
**Severity: P2 Medium**

Large screen/service files include Mushaf, Radio, Player, Reciters, Downloads and Search. The code is functional but responsibilities are concentrated.

Required target: incremental extraction around actual feature/domain boundaries; no framework rewrite and no ceremonial layering for small features.

### AUD-P2-003 — Admin API module is oversized
**Severity: P2 Medium**

`apps/admin/lib/api.ts` is a large multi-domain server module, with historical/phase-specific API code also present.

Required target: split by domain only after P0/P1 contract/security decisions are stable.

### AUD-P2-004 — README and historical architecture documentation are stale
**Severity: P2 Medium**

Root README still describes an earlier radio phase and explicitly excludes components that now exist in the repo.

Required target: update README after architecture decisions; preserve phase evidence under history/index rather than deleting it.

### AUD-P2-005 — Monorepo DX/governance needs consolidation
**Severity: P2 Low/Medium**

No single root developer command surface/CODEOWNERS governance was established in the audited state.

Required target: minimal root commands (`make` or equivalent), sensitive-path governance and a CODEOWNERS proposal without inventing unknown teams.

### AUD-P3-001 — Remaining UX/performance refinements
**Severity: P3 Low**

Additional caching/rendering/interaction optimizations should wait until integrity, security, API and runtime closure work is stable.

## 3. Priority queue after Phase 1

### P0 — must close before P2
1. Build canonical/versioned Quran integrity foundation and tests.
2. Finish cross-layer Reciter Identity invariant audit/contract.
3. Execute Radio Phase 6B single-runtime protected acceptance.
4. Complete critical Auth/RLS/secret/grant checks; preserve the now-correct virtual-radio RLS policies.

### P1
1. Produce Canonical API ADR and compatibility plan.
2. Replace production-sensitive process-local rate limiting.
3. Reorganize CI/release gates.
4. Establish observability baseline and SLO definitions.
5. Prove empty-database migration baseline and audit privileged functions/grants.
6. Harden public/provider fetch boundaries.

### P2
1. Optimize Flutter startup.
2. Incrementally modularize Flutter features.
3. Modularize Admin by domain.
4. Add root developer commands/governance.
5. Clean README/current/history documentation.

### P3
1. Performance refinements supported by measurements.
2. Non-critical refactors.
3. UX refinements not required for correctness/reliability.

## 4. Security posture observed during audit

- No evidence was found that a publishable Supabase key is being treated as a server secret in the mobile API design.
- Server secrets are represented as environment variables for Admin/Radio Engine/Audio Worker.
- Current virtual-radio tables are RLS-enabled with permission-aware policies in the connected DEVELOPMENT database.
- Admin authorization is server-side, not frontend-only, on inspected routes.
- The process-local rate limiter is explicitly not considered production-distributed protection.
- SECURITY DEFINER functions and grants need a dedicated systematic audit.

## 5. Quran/reciter posture observed during audit

- Quran audio wrong-reciter regression tests now exist and pass in the current branch CI.
- Offline downloads key local media by provider + reciter identity + edition + bitrate + surah/ayah and verify local SHA-256 before reuse.
- The image Mushaf asset pipeline is versioned and includes SHA-256/checksum support, with QuranPedia Hafs source pinned in code.
- Textual Quran data remains the highest-risk gap because it is still fetched live without a Tarteel canonical dataset/version/checksum gate.

## 6. Radio posture observed during audit

Phase 6 evidence is substantial: fencing, queues, command idempotency, real Liquidsoap/Icecast, fixed mount, two listeners and 30-minute soak. The audit does **not** downgrade that evidence. The remaining production gap is narrow but important: prove database claim/effect and real playout/ACK in the same long-lived secret-backed coordinator run.

## 7. Phase 1 acceptance

- Repository/component inventory: PASS.
- Current public/admin/data/audio/radio flows mapped: PASS.
- Current DEVELOPMENT RLS state inspected: PASS.
- Quran integrity risk identified from code: PASS.
- Reciter invariant evidence inspected: PASS WITH CROSS-LAYER GAP.
- Radio closure state reconciled with Phase 6 evidence: PASS WITH OPEN 6B GATE.
- CI/workflow structure inventoried: PASS.
- Architecture modified: NO.

**PHASE 1 — FULL REPOSITORY AUDIT: PASS WITH P0 FINDINGS**

Next step: Phase 2 gap analysis/documentation, followed by the least-breaking P0 implementation. The first code-changing P0 should be Quran Integrity foundation; it can be added alongside the current API before any compatibility switch.
