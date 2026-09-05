import test from 'node:test';
import assert from 'node:assert/strict';
import { apiHealth } from '../tarteel-api-health/index.ts';

test('Edge health rejects silent 200s and never exposes signed playback URLs', async t => {
  const env = name => ({ SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'test' })[name];
  const request = new Request('https://example.test');
  t.mock.method(globalThis, 'fetch', async () => Response.json({ data: [] }));
  assert.equal((await apiHealth(request, env)).status, 503);
  t.mock.method(globalThis, 'fetch', async url => {
    if (String(url).endsWith('/surahs')) return Response.json({ data: [{ track: { playback_url: 'https://audio.test/file?token=private' } }] });
    if (String(url).includes('/reciters?')) return Response.json({ data: [{ id: '00000000-0000-4000-8000-000000000001' }] });
    return Response.json({ data: [{ playback_url: 'https://audio.test/station' }] });
  });
  const response = await apiHealth(request, env);
  assert.equal(response.status, 200);
  assert.ok(!(await response.text()).includes('private'));
  t.mock.method(globalThis, 'fetch', async () => { throw new Error('password=private'); });
  const failure = await apiHealth(request, env);
  assert.equal(failure.status, 503);
  assert.ok(!(await failure.text()).includes('private'));
});
