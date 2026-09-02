# Security Review — 2026-09 Hardening

## Supabase privilege audit

The connected `Quran stream` project was inspected read-only. Tables in private `app` and `radio` schemas have RLS enabled and are intentionally not exposed to ordinary clients. The absence of per-table policies in these private schemas is not treated as a reason to create permissive policies.

Public `tarteel_public_*` RPC wrappers are intentionally callable by `anon`/`authenticated` for the read-only public catalog. They use `SECURITY DEFINER` with an empty `search_path` and delegate to explicit application functions/tables. They remain a reviewed allowlist rather than being converted mechanically to `SECURITY INVOKER`, which would break the current public API contract because clients do not receive direct `app` schema access.

Security tests must continue to prove that private mutation/Radio functions are not executable by `anon` or ordinary `authenticated` roles.

## Findings addressed

1. Production cookie security now defaults to `Secure` when the environment is production.
2. Admin session AAL and session ID are derived only after Supabase has validated the access token.
3. Sensitive admin actions support fail-closed AAL2 enforcement through `TARTEEL_ADMIN_MFA_MODE=required`.
4. Current-session logout revocation is explicitly requested; local cookies are cleared even if the upstream revocation endpoint is temporarily unavailable.
5. Production throttling is distributed through PostgreSQL and no longer depends on the in-process Map.
6. Runtime configuration and managed-radio operations receive structured audit records.
7. Managed-radio forwarding uses the refreshed access token when server-side session refresh occurred, preventing stale-token forwarding.
8. Managed-radio upstream calls have a 10-second timeout, redirect rejection and a bounded response body.

## Remaining deployment work

MFA `required` mode should be enabled for privileged roles only after enrollment/challenge UX is operational and verified. Access JWT lifetime should remain short because session revocation invalidates refresh/session state while already-issued access JWTs remain usable until expiry.
