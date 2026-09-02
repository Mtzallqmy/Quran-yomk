# Admin MFA Rollout Runbook

1. Ensure privileged SUPER_ADMIN and RADIO_MANAGER users can enroll a verified Supabase MFA factor.
2. Verify the Admin UI can complete challenge/verify and receive an `aal2` access token.
3. Keep `TARTEEL_ADMIN_MFA_MODE=ready` while enrollment is being introduced.
4. Test radio command, external rights/config and runtime-config mutations with both `aal1` and `aal2` sessions.
5. Set `TARTEEL_ADMIN_MFA_MODE=required` in production only after the `aal2` success path is confirmed.
6. Confirm an `aal1` sensitive mutation returns `MFA_REQUIRED` without changing data.
7. Confirm `aal2` mutations preserve RBAC, origin validation, distributed rate limits and audit records.
8. Record rollout date and responsible release in the engineering hardening report.

Rollback: return the mode to `ready`; do not weaken RBAC or CSRF controls as an MFA workaround.
