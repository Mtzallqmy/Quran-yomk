import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { TrustedStorage } from '../src/storage.js';
import { fetchJsonResponse } from '../src/http.js';

test('storage download rejects redirects, bad types and oversized streams', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'storage-http-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const storage = new TrustedStorage('https://example.supabase.co', 'test-key');
  const key = `media/${'a'.repeat(36)}/original/${'b'.repeat(36)}.mp3`;
  let response = new Response(new Uint8Array([1, 2]), { headers: { 'content-type': 'audio/mpeg' } });
  t.mock.method(globalThis, 'fetch', async (_url: unknown, init: RequestInit) => {
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal);
    return response;
  });
  await storage.download('tarteel-media-originals', key, join(dir, 'valid'), 1000, 2);
  assert.equal((await readFile(join(dir, 'valid'))).length, 2);
  for (const [index, invalid] of [
    new Response(null, { status: 302, headers: { location: 'http://169.254.169.254' } }),
    new Response('html', { headers: { 'content-type': 'text/html' } }),
    new Response(new Uint8Array(3), { headers: { 'content-type': 'audio/mpeg' } }),
    new Response(new Uint8Array(1), { headers: { 'content-type': 'audio/mpeg' } }),
    new Response(new Uint8Array(2), { headers: { 'content-type': 'audio/mpeg', 'content-length': '999999' } }),
  ].entries()) {
    response = invalid;
    await assert.rejects(storage.download('tarteel-media-originals', key, join(dir, `bad-${index}`), 1000, 2));
  }
  response = new Response(new ReadableStream({ start() {} }), { headers: { 'content-type': 'audio/mpeg' } });
  await assert.rejects(storage.download('tarteel-media-originals', key, join(dir, 'timeout'), 10, 2), { code: 'DOWNLOAD_FAILED' });
});

test('SDK transport rejects invalid JSON and excessive response sizes', async t => {
  let response = Response.json({ ok: true });
  t.mock.method(globalThis, 'fetch', async () => response);
  assert.deepEqual(await (await fetchJsonResponse('https://example.test')).json(), { ok: true });
  response = Response.json({ error: 'private backend error' });
  await assert.rejects(fetchJsonResponse('https://example.test'), { code: 'UPSTREAM_INVALID_RESPONSE' });
  response = Response.json({ text: 'large' });
  await assert.rejects(fetchJsonResponse('https://example.test', {}, { maxBytes: 1 }), { code: 'UPSTREAM_RESPONSE_TOO_LARGE' });
});
