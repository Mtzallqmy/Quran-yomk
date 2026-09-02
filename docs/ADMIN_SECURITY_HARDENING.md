# Admin Security Hardening

## Scope

This document records the production-hardening controls for the Next.js Admin API without changing the existing RBAC model or replacing Supabase Auth.

## Session and cookie policy

- Access and refresh tokens remain server-managed HttpOnly cookies.
- `SameSite=Lax` is retained to preserve normal same-site navigation while origin checks protect mutations.
- `Secure` defaults to `true` when `TARTEEL_ENVIRONMENT=production`; an explicit `TARTEEL_COOKIE_SECURE` override remains for controlled environments.
- Session refresh happens server-side. If a sensitive managed-radio request refreshed its access token, the refreshed token is forwarded instead of the stale request cookie.
- Logout requests revoke the current Supabase session (`scope=local`) on a best-effort basis and always clear local cookies. Supabase access JWTs can remain valid until their configured expiry, so production JWT expiry should remain short for administrators.

## MFA readiness

`TARTEEL_ADMIN_MFA_MODE` accepts:

- `off`: do not apply an AAL gate.
- `ready` (default): expose/record AAL metadata but do not block an existing deployment that has no MFA enrollment flow yet.
- `required`: sensitive mutations fail closed unless the already-validated Supabase access token carries `aal2`.

Sensitive routes include radio commands/control, runtime configuration, settings, external-station/rights changes, and future RBAC mutations. Production rollout should move SUPER_ADMIN and RADIO_MANAGER accounts to `required` only after verified TOTP enrollment/challenge UX is available.

## Distributed rate limiting

Production enforcement no longer depends on the process-local `Map`. The private `app.consume_rate_limit` RPC atomically updates SHA-256 bucket keys in PostgreSQL. `anon` and `authenticated` receive no table or function privileges; only `service_role` may consume buckets.

Dimensions:

- login: IP + action, 10/minute;
- public search: IP + action, 60/minute;
- sensitive admin mutations: admin ID + action and IP + action;
- radio control, runtime config, managed radio and upload operations use tighter action-specific limits.

A rejected request returns HTTP 429 with `Retry-After` when the reset time is known.

## CSRF and authorization

Existing server-side `adminContext` + permission checks remain authoritative. Mutation routes continue to use same-origin validation. Frontend state is not trusted for authorization.

## Audit

Runtime configuration and managed-radio operations now append redacted audit entries with actor, action, target, request ID, AAL, old/new values where available, and an optional operator reason. Existing central API mutations retain their historical audit path.

## Deployment order

1. Apply `20260903010000_distributed_rate_limits.sql`.
2. Verify the function is executable only by `service_role`.
3. Deploy Admin.
4. Smoke login/search/admin mutations and verify 429/Retry-After behavior.
5. Enable `TARTEEL_ADMIN_MFA_MODE=required` only after MFA enrollment/challenge is operational for privileged roles.

## Rollback

Application rollback is safe because the migration is additive. The private rate-limit table/function may remain in place; do not delete historical migrations. If the Admin build is rolled back, the old local limiter resumes its previous behavior.
