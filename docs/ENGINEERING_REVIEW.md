# Engineering Review

Updated 2026-09-05. Current repository evidence is distinguished from deployment
verification and untested operational recommendations. Detailed gap status is in
[ARCHITECTURE_GAPS.md](ARCHITECTURE_GAPS.md).

## Verified hardening

| Risk | Implemented protection | Evidence / limit |
|---|---|---|
| Broken fresh database or grant drift | Full migrations/seed, core catalogs, RBAC, grants, atomic runtime updates; two rebuilds and schema comparison. | #29, #36–#38; DB run 33998661750 passed. This does not reset or migrate a live database. |
| Provider hang, oversized body, redirects, invalid data | Bounded HTTP helpers, content/status/schema checks, closed redirect policy; fixed HTTPS allowlists for URL-influenced probes. | #30–#36; failure fixtures passed. No claim of arbitrary-host DNS rebinding protection: probe hosts are allowlisted. |
| SQL provider ingestion corrupts catalog after failure | Only validated server payloads reach ingestion; malformed/empty catalogs fail before missing-item updates; scheduled requests require a dedicated server token. | #36; deployment and Vault endpoint setup remain required. |
| Unauthorized Admin mutations / CSRF | Shared auth, action permissions, exact Origin, secure cookies and bounded bodies. Runtime configuration RPC repeats permission checks atomically. | #37; regression tests cover deny paths and audit failures. |
| Missing sensitive-operation evidence | STARTED audit before effects, outcome audit afterward; atomic runtime settings audit; no raw body/cookies in generic audit. | #37. Failure to confirm a post-effect audit returns 503 and requires state reconciliation before retry. |
| Cross-instance rate-limit bypass | Persistent shared DB buckets, hashed keys, account/IP limits and lock-safe cleanup. | #38; limit/reset/fresh-connection/32-client concurrency and concurrent-renewal tests passed twice. |
| False health and private exception leakage | Elysia/Edge dependency failures return 503; radio readiness checks live lease and distribution components. Request IDs and fixed error codes; raw exception text removed from critical logs. | #39–#40; deployed versions still require reconciliation. Health is not a waveform/silence guarantee. |
| Startup waits for optional disk/network work | Deferred independent post-frame tasks and lazy storage; early offline operations await a shared initialization future. | #41; Flutter analysis/tests and Universal/ARM64 release builds passed in run 33998990465. |
| Public/Admin rules difficult to inspect | Public-read dispatch extracted unchanged; auth, mutation guard, HTTP and limiter remain separate. | #42; run 33999382817 passed types, tests and production Admin build. |
| Radio command/ACK correctness | Deterministic scheduling, queue replacement, fencing and actual track-start ACK regressions retained. | Current unit tests passed. Real broadcast/soak tests are waived by owner instruction, not claimed green. |
| CI false green | Database assertions fail on false/NULL; schema drift fails; formatting is check-only; release APKs actually build. Live providers are separate. | Deterministic CI remains mandatory. Android physical-device/emulator acceptance is not implied by PR CI. |

## Production verification still open

The connected Supabase project was ACTIVE_HEALTHY during read-only inspection,
but its recorded migration versions and deployed functions lag the merged code.
Security advisors returned INFO-only findings; this is not evidence that the new
Admin grants, provider dispatcher or health function have been deployed.

Before claiming production readiness, reconcile deployment state, verify server
secret placement and operational configuration, and record any accepted P1 risk.
Do not expose service-role credentials to Flutter, browser bundles or logs.
Repository hardening has no known P0 established by this review; that statement
is not a completed final production audit.

## Operational decisions and limits

- Liquidsoap is the implemented continuous playout adapter; FFmpeg remains the
  processing/probe tool. This is no longer an unresolved engine choice.
- One DB project, playout host and Icecast endpoint remain potential single
  failure points. HA, restore testing and capacity require deployment evidence.
- Define production region/timezone, rights approvers, codec policy, retention,
  SLO/RPO/RTO and failure thresholds before an operational production sign-off.
- MFA policy for sensitive administrators and dependency/SBOM maintenance remain
  operational follow-up; they are not silently represented as deployed controls.
- Fault injection, multi-host failover and waveform/silence acceptance are not
  inferred from unit tests. No arbitrary count of unresolved decisions is used.

Historical phase reports document their original acceptance scope. They are not
current production certification and must not override the open items above.
