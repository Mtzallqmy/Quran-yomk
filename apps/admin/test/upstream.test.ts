import test from 'node:test';
import assert from 'node:assert/strict';
import { adminContext } from '../lib/auth.ts';
import { db, authPassword, authUser, authSignOut, createSignedDownload } from '../lib/supabase.ts';

test('Admin upstream fails closed and never returns backend details', async t => {
  process.env.SUPABASE_URL = 'https://example.supabase.co';
  process.env.SUPABASE_PUBLISHABLE_KEY = 'test-public';
  process.env.SUPABASE_SECRET_KEY = 'test-private';
  const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
  let reply = response([]);
  t.mock.method(globalThis, 'fetch', async (_url: unknown, init: RequestInit) => {
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal);
    return reply;
  });
  assert.deepEqual((await db('app', 'stations')).data, []);
  reply = response({ message: 'private database detail test-private' }, 500);
  await assert.rejects(db('app', 'stations'), { status: 502, message: 'Database request failed' });
  reply = new Response('<html>error</html>', { headers: { 'content-type': 'text/html' } });
  await assert.rejects(db('app', 'stations'), { code: 'UPSTREAM_INVALID_RESPONSE' });
  reply = response({ access_token: 'token' });
  await assert.rejects(authPassword('a@example.com', 'password'), { code: 'INVALID_AUTH_RESPONSE' });
  reply = response({ id: null });
  await assert.rejects(authUser('token'), { code: 'INVALID_AUTH_RESPONSE' });
  reply = response({ signedURL: 123 });
  await assert.rejects(createSignedDownload('bucket', 'object'), { code: 'STORAGE_ERROR' });
  reply = response({ message: 'private failure' }, 503);
  await assert.rejects(authSignOut('token'), { code: 'LOGOUT_FAILED' });
});

test('Auth outages never rotate refresh tokens or masquerade as expired sessions', async t => {
  process.env.SUPABASE_URL='https://example.supabase.co';process.env.SUPABASE_PUBLISHABLE_KEY='test-public';process.env.SUPABASE_SECRET_KEY='test-private';
  let status=503;let calls=0;
  t.mock.method(globalThis,'fetch',async (url:unknown)=>{calls++;assert.ok(String(url).endsWith('/auth/v1/user'));return new Response('private',{status});});
  for(const failure of [503,429]){status=failure;calls=0;await assert.rejects(adminContext(new Request('https://admin.test',{headers:{cookie:'tarteel_admin_access=access; tarteel_admin_refresh=refresh'}})),{code:'AUTH_UNAVAILABLE'});assert.equal(calls,1);}
});
