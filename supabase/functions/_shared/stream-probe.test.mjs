import test from 'node:test';
import assert from 'node:assert/strict';
import { probeTrustedStream, trustedProbeUrl } from './stream-probe.ts';

test('private, obfuscated, credentialed and unapproved URLs never reach fetch', async () => {
  for (const url of ['https://127.0.0.1/a', 'https://2130706433/a', 'https://[::1]/', 'https://localhost/',
    'https://169.254.169.254/', 'https://radio.co.evil.test/', 'https://evilradio.co/',
    'https://radio.co@127.0.0.1/', 'https://user:secret@streaming.radio.co/', 'http://backup.qurango.net/',
    'https://backup.qurango.net:8443/', 'https://attacker.test/']) {
    const result = await probeTrustedStream(url, async () => { throw new Error('fetch must not run'); });
    assert.equal(trustedProbeUrl(url), null);
    assert.equal(result.error, 'UNAPPROVED_STREAM_HOST');
  }
});

test('trusted audio has a deadline and redirects disabled; body is cancelled', async () => {
  let cancelled = false;
  const result = await probeTrustedStream('https://backup.qurango.net/radio/test', async (_url, init) => {
    assert.equal(init.redirect, 'error');
    assert.ok(init.signal instanceof AbortSignal);
    return new Response(new ReadableStream({ cancel() { cancelled = true; } }), { headers: { 'content-type': 'audio/mpeg' } });
  });
  assert.equal(result.ok, true);
  assert.equal(cancelled, true);
});

test('redirects to metadata endpoints and HTML 200s are never healthy', async () => {
  for (const response of [
    new Response(null, { status: 302, headers: { location: 'https://169.254.169.254/', 'content-type': 'audio/mpeg' } }),
    new Response('<html>failure</html>', { headers: { 'content-type': 'text/html' } }),
    new Response(null, { status: 500, headers: { 'content-type': 'audio/mpeg' } }),
  ]) {
    let calls = 0;
    const result = await probeTrustedStream('https://stream.radiojar.com/test', async () => { calls++; return response; });
    assert.equal(result.ok, false);
    assert.equal(calls, 1);
  }
});

test('provider exceptions do not expose credentials', async () => {
  const result = await probeTrustedStream('https://streaming.radio.co/test', async () => { throw new Error('password=private'); });
  assert.equal(result.ok, false);
  assert.equal(result.error, 'STREAM_PROBE_FAILED');
  assert.ok(!JSON.stringify(result).includes('private'));
});
