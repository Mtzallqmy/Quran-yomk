import { catalogSources, prepareCatalogRpc } from '../_shared/provider-catalog.ts';
import { fetchJsonResponse } from '../_shared/http.ts';

export async function handleProviderSync(request: Request, env: (name: string) => string | undefined) {
  const requestId = crypto.randomUUID();
  const key = env('SUPABASE_SERVICE_ROLE_KEY');
  if (!key || request.method !== 'POST' || !/^Bearer [a-f0-9]{64}$/.test(request.headers.get('authorization') ?? '')) {
    return Response.json({ error: { code: 'FORBIDDEN', request_id: requestId } }, { status: 403 });
  }
  try {
    const authorized = await fetchJsonResponse(`${env('SUPABASE_URL')}/rest/v1/rpc/authorize_provider_sync`, {
      method: 'POST', headers: { apikey: key, authorization: `Bearer ${key}`, 'content-profile': 'app', 'content-type': 'application/json' },
      body: JSON.stringify({ p_token: request.headers.get('authorization')!.slice(7) }),
    });
    if (!authorized.ok || await authorized.json() !== true) return Response.json({ error: { code: 'FORBIDDEN', request_id: requestId } }, { status: 403 });
    for (const name of Object.keys(catalogSources)) {
      const rpc = await prepareCatalogRpc(name, {});
      const response = await fetchJsonResponse(`${env('SUPABASE_URL')}/rest/v1/rpc/${rpc.name}`, {
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
}

if (typeof Deno !== 'undefined') Deno.serve(request => handleProviderSync(request, name => Deno.env.get(name)));
