import { createHash, randomUUID } from 'node:crypto';
import type { Config } from './config.js';
import { commandEffect, type ContentResolver, type RadioCommand } from './commands.js';
import type { ClaimedCommand, ClaimedOccurrence, EnqueueInput, SupabaseAutomationStore } from './automation-store.js';
import type { EngineSnapshot, Lease, Track } from './types.js';
import type { RadioEngine } from './engine.js';
import { Logger } from './logger.js';

export type AutomationStore = Pick<
  SupabaseAutomationStore,
  | 'recover'
  | 'materialize'
  | 'claimOccurrence'
  | 'completeOccurrence'
  | 'claimCommand'
  | 'recordCommandEffect'
  | 'enqueue'
  | 'completeCommand'
  | 'recordPlayoutStart'
  | 'recordPlayoutEnd'
>;
export type CoordinatorEngine = Pick<
  RadioEngine,
  | 'activeLease'
  | 'snapshot'
  | 'resolveMediaTrack'
  | 'resolvePlaylistTracks'
  | 'applyAutomationTracks'
  | 'skipCurrent'
  | 'clearAutomation'
  | 'setAutomationMode'
>;

type ActivePlayout = { playoutId: string; track: Track; startedAt: string };
type PendingCommand = { id: string; effectType: string; payloadHash: string; queueEntryIds: string[] };

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
function hash(value: unknown): string {
  return createHash('sha256').update(JSON.stringify(value)).digest('hex');
}
function payloadObject(value: unknown): Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}
function validTimeline(snapshot: EngineSnapshot): boolean {
  if (!snapshot.currentStartedAt || !snapshot.expectedEndAt) return true;
  const start = Date.parse(snapshot.currentStartedAt);
  const end = Date.parse(snapshot.expectedEndAt);
  return Number.isFinite(start) && Number.isFinite(end) && end >= start;
}

export class RadioCoordinator {
  private scheduleTimer?: NodeJS.Timeout;
  private commandTimer?: NodeJS.Timeout;
  private ackTimer?: NodeJS.Timeout;
  private schedulerRunning = false;
  private commandRunning = false;
  private ackRunning = false;
  private recoveredToken: number | null = null;
  private lastAck = 0;
  private activePlayout: ActivePlayout | null = null;
  private pendingPlayoutId: string | null = null;
  private interruptionReason: string | null = null;
  private stopAfterCurrent = false;
  private occurrenceOutstanding = new Map<string, number>();
  private pendingCommands = new Map<string, PendingCommand>();

  constructor(
    private readonly config: Config,
    private readonly engine: CoordinatorEngine,
    private readonly store: AutomationStore,
    private readonly logger = new Logger(),
  ) {}

  start(): void {
    this.lastAck = this.engine.snapshot.playoutAckCount;
    this.scheduleTimer = setInterval(
      () => void this.tickSchedule(),
      this.config.schedulerPollSeconds * 1000,
    );
    this.scheduleTimer.unref();
    this.commandTimer = setInterval(
      () => void this.tickCommand(),
      this.config.commandPollSeconds * 1000,
    );
    this.commandTimer.unref();
    this.ackTimer = setInterval(() => void this.tickAck(), 200);
    this.ackTimer.unref();
    void this.tickRecovery();
    void this.tickSchedule();
    void this.tickCommand();
    void this.tickAck();
  }

  async stop(): Promise<void> {
    if (this.scheduleTimer) clearInterval(this.scheduleTimer);
    if (this.commandTimer) clearInterval(this.commandTimer);
    if (this.ackTimer) clearInterval(this.ackTimer);
    this.scheduleTimer = undefined;
    this.commandTimer = undefined;
    this.ackTimer = undefined;
    const lease = this.engine.activeLease;
    if (lease && this.activePlayout) {
      await this.finishActive(lease, new Date().toISOString(), false, 'ENGINE_STOP').catch((error) =>
        this.logger.error('PLAYOUT_END_FAILED', error),
      );
    }
  }

  private lease(): Lease | null {
    return this.engine.activeLease;
  }

  private async tickRecovery(): Promise<void> {
    const lease = this.lease();
    if (!lease || this.recoveredToken === lease.fencingToken) return;
    try {
      const result = await this.store.recover(lease);
      this.recoveredToken = lease.fencingToken;
      this.logger.info('AUTOMATION_RECOVERED', {
        station_id: lease.stationId,
        fencing_token: lease.fencingToken,
        ...result,
      });
    } catch (error) {
      this.logger.error('AUTOMATION_RECOVERY_FAILED', error);
    }
  }

  private resolver(): ContentResolver {
    return {
      resolveMedia: async (id) => {
        const track = this.engine.resolveMediaTrack(id);
        return {
          mediaId: id,
          title: track.title,
          path: track.path,
          durationSeconds: track.durationSeconds,
        };
      },
      resolvePlaylist: async (id) =>
        this.engine.resolvePlaylistTracks(id).map((track) => {
          if (!track.mediaId) throw new Error('PLAYLIST_MEDIA_ID_MISSING');
          return {
            mediaId: track.mediaId,
            title: track.title,
            path: track.path,
            durationSeconds: track.durationSeconds,
          };
        }),
    };
  }

  private async tickSchedule(now = new Date()): Promise<void> {
    if (this.schedulerRunning) return;
    const lease = this.lease();
    if (!lease) return;
    this.schedulerRunning = true;
    try {
      await this.tickRecovery();
      const materialized = await this.store.materialize(
        lease.stationId,
        new Date(now.getTime() - this.config.missedGraceSeconds * 1000),
        new Date(now.getTime() + this.config.queueLookaheadSeconds * 1000),
      );
      const occurrence = await this.store.claimOccurrence(
        lease,
        this.config.missedGraceSeconds,
        now,
      );
      if (!occurrence) {
        this.logger.info('SCHEDULER_TICK', { materialized, occurrence_id: null });
        return;
      }
      try {
        const tracks = await this.dispatchOccurrence(lease, occurrence);
        this.occurrenceOutstanding.set(occurrence.id, tracks.length);
        await this.engine.applyAutomationTracks(
          tracks,
          occurrence.interrupt_policy === 'INTERRUPT',
        );
        if (occurrence.interrupt_policy === 'INTERRUPT') {
          this.interruptionReason = 'SCHEDULE_INTERRUPT';
        }
        await this.engine.setAutomationMode('SCHEDULED');
        this.logger.info('SCHEDULE_DISPATCHED', {
          occurrence_id: occurrence.id,
          queue_entries: tracks.map((track) => track.queueEntryId),
          materialized,
        });
      } catch (error) {
        await this.store
          .completeOccurrence(
            lease,
            occurrence.id,
            false,
            { phase: 'dispatch' },
            'SCHEDULE_DISPATCH_FAILED',
            errorMessage(error),
          )
          .catch(() => false);
        this.logger.error('SCHEDULE_DISPATCH_FAILED', error);
      }
    } catch (error) {
      this.logger.error('SCHEDULER_FAILED', error);
    } finally {
      this.schedulerRunning = false;
    }
  }

  private async dispatchOccurrence(
    lease: Lease,
    occurrence: ClaimedOccurrence,
  ): Promise<Track[]> {
    const base =
      occurrence.content_type === 'MEDIA'
        ? occurrence.media_id
          ? [this.engine.resolveMediaTrack(occurrence.media_id)]
          : []
        : occurrence.playlist_id
          ? this.engine.resolvePlaylistTracks(occurrence.playlist_id)
          : [];
    if (!base.length) throw new Error('SCHEDULE_CONTENT_EMPTY');
    const result: Track[] = [];
    for (const [index, track] of base.entries()) {
      if (!track.mediaId) throw new Error('SCHEDULE_MEDIA_ID_MISSING');
      const queueEntryId = await this.store.enqueue(lease, {
        mediaId: track.mediaId,
        source: 'SCHEDULED',
        priority: occurrence.priority,
        interruptPolicy: occurrence.interrupt_policy,
        idempotencyKey: `occurrence:${occurrence.id}:${index}`,
        intendedAt: occurrence.scheduled_for,
        sequence: index,
        occurrenceId: occurrence.id,
        playlistId: occurrence.playlist_id ?? undefined,
        metadata: { schedule_id: occurrence.schedule_id },
      });
      result.push({
        ...track,
        queueEntryId,
        occurrenceId: occurrence.id,
        playlistId: occurrence.playlist_id,
      });
    }
    return result;
  }

  private async tickCommand(): Promise<void> {
    if (this.commandRunning) return;
    const lease = this.lease();
    if (!lease) return;
    this.commandRunning = true;
    try {
      await this.tickRecovery();
      const claimed = await this.store.claimCommand(lease);
      if (!claimed) return;
      const command: RadioCommand = {
        id: claimed.id,
        stationId: claimed.station_id,
        type: claimed.command_type as RadioCommand['type'],
        priority: claimed.priority,
        payload: claimed.payload,
        createdAt: claimed.created_at,
      };

      let effect: Awaited<ReturnType<typeof commandEffect>>;
      try {
        effect = await commandEffect(command, this.resolver());
      } catch (error) {
        await this.store
          .completeCommand(
            lease,
            claimed.id,
            false,
            { phase: 'resolve', command_type: claimed.command_type },
            'COMMAND_RESOLVE_FAILED',
            errorMessage(error),
          )
          .catch(() => false);
        throw error;
      }

      const effectHash = hash({
        type: effect.kind,
        payload: claimed.payload,
        priority: claimed.priority,
      });
      await this.store.recordCommandEffect(
        lease,
        claimed.id,
        effect.kind,
        effectHash,
        'PREPARED',
        { command_type: claimed.command_type },
      );
      try {
        if (effect.kind === 'ENQUEUE') {
          const playlistId =
            typeof payloadObject(claimed.payload).playlist_id === 'string'
              ? String(payloadObject(claimed.payload).playlist_id)
              : undefined;
          const tracks: Track[] = [];
          for (const [index, item] of effect.items.entries()) {
            const input: EnqueueInput = {
              mediaId: item.mediaId,
              source: item.source,
              priority: item.priority,
              interruptPolicy: item.interruptPolicy,
              idempotencyKey: `command:${claimed.id}:${index}`,
              intendedAt: item.intendedAt,
              sequence: item.sequence,
              commandId: claimed.id,
              playlistId,
              metadata: { effect_hash: effectHash },
            };
            const queueEntryId = await this.store.enqueue(lease, input);
            tracks.push({
              mediaId: item.mediaId,
              title: item.title,
              path: item.path,
              durationSeconds: item.durationSeconds,
              queueEntryId,
              commandId: claimed.id,
              playlistId,
            });
          }
          const interrupt = effect.items.some(
            (item) => item.interruptPolicy === 'INTERRUPT',
          );
          await this.engine.applyAutomationTracks(tracks, interrupt);
          if (interrupt) this.interruptionReason = 'COMMAND_INTERRUPT';
          await this.engine.setAutomationMode('MANUAL');
          await this.store.recordCommandEffect(
            lease,
            claimed.id,
            effect.kind,
            effectHash,
            'DISPATCHED',
            { queue_entry_ids: tracks.map((track) => track.queueEntryId) },
          );
          this.pendingCommands.set(claimed.id, {
            id: claimed.id,
            effectType: effect.kind,
            payloadHash: effectHash,
            queueEntryIds: tracks.map((track) => track.queueEntryId!).filter(Boolean),
          });
          return;
        }
        if (effect.kind === 'SKIP') {
          this.interruptionReason = 'SKIP';
          await this.engine.skipCurrent();
        } else if (effect.kind === 'STOP_AFTER_CURRENT') {
          this.stopAfterCurrent = true;
          await this.engine.clearAutomation();
        } else if (effect.kind === 'RESUME_AUTO') {
          this.stopAfterCurrent = false;
          await this.engine.clearAutomation();
          await this.engine.setAutomationMode('AUTO');
        }
        await this.store.recordCommandEffect(
          lease,
          claimed.id,
          effect.kind,
          effectHash,
          'ACKED',
          { control_ack: true },
        );
        await this.store.completeCommand(lease, claimed.id, true, { effect: effect.kind });
      } catch (error) {
        await this.store
          .recordCommandEffect(lease, claimed.id, effect.kind, effectHash, 'FAILED', {
            error_code: 'COMMAND_DISPATCH_FAILED',
          })
          .catch(() => null);
        await this.store
          .completeCommand(
            lease,
            claimed.id,
            false,
            { effect: effect.kind },
            'COMMAND_DISPATCH_FAILED',
            errorMessage(error),
          )
          .catch(() => false);
        throw error;
      }
    } catch (error) {
      this.logger.error('COMMAND_PROCESSING_FAILED', error);
    } finally {
      this.commandRunning = false;
    }
  }

  private async tickAck(): Promise<void> {
    if (this.ackRunning) return;
    const lease = this.lease();
    if (!lease) return;
    const snapshot = this.engine.snapshot;
    if (snapshot.playoutAckCount <= this.lastAck) return;
    this.ackRunning = true;
    try {
      if (!validTimeline(snapshot)) throw new Error('PLAYOUT_TIMELINE_INVALID');
      const startedAt = snapshot.currentStartedAt ?? new Date().toISOString();
      if (
        this.activePlayout &&
        this.activePlayout.track.queueEntryId !== snapshot.current?.queueEntryId
      ) {
        await this.finishActive(
          lease,
          startedAt,
          this.interruptionReason === null,
          this.interruptionReason ?? undefined,
        );
      }
      const current = snapshot.current;
      if (
        current?.queueEntryId &&
        (!this.activePlayout || this.activePlayout.track.queueEntryId !== current.queueEntryId)
      ) {
        this.pendingPlayoutId ??= randomUUID();
        await this.store.recordPlayoutStart(
          lease,
          current.queueEntryId,
          this.pendingPlayoutId,
          startedAt,
        );
        this.activePlayout = {
          playoutId: this.pendingPlayoutId,
          track: { ...current },
          startedAt,
        };
        this.pendingPlayoutId = null;
        if (current.commandId) {
          const pending = this.pendingCommands.get(current.commandId);
          if (pending) {
            await this.store.recordCommandEffect(
              lease,
              pending.id,
              pending.effectType,
              pending.payloadHash,
              'ACKED',
              {
                playout_id: this.activePlayout.playoutId,
                queue_entry_id: current.queueEntryId,
              },
            );
            await this.store.completeCommand(lease, pending.id, true, {
              effect: pending.effectType,
              playout_id: this.activePlayout.playoutId,
            });
            this.pendingCommands.delete(pending.id);
          }
        }
      }
      if (
        this.stopAfterCurrent &&
        (!current?.queueEntryId || this.interruptionReason === null)
      ) {
        this.stopAfterCurrent = false;
        await this.engine.setAutomationMode('AUTO');
      }
      this.interruptionReason = null;
      this.lastAck = snapshot.playoutAckCount;
    } catch (error) {
      this.logger.error('PLAYOUT_ACK_FAILED', error);
    } finally {
      this.ackRunning = false;
    }
  }

  private async finishActive(
    lease: Lease,
    endedAt: string,
    completedNaturally: boolean,
    reason?: string,
  ): Promise<void> {
    const active = this.activePlayout;
    if (!active) return;
    await this.store.recordPlayoutEnd(
      lease,
      active.playoutId,
      endedAt,
      completedNaturally,
      reason,
    );
    this.activePlayout = null;
    const occurrenceId = active.track.occurrenceId;
    if (!occurrenceId) return;
    const remaining = Math.max(
      0,
      (this.occurrenceOutstanding.get(occurrenceId) ?? 1) - 1,
    );
    if (!completedNaturally) {
      this.occurrenceOutstanding.delete(occurrenceId);
      await this.store.completeOccurrence(
        lease,
        occurrenceId,
        false,
        { playout_id: active.playoutId },
        'PLAYOUT_INTERRUPTED',
        reason ?? 'INTERRUPTED',
      );
      return;
    }
    if (remaining === 0) {
      this.occurrenceOutstanding.delete(occurrenceId);
      await this.store.completeOccurrence(lease, occurrenceId, true, {
        playout_id: active.playoutId,
      });
    } else {
      this.occurrenceOutstanding.set(occurrenceId, remaining);
    }
  }
}
