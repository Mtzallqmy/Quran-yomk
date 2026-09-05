import test from 'node:test';
import assert from 'node:assert/strict';
import { RadioEngine } from '../src/engine.js';
import type { Config } from '../src/config.js';
import type { LeaseStore, Track } from '../src/types.js';

test('empty and unknown ACKs cannot fabricate playback or advance history', () => {
  const engine = new RadioEngine({ mount: '/tarteel.mp3' } as Config, {} as LeaseStore);
  const track: Track = { mediaId: 'media-a', title: 'A', path: '/tmp/a.wav', durationSeconds: 20 };
  Reflect.set(engine, 'mainTracks', [track]);
  Reflect.set(engine, 'automationTracks', [{ ...track, queueEntryId: 'queued-a' }]);
  const acknowledge = (payload: string) => Reflect.get(engine, 'handleTrackStart').call(engine, payload);
  const events: string[] = [];
  engine.onTrackStart(event => events.push(event.track.title));
  for (const payload of ['{}', 'not-json', '{"tarteel_index":""}', '{"tarteel_index":null}', '{"queue_entry_id":"unknown","media_id":"media-a"}']) {
    acknowledge(payload);
  }
  assert.equal(engine.snapshot.current, null);
  assert.equal(engine.snapshot.playoutAckCount, 0);
  assert.deepEqual(events, []);
  acknowledge('{"tarteel_index":"0","media_id":"media-a","queue_entry_id":"none"}');
  assert.equal(engine.snapshot.current, track);
  assert.equal(engine.snapshot.playoutAckCount, 1);
  assert.deepEqual(events, ['A']);
});

test('replacing pending automation preserves the current track and removes stale requests', async () => {
  const engine = new RadioEngine({ mount: '/tarteel.mp3' } as Config, {} as LeaseStore);
  const current: Track = { mediaId: 'playing', queueEntryId: 'playing', title: 'Current', path: '/tmp/current.wav', durationSeconds: 20 };
  engine.snapshot.current = current;
  const pending = ['stale-a', 'stale-b'];
  Reflect.set(engine, 'source', {
    clearAutomation: async () => { pending.length = 0; },
    pushTrack: async (_path: string, _mediaId: string, id: string, interrupt: boolean) => {
      assert.equal(interrupt, false);
      pending.push(id);
    },
  });
  await engine.applyAutomationTracks([{ ...current, queueEntryId: 'next' }], false);
  assert.deepEqual(pending, ['next']);
  assert.equal(engine.snapshot.current, current);
});
