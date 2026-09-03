# Distributed Rate Limit Runbook

The production limiter uses `app.rate_limit_buckets` and `app.consume_rate_limit` in PostgreSQL. Bucket keys are SHA-256 digests; raw IP addresses and administrator IDs are not persisted in the bucket key.

Operational checks:

- verify the migration is applied before deploying the hardened Admin build;
- verify `anon` and `authenticated` cannot execute the limiter RPC;
- verify `service_role` can execute it;
- send requests up to the configured threshold and confirm the next response is HTTP 429 with `Retry-After`;
- confirm normal requests resume after `reset_at`;
- alert on sustained `RATE_LIMIT_UNAVAILABLE` because the limiter fails closed when its backend cannot be reached.

The process-local development limiter is intentionally bypassed in production and is not a production control.
