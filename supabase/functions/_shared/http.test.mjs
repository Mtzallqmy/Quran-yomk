import test from 'node:test';
import assert from 'node:assert/strict';
import { fetchJsonResponse } from './http.ts';
const originalFetch = globalThis.fetch;
test.afterEach(() => { globalThis.fetch = originalFetch; });

test('valid JSON and empty successful mutations retain their semantics', async () => {
  globalThis.fetch = async (_url, init) => {
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal instanceof AbortSignal);
    return Response.json({ data: [1] });
  };
  assert.deepEqual(await (await fetchJsonResponse('https://upstream.test')).json(), { data: [1] });
  globalThis.fetch = async () => new Response(null, { status: 204 });
  assert.equal((await fetchJsonResponse('https://upstream.test')).status, 204);
});

test('non-JSON and malformed JSON fail closed', async () => {
  for (const response of [new Response('<html>private</html>'), new Response('{', { headers: { 'content-type': 'application/json' } }), Response.json({ error: 'private' })]) {
    globalThis.fetch = async () => response;
    await assert.rejects(fetchJsonResponse('https://upstream.test'), { code: 'UPSTREAM_INVALID_RESPONSE' });
  }
});

test('oversized declared and chunked bodies are cancelled', async () => {
  for (const declared of [null, '99']) {
    let cancelled = false;
    const headers = { 'content-type': 'application/json' };
    if (declared) headers['content-length'] = declared;
    globalThis.fetch = async () => new Response(new ReadableStream({
      pull(controller) { controller.enqueue(new Uint8Array(8)); },
      cancel() { cancelled = true; },
    }), { headers });
    await assert.rejects(fetchJsonResponse('https://upstream.test', {}, { maxBytes: 12 }), { code: 'UPSTREAM_RESPONSE_TOO_LARGE' });
    assert.equal(cancelled, true);
  }
});

test('the deadline covers stalled bodies, not only response headers', async () => {
  globalThis.fetch = async (_url, init) => new Response(new ReadableStream({
    start(controller) { init.signal.addEventListener('abort', () => controller.error(new Error('private')), { once: true }); },
  }), { headers: { 'content-type': 'application/json' } });
  await assert.rejects(fetchJsonResponse('https://upstream.test', {}, { timeoutMs: 10 }), { code: 'UPSTREAM_TIMEOUT', status: 503 });
});

test('upstream status bodies and network exceptions cannot disclose secrets', async () => {
  globalThis.fetch = async () => new Response('password=private', { status: 403 });
  const response = await fetchJsonResponse('https://upstream.test');
  assert.equal(response.status, 403);
  assert.equal(await response.text(), '');
  globalThis.fetch = async () => { throw new Error('token=private'); };
  await assert.rejects(fetchJsonResponse('https://upstream.test'), error => error.code === 'UPSTREAM_UNAVAILABLE' && !error.message.includes('private'));
});
