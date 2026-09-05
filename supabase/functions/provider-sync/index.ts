import { catalogSources, prepareCatalogRpc } from '../_shared/provider-catalog.ts';
import { fetchJsonResponse } from '../_shared/http.ts';

Deno.serve(async request => {
  const requestId = crypto.randomUUID();
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!key || request.method !== 'POST' || request.headers.get('authorization') !== `Bearer ${key}`) {
    return Response.json({ error: { code: 'FORBIDDEN', request_id: requestId } }, { status: 403 });
  }
  try {
    for (const name of Object.keys(catalogSources)) {
      const rpc = await prepareCatalogRpc(name, {});
      const response = await fetchJsonResponse(`${Deno.env.get('SUPABASE_URL')}/rest/v1/rpc/${rpc.name}`, {
        method: 'POST', headers: { apikey: key, authorization: `Bearer ${key}`, 'content-profile': 'app', 'content-type': 'application/json' },
        body: JSON.stringify(rpc.args),
      });
      if (!response.ok) throw new Error();
    }
    return Response.json({ data: { synced: true }, request_id: requestId });
  } catch {
    console.error(JSON.stringify({ event: 'PROVIDER_SYNC_FAILED', request_id: requestId }));
    return Response.json({ error: { code: 'PROVIDER_SYNC_FAILED', request_id: requestId } }, { status: 502 });
  }
});
