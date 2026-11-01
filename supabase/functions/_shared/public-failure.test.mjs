import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { stripTypeScriptTypes } from 'node:module';

test('public Edge distinguishes dependency failure and keeps unexpected exceptions private', async t => {
  let handler;
  const previous = globalThis.Deno;
  globalThis.Deno = {
    env: { get: name => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'public-test', SUPABASE_SERVICE_ROLE_KEY: 'server-test' })[name] },
    serve: value => { handler = value; },
  };
  t.after(() => { globalThis.Deno = previous; });
  const file = new URL('../tarteel-api/index.ts', import.meta.url);
  const source = (await readFile(file, 'utf8'))
    .replace(/import "jsr:[^"]+";\n/, '')
    .replace(/from "(\.[^"]+)"/g, (_, path) => `from "${new URL(path, file).href}"`);
  await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source)).toString('base64')}`);
  const logs = [];
  t.mock.method(console, 'error', value => logs.push(value));
  t.mock.method(globalThis, 'fetch', async () => new Response('password=private-upstream', { status: 503 }));
  const request = new Request('https://example.test/tarteel-api/surahs', { headers: { apikey: 'public-test' } });
  const upstream = await handler(request);
  assert.equal(upstream.status, 502);
  assert.equal((await upstream.json()).error.code, 'UPSTREAM_UNAVAILABLE');
  const broken = { headers: request.headers, method: 'GET', get url() { throw new Error('password=private-internal'); } };
  const internal = await handler(broken);
  assert.equal(internal.status, 500);
  assert.equal((await internal.json()).error.code, 'INTERNAL_ERROR');
  assert.ok(!logs.join('').includes('private'));
});
