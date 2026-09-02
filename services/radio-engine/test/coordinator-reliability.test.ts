import test from 'node:test';
import assert from 'node:assert/strict';
import type { Config } from '../src/config.js';
import { RadioCoordinator, type AutomationStore, type CoordinatorEngine } from '../src/coordinator.js';
import type { ClaimedCommand, ClaimedOccurrence, EnqueueInput } from '../src/automation-store.js';
import type { EngineSnapshot, Lease, Track } from '../src/types.js';

const stationId = '00000000-0000-4000-8000-000000000006';
const lease = (fencingToken = 7): Lease => ({
  stationId,
  ownerId: 'reliability-test',
  fencingToken,
  expiresAt: '2099-01-01T00:00:00Z',
});
const config: Config = {
  stationId,
  ownerId: 'reliability-test',
  databaseMode: 'supabase',
  supabaseUrl: 'https://example.invalid',
  supabaseSecretKey: 'test-only',
  ffmpegPath: 'ffmpeg',
  ffprobePath: 'ffprobe',
  liquidsoapPath: 'liquidsoap',
  liquidsoapAllowRoot: false,
  icecastHost: '127.0.0.1',
  icecastPort: 8000,
  mount: '/tarteel.mp3',
  sourceUser: 'source',
  sourcePassword: 'test',
  playlistPath: '/tmp/playlist.json',
  fallbackPath: '/tmp/fallback.m4a',
  workspaceRoot: '/tmp/radio',
  healthPort: 8091,
  leaseSeconds: 15,
  heartbeatSeconds: 5,
  sourceTimeoutSeconds: 20,
  restartMax: 5,
  version: 'test',
  schedulerPollSeconds: 5,
  commandPollSeconds: 2,
  missedGraceSeconds: 120,
  queueLookaheadSeconds: 120,
  liquidsoapControlPort: 1234,
  faultInjectionEnabled: false,
};

function snapshot(): EngineSnapshot {
  return {
    mode: 'AUTO',
    sourceConnected: true,
    liquidsoapAlive: true,
    icecastReachable: true,
    mountAvailable: true,
    broadcasting: true,
    streamMount: '/tarteel.mp3',
    current: null,
    next: null,
    currentStartedAt: null,
    expectedEndAt: null,
    sourceStartedAt: null,
    lastError: null,
    lastRecoveryAt: null,
    reconnectCount: 0,
    trackFailures: 0,
    playoutAckCount: 0,
  };
}

class ReliabilityEngine implements CoordinatorEngine {
  activeLease: Lease | null = lease();
  snapshot = snapshot();
  applied: Track[] = [];
  private readonly tracks = new Map<string, Track>([
    ['m1', { mediaId: 'm1', title: 'One', path: '/one.m4a', durationSeconds: 20 }],
  ]);

  resolveMediaTrack(id: string): Track {
    const value = this.tracks.get(id);
    if (!value) throw new Error('MEDIA_NOT_FOUND');
    return { ...value };
  }
  resolvePlaylistTracks(): Track[] {
    return [this.resolveMediaTrack('m1')];
  }
  async applyAutomationTracks(tracks: Track[]): Promise<void> {
    this.applied = tracks.map((track) => ({ ...track }));
  }
  async skipCurrent(): Promise<void> {}
  async clearAutomation(): Promise<void> {}
  async setAutomationMode(mode: 'AUTO' | 'SCHEDULED' | 'MANUAL'): Promise<void> {
    this.snapshot.mode = mode;
  }
}

class ReliabilityStore implements AutomationStore {
  occurrence: ClaimedOccurrence | null = null;
  command: ClaimedCommand | null = null;
  recoveryTokens: number[] = [];
  completedCommands: Array<{ id: string; ok: boolean; errorCode?: string }> = [];
  completedOccurrences: Array<{ id: string; ok: boolean }> = [];
  enqueues: EnqueueInput[] = [];
  recoverFailures = 0;
  materializeFailures = 0;

  async recover(currentLease: Lease): Promise<Record<string, unknown>> {
    this.recoveryTokens.push(currentLease.fencingToken);
    if (this.recoverFailures > 0) {
      this.recoverFailures -= 1;
      throw new Error('DB_TEMPORARY_FAILURE');
    }
    return { recovered: true };
  }
  async materialize(): Promise<number> {
    if (this.materializeFailures > 0) {
      this.materializeFailures -= 1;
      throw new Error('DB_TEMPORARY_FAILURE');
    }
    return 1;
  }
  async claimOccurrence(): Promise<ClaimedOccurrence | null> {
    const value = this.occurrence;
    this.occurrence = null;
    return value;
  }
  async completeOccurrence(_lease: Lease, id: string, ok: boolean): Promise<boolean> {
    this.completedOccurrences.push({ id, ok });
    return true;
  }
  async claimCommand(): Promise<ClaimedCommand | null> {
    const value = this.command;
    this.command = null;
    return value;
  }
  async recordCommandEffect(): Promise<string> {
    return 'effect';
  }
  async enqueue(_lease: Lease, input: EnqueueInput): Promise<string> {
    this.enqueues.push(input);
    return `q-${this.enqueues.length}`;
  }
  async completeCommand(
    _lease: Lease,
    id: string,
    ok: boolean,
    _result?: Record<string, unknown>,
    errorCode?: string,
  ): Promise<boolean> {
    this.completedCommands.push({ id, ok, errorCode });
    return true;
  }
  async recordPlayoutStart(): Promise<number> {
    return 1;
  }
  async recordPlayoutEnd(): Promise<boolean> {
    return true;
  }
}

async function privateTick(
  coordinator: RadioCoordinator,
  name: 'tickSchedule' | 'tickCommand' | 'tickAck',
  arg?: Date,
): Promise<void> {
  const target = coordinator as unknown as Record<
    string,
    ((arg?: Date) => Promise<void>) | undefined
  >;
  const tick = target[name];
  assert.ok(tick, `missing coordinator tick: ${name}`);
  await tick.call(coordinator, arg);
}

test('temporary recovery failure is retried and successful fencing token is cached', async () => {
  const engine = new ReliabilityEngine();
  const store = new ReliabilityStore();
  store.recoverFailures = 1;
  const coordinator = new RadioCoordinator(config, engine, store);

  await privateTick(coordinator, 'tickSchedule');
  await privateTick(coordinator, 'tickSchedule');
  await privateTick(coordinator, 'tickSchedule');

  assert.deepEqual(store.recoveryTokens, [7, 7]);
});

test('engine restart or lease rotation performs recovery for the new fencing token exactly once', async () => {
  const engine = new ReliabilityEngine();
  const store = new ReliabilityStore();
  const first = new RadioCoordinator(config, engine, store);
  await privateTick(first, 'tickSchedule');

  engine.activeLease = lease(8);
  const restarted = new RadioCoordinator(config, engine, store);
  await privateTick(restarted, 'tickSchedule');
  await privateTick(restarted, 'tickSchedule');

  assert.deepEqual(store.recoveryTokens, [7, 8]);
});

test('temporary scheduler database failure does not consume the occurrence and the next tick dispatches it', async () => {
  const engine = new ReliabilityEngine();
  const store = new ReliabilityStore();
  store.materializeFailures = 1;
  store.occurrence = {
    id: 'occ-retry',
    schedule_id: 'schedule-1',
    station_id: stationId,
    content_type: 'MEDIA',
    media_id: 'm1',
    playlist_id: null,
    priority: 'NORMAL',
    interrupt_policy: 'FINISH_CURRENT',
    scheduled_for: '2026-09-02T10:00:00Z',
  };
  const coordinator = new RadioCoordinator(config, engine, store);

  await privateTick(coordinator, 'tickSchedule');
  assert.equal(store.enqueues.length, 0);
  assert.equal(store.occurrence?.id, 'occ-retry');

  await privateTick(coordinator, 'tickSchedule');
  assert.equal(store.enqueues.length, 1);
  assert.equal(engine.applied[0]?.mediaId, 'm1');
});

test('missing scheduled media fails the claimed occurrence closed', async () => {
  const engine = new ReliabilityEngine();
  const store = new ReliabilityStore();
  store.occurrence = {
    id: 'occ-missing',
    schedule_id: 'schedule-1',
    station_id: stationId,
    content_type: 'MEDIA',
    media_id: 'missing',
    playlist_id: null,
    priority: 'NORMAL',
    interrupt_policy: 'FINISH_CURRENT',
    scheduled_for: '2026-09-02T10:00:00Z',
  };
  const coordinator = new RadioCoordinator(config, engine, store);

  await privateTick(coordinator, 'tickSchedule');

  assert.deepEqual(store.completedOccurrences, [{ id: 'occ-missing', ok: false }]);
  assert.equal(engine.applied.length, 0);
});

test('missing command media marks the claimed command failed instead of stranding PROCESSING', async () => {
  const engine = new ReliabilityEngine();
  const store = new ReliabilityStore();
  store.command = {
    id: 'cmd-missing',
    station_id: stationId,
    command_type: 'PLAY_NOW',
    payload: { media_id: 'missing', interrupt: true },
    priority: 'HIGH',
    created_at: '2026-09-02T10:00:00Z',
  };
  const coordinator = new RadioCoordinator(config, engine, store);

  await privateTick(coordinator, 'tickCommand');

  assert.deepEqual(store.completedCommands, [
    { id: 'cmd-missing', ok: false, errorCode: 'COMMAND_RESOLVE_FAILED' },
  ]);
  assert.equal(store.enqueues.length, 0);
});

test('coordinator performs no database mutation without an active lease', async () => {
  const engine = new ReliabilityEngine();
  engine.activeLease = null;
  const store = new ReliabilityStore();
  store.command = {
    id: 'cmd-no-lease',
    station_id: stationId,
    command_type: 'SKIP',
    payload: {},
    priority: 'NORMAL',
    created_at: '2026-09-02T10:00:00Z',
  };
  const coordinator = new RadioCoordinator(config, engine, store);

  await privateTick(coordinator, 'tickSchedule');
  await privateTick(coordinator, 'tickCommand');
  await privateTick(coordinator, 'tickAck');

  assert.deepEqual(store.recoveryTokens, []);
  assert.equal(store.command?.id, 'cmd-no-lease');
  assert.equal(store.enqueues.length, 0);
});
