import test from 'node:test';
import assert from 'node:assert/strict';
import { prepareCatalogRpc } from './provider-catalog.ts';

test('catalog sync ignores caller URLs and never passes empty or invalid catalogs to SQL', async t => {
  let payload = { stations: [{ id: '1', streamUrl: 'https://example.test/audio' }] };
  t.mock.method(globalThis, 'fetch', async (url, init) => {
    assert.equal(url, 'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json');
    assert.equal(init.redirect, 'error');
    return Response.json(payload);
  });
  const result = await prepareCatalogRpc('sync_islamic_radio_api_stations', { url: 'http://169.254.169.254' });
  assert.equal(result.name, 'sync_islamic_radio_api_stations_payload');
  assert.deepEqual(result.args, { p_payload: payload });
  for (const invalid of [{}, { stations: [] }, { stations: {} }, { error: 'private' }]) {
    payload = invalid;
    await assert.rejects(prepareCatalogRpc('sync_islamic_radio_api_stations', {}));
  }
  assert.deepEqual(await prepareCatalogRpc('unrelated', { a: 1 }), { name: 'unrelated', args: { a: 1 } });
  assert.deepEqual(await prepareCatalogRpc('constructor', {}), { name: 'constructor', args: {} });
});
