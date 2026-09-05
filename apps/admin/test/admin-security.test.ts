import test from 'node:test';
import assert from 'node:assert/strict';
import { sameOrigin, body } from '../lib/http.ts';
import { adminMutation } from '../lib/admin-mutation.ts';
import { sessionCookies } from '../lib/auth.ts';

const request = (origin = 'https://admin.test') => new Request('https://admin.test/api/v1/admin/settings', { method: 'POST', headers: { origin, cookie: 'tarteel_admin_access=user-token' } });
test('cookie mutations require an exact origin, including scheme', () => {
  for (const origin of ['', 'null', 'invalid', 'http://admin.test', 'https://evil.test']) assert.throws(() => sameOrigin(request(origin)), { code: 'CSRF_REJECTED' });
  assert.doesNotThrow(() => sameOrigin(request()));
});

test('Admin mutations authorize, audit before effects, and record outcomes without tokens', async t => {
  process.env.SUPABASE_URL = 'https://example.supabase.co';
  process.env.SUPABASE_PUBLISHABLE_KEY = 'public-test';
  process.env.SUPABASE_SECRET_KEY = 'private-test';
  const userId = '00000000-0000-4000-8000-000000000001';
  let permitted = true, auditAvailable = true, effects = 0;
  const events: string[] = [];
  t.mock.method(globalThis, 'fetch', async (input: unknown, init: RequestInit) => {
    const url = String(input);
    if (url.includes('/auth/v1/user')) return Response.json({ id: userId });
    if (url.includes('/administrators?')) return Response.json([{ id: userId, display_name: 'Admin' }]);
    if (url.includes('/administrator_roles?')) return Response.json([{ role_id: userId }]);
    if (url.includes('/roles?')) return Response.json([{ id: userId, code: 'SUPER_ADMIN' }]);
    if (url.includes('/role_permissions?')) return Response.json([{ permission_id: userId }]);
    if (url.includes('/permissions?')) return Response.json(permitted ? [{ code: 'settings.write' }] : []);
    if (url.endsWith('/audit_logs')) {
      if (!auditAvailable) return new Response(null, { status: 503 });
      const text = String(init.body);
      assert.doesNotMatch(text, /user-token|private-test|password/);
      events.push(JSON.parse(text).metadata.status);
      return Response.json([]);
    }
    throw new Error('unexpected request');
  });
  const run = () => adminMutation(request(), userId, async () => { effects++; return 'ok'; }, 'settings.write');
  await assert.rejects(adminMutation(new Request('https://admin.test/api/v1/admin/settings', { method: 'POST', headers: { origin: 'https://admin.test' } }), userId, async () => { effects++; }), { code: 'AUTH_REQUIRED' });
  permitted = false;
  await assert.rejects(run(), { code: 'FORBIDDEN' });
  assert.equal(effects, 0);
  permitted = true; auditAvailable = false;
  await assert.rejects(run());
  assert.equal(effects, 0);
  auditAvailable = true;
  assert.equal(await run(), 'ok');
  assert.deepEqual(events, ['STARTED', 'COMPLETED']);
  await assert.rejects(adminMutation(request(), userId, async () => { throw new Error('private'); }, 'settings.write'));
  assert.deepEqual(events.slice(-2), ['STARTED', 'FAILED']);
});

test('production cookies are secure even without the optional flag', t => {
  const previous = process.env.NODE_ENV;
  t.after(() => { if (previous === undefined) Reflect.deleteProperty(process.env, 'NODE_ENV'); else Reflect.set(process.env, 'NODE_ENV', previous); });
  Reflect.set(process.env, 'NODE_ENV', 'production');
  assert.ok(sessionCookies({ access_token: 'test', refresh_token: 'test', expires_in: 3600 }).every(cookie => cookie.includes('; Secure') && cookie.includes('; HttpOnly')));
});

test('chunked mutation payloads cannot bypass the size limit', async () => {
  const request=new Request('https://admin.test',{method:'POST',body:'{"value":"too large"}'});
  await assert.rejects(body(request,4),{code:'PAYLOAD_TOO_LARGE'});
  assert.deepEqual(await body(new Request('https://admin.test',{method:'DELETE'})),{});
});
