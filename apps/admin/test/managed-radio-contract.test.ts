import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';

const root=new URL('../../../',import.meta.url);
const read=(path:string)=>readFile(new URL(path,root),'utf8');

test('ManagedRadioService keeps provider credentials in Supabase Edge only',async()=>{
  const edge=await read('supabase/functions/tarteel-managed-radio/index.ts');
  const mobile=await Promise.all([
    read('apps/mobile/lib/src/api.dart'),
    read('apps/mobile/lib/src/virtual_radio.dart'),
    read('apps/mobile/lib/src/playback.dart'),
  ]).then(x=>x.join('\n'));
  assert.match(edge,/interface ManagedRadioService/);
  assert.match(edge,/RADIOCO_STATION_ID/);
  assert.match(edge,/RADIOCO_STUDIO_AUTHORIZATION/);
  assert.doesNotMatch(mobile,/RADIOCO_STUDIO_AUTHORIZATION|RADIOCO_STATION_ID|RADIOCO_.*TOKEN/);
});

test('managed radio writes are explicit and microphone is out of scope',async()=>{
  const edge=await read('supabase/functions/tarteel-managed-radio/index.ts');
  assert.match(edge,/SYNC_SCHEDULE/);
  assert.match(edge,/TEST_RELAY/);
  assert.match(edge,/REFRESH_NOW_PLAYING/);
  assert.match(edge,/PRIMARY_RELAY/);
  assert.match(edge,/SECONDARY_RELAY/);
  assert.match(edge,/BACKUP_PLAYLIST/);
  assert.doesNotMatch(edge,/START_MICROPHONE|START_LIVE_DJ|MICROPHONE_STREAM/);
});

test('public managed resolver separates relay source from final playback',async()=>{
  const migration=await read('supabase/migrations/20260831001200_managed_radio_fixed_stream_contract.sql');
  assert.match(migration,/relay_source/);
  assert.match(migration,/MANAGED_RADIO/);
  assert.match(migration,/seekable',false/);
  assert.match(migration,/station,playback_url/);
});
