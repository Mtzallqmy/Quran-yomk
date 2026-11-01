# Protected catalog synchronization

Deploy `provider-sync` together with the provider catalog ingestion migration and updated Admin. Provider downloads now run through the bounded Edge transport. SQL ingestion accepts only server-authorized JSON and rejects missing/empty catalogs; legacy network RPCs fail closed. Existing stations remain available when a provider fails.

For the daily 02:17 UTC job, configure the endpoint Vault secret through the Supabase dashboard, never through client code or committed SQL:

- `tarteel_provider_sync_url`: `https://<project-ref>.supabase.co/functions/v1/provider-sync`
The migration creates `tarteel_provider_sync_key` from 32 cryptographically random bytes inside Vault. The Edge function verifies it through a service-only RPC; callers never send the service-role key. JWT gateway validation is disabled specifically for this function because it implements this separate token check. Do not expose or overwrite the generated token.

Missing configuration causes an explicit cron failure. The dispatcher returns a pg_net request ID; inspect its response in `net._http_response` and the structured `PROVIDER_SYNC_FAILED` Edge event. A queued HTTP request alone is not proof of a successful catalog sync. Verify HTTP 200 and completed provider sync records after deployment. Do not publish response headers or Vault values in logs.

CI tests rebuilds and invalid catalog rejection without calling live providers. Production Vault configuration and a successful authenticated dispatch must be verified in the target project before considering scheduled sync operational.
