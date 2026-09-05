import test from 'node:test';
import assert from 'node:assert/strict';
import { handleProviderSync } from '../provider-sync/index.ts';
const env = name => ({ SUPABASE_SERVICE_ROLE_KEY: 'internal-test-role', SUPABASE_URL: 'https://example.supabase.co' })[name];
test('dispatch requires a dedicated token, never a client service-role key', async t => {
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async () => { calls++; return Response.json(false); });
  for (const token of ['', 'Bearer internal-test-role', 'Bearer wrong']) {
    const response = await handleProviderSync(new Request('https://example.test', { method: 'POST', headers: { authorization: token } }), env);
    assert.equal(response.status, 403);
  }
  assert.equal(calls, 0);
  const response = await handleProviderSync(new Request('https://example.test', { method: 'POST', headers: { authorization: `Bearer ${'0'.repeat(64)}` } }), env);
  assert.equal(response.status, 403);
  assert.equal(calls, 1);
});

test('authorized scheduled sync preserves the existing provider scope', async t => {
  const calls = [];
  t.mock.method(globalThis, 'fetch', async url => {
    calls.push(String(url));
    if (String(url).endsWith('authorize_provider_sync')) return Response.json(true);
    if (String(url).startsWith('https://raw.githubusercontent.com/')) return Response.json({ stations: [{ id: '1' }] });
    if (String(url).endsWith('sync_islamic_radio_api_stations_payload')) return Response.json({ run_id: 'run' });
    throw new Error('unexpected endpoint');
  });
  const request = () => new Request('https://example.test', { method: 'POST', headers: { authorization: `Bearer ${'0'.repeat(64)}` } });
  assert.equal((await handleProviderSync(request(), env)).status, 200);
  assert.equal(calls.length, 3);
  t.mock.method(globalThis, 'fetch', async () => Response.json({ error: 'private' }));
  const response = await handleProviderSync(request(), env);
  assert.equal(response.status, 502);
  assert.ok(!(await response.text()).includes('private'));
});
