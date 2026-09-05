# Protected catalog synchronization

Deploy `provider-sync` together with the provider catalog ingestion migration and updated Admin. Provider downloads now run through the bounded Edge transport. SQL ingestion accepts only server-authorized JSON and rejects missing/empty catalogs; legacy network RPCs fail closed. Existing stations remain available when a provider fails.

For the daily 02:17 UTC job, configure these Vault secrets through the Supabase dashboard, never through client code or committed SQL:

- `tarteel_provider_sync_url`: `https://<project-ref>.supabase.co/functions/v1/provider-sync`
- `tarteel_provider_sync_key`: this project's service-role JWT, matching the Edge runtime's `SUPABASE_SERVICE_ROLE_KEY`.

Missing configuration causes an explicit cron failure. The dispatcher returns a pg_net request ID; inspect its response in `net._http_response` and the structured `PROVIDER_SYNC_FAILED` Edge event. A queued HTTP request alone is not proof of a successful catalog sync. Verify HTTP 200 and completed provider sync records after deployment. Do not publish response headers or Vault values in logs.

CI tests rebuilds and invalid catalog rejection without calling live providers. Production Vault configuration and a successful authenticated dispatch must be verified in the target project before considering scheduled sync operational.
