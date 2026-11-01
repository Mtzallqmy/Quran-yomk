import test from 'node:test';
import assert from 'node:assert/strict';
import { rateLimit } from '../lib/rate-limit.ts';

test('every limiter call uses shared state, hashes identities and fails closed', async t => {
  process.env.SUPABASE_URL = 'https://example.supabase.co';
  process.env.SUPABASE_PUBLISHABLE_KEY = 'public-test';
  process.env.SUPABASE_SECRET_KEY = 'private-test';
  let allowed: unknown = true;
  let calls = 0;
  t.mock.method(globalThis, 'fetch', async (url: unknown, init: RequestInit) => {
    assert.ok(String(url).endsWith('/rpc/consume_rate_limit'));
    const args = JSON.parse(String(init.body));
    assert.match(args.p_bucket_key, /^[0-9a-f]{64}$/);
    assert.equal(args.p_limit, 10);
    assert.ok(!String(init.body).includes('person@example.com'));
    calls++;
    return Response.json(allowed);
  });
  await rateLimit('login-account:person@example.com', 10, 60000);
  await rateLimit('login-account:person@example.com', 10, 60000);
  assert.equal(calls, 2);
  for (const invalid of [false, null, { allowed: true }]) {
    allowed = invalid;
    await assert.rejects(rateLimit('login-account:person@example.com', 10, 60000), { code: 'RATE_LIMITED' });
  }
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('private'); });
  await assert.rejects(rateLimit('login-account:person@example.com', 10, 60000), { code: 'UPSTREAM_UNAVAILABLE' });
});
