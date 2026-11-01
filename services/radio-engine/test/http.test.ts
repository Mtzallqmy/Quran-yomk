import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchBackend, fetchBoundedResponse } from '../src/http.js';

test('backend downloads enforce size and type before SDK buffering', async t => {
  let response = new Response(new Uint8Array([1]), { headers: { 'content-type': 'audio/mp4' } });
  t.mock.method(globalThis, 'fetch', async (_url: unknown, init: RequestInit) => {
    assert.equal(init.redirect, 'error'); assert.ok(init.signal); return response;
  });
  assert.equal((await (await fetchBackend('https://example.test/storage/v1/object/media')).arrayBuffer()).byteLength, 1);
  response = new Response('html');
  await assert.rejects(fetchBackend('https://example.test/storage/v1/object/media'), { code: 'UPSTREAM_INVALID_RESPONSE' });
  response = new Response('', { headers: { 'content-type': 'audio/mp4', 'content-length': '52428801' } });
  await assert.rejects(fetchBackend('https://example.test/storage/v1/object/media'), { code: 'UPSTREAM_RESPONSE_TOO_LARGE' });
  response = Response.json({ error: 'private' });
  await assert.rejects(fetchBackend('https://example.test/rest/v1/rpc/test'), { code: 'UPSTREAM_INVALID_RESPONSE' });
});

test('Icecast metadata silent failure is rejected and body reads have a deadline', async t => {
  let response = new Response('<iceresponse><return>0</return></iceresponse>', { headers: { 'content-type': 'text/xml' } });
  t.mock.method(globalThis, 'fetch', async () => response);
  await assert.rejects(fetchBoundedResponse('http://localhost/admin', {}, { format: 'xml' }), { code: 'UPSTREAM_INVALID_RESPONSE' });
  response = new Response('<iceresponse><return>1</return></iceresponse>', { headers: { 'content-type': 'text/xml' } });
  assert.equal((await fetchBoundedResponse('http://localhost/admin', {}, { format: 'xml' })).ok, true);
  t.mock.method(globalThis, 'fetch', async (_url: unknown, init: RequestInit) => new Response(new ReadableStream({
    start(controller) { init.signal?.addEventListener('abort', () => controller.error(new Error('secret')), { once: true }); },
  }), { headers: { 'content-type': 'application/json' } }));
  await assert.rejects(fetchBoundedResponse('http://localhost', {}, { timeoutMs: 10 }), { code: 'UPSTREAM_TIMEOUT' });
});
