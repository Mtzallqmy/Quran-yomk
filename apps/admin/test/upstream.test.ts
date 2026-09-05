import test from 'node:test';
import assert from 'node:assert/strict';
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
