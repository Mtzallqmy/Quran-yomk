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
