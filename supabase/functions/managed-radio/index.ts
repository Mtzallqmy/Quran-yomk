import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { probeTrustedStream as probeStream } from "../_shared/stream-probe.ts";

type Json = null | boolean | number | string | Json[] | { [key: string]: Json };
type Obj = Record<string, any>;

const SUPABASE_URL = (Deno.env.get('SUPABASE_URL') ?? '').replace(/\/$/, '');
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_SECRET_KEY') ?? '';
const RADIO_BASE = 'https://studio.radio.co/api/v1';
const RADIO_PUBLIC = 'https://public.radio.co/api/v2';
const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, apikey, content-type, x-request-id',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'content-type': 'application/json; charset=utf-8',
};

class HttpError extends Error {
  status: number;
  code: string;
  details?: Json;
  constructor(status: number, code: string, message: string, details?: Json) {
    super(message);
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

function reply(data: unknown, status = 200, headers: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, ...Object.fromEntries(new Headers(headers)) },
  });
}

function fail(requestId: string, error: unknown) {
  const e = error instanceof HttpError
    ? error
    : new HttpError(
        500,
        'INTERNAL_ERROR',
        error instanceof Error ? error.message : String(error),
      );
  console.error(JSON.stringify({
    event: 'MANAGED_RADIO_ERROR',
    request_id: requestId,
    status: e.status,
    code: e.code,
    message: e.message,
  }));
  return reply(
    {
      error: {
        code: e.code,
        message: e.message,
        request_id: requestId,
        details: e.details ?? null,
      },
    },
    e.status,
    { 'x-request-id': requestId, 'cache-control': 'no-store' },
  );
}

async function parse(response: Response): Promise<any> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function uuid(value: string | null) {
  return !!value && /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(value);
}

function safeUrl(value: unknown) {
  if (typeof value !== 'string') return null;
  try {
    const u = new URL(value);
    return u.protocol === 'https:' ? u.toString() : null;
  } catch {
    return null;
  }
}

function bearer(req: Request) {
  const raw = req.headers.get('authorization') ?? '';
  const match = /^Bearer\s+(.+)$/i.exec(raw);
  if (!match) {
    throw new HttpError(
      401,
      'AUTH_REQUIRED',
      'Administrator authentication is required',
    );
  }
  return match[1];
}

async function dataApi(
  schema: 'app' | 'public',
  resource: string,
  init: RequestInit = {},
) {
  if (!SUPABASE_URL || !SERVICE_KEY) {
    throw new HttpError(
      503,
      'SERVER_NOT_CONFIGURED',
      'Supabase service runtime is not configured',
    );
  }
  const headers = new Headers(init.headers);
  headers.set('apikey', SERVICE_KEY);
  headers.set('accept-profile', schema);
  headers.set('content-profile', schema);
  if (init.body && !headers.has('content-type')) {
    headers.set('content-type', 'application/json');
  }
  if (!headers.has('prefer')) headers.set('prefer', 'return=representation');
  const response = await fetch(`${SUPABASE_URL}/rest/v1/${resource}`, {
    ...init,
    headers,
    cache: 'no-store',
  });
  const body = await parse(response);
  if (!response.ok) {
    throw new HttpError(
      response.status >= 500 ? 502 : response.status,
      'DATABASE_ERROR',
      typeof body?.message === 'string'
        ? body.message
        : `Data API ${response.status}`,
    );
  }
  return body;
}

async function rpc(fn: string, args: Obj) {
  return await dataApi('app', `rpc/${fn}`, {
    method: 'POST',
    body: JSON.stringify(args),
  });
}

async function currentUser(token: string) {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: {
      apikey: SERVICE_KEY,
      authorization: `Bearer ${token}`,
    },
    cache: 'no-store',
  });
  const body = await parse(response);
  if (!response.ok || !body?.id) {
    throw new HttpError(
      401,
      'AUTH_REQUIRED',
      'Administrator session is invalid',
    );
  }
  return body as { id: string; email?: string };
}

async function requirePermission(token: string, permission: string) {
  const user = await currentUser(token);
  const allowed = await rpc('managed_radio_authorized', {
    p_user_id: user.id,
    p_permission: permission,
  });
  const value = Array.isArray(allowed) ? allowed[0] : allowed;
  if (value !== true) {
    throw new HttpError(
      403,
      'FORBIDDEN',
      `Permission ${permission} is required`,
    );
  }
  return user;
}

async function sha256(value: unknown) {
  const bytes = new TextEncoder().encode(JSON.stringify(value));
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', bytes));
  return [...digest]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function arrayAt(value: any, key: string): any[] {
  if (Array.isArray(value)) return value;
  if (Array.isArray(value?.[key])) return value[key];
  if (Array.isArray(value?.data?.[key])) return value.data[key];
  if (Array.isArray(value?.data)) return value.data;
  return [];
}

function firstAt(value: any, key: string) {
  return arrayAt(value, key)[0] ?? value?.data ?? value ?? null;
}

class RadioCoService {
  private accessToken: string | null = null;
  private tokenExpiresAt = 0;
  readonly clientId = Deno.env.get('RADIO_CO_CLIENT_ID') ?? '';
  readonly clientSecret = Deno.env.get('RADIO_CO_CLIENT_SECRET') ?? '';
  readonly refreshToken = Deno.env.get('RADIO_CO_REFRESH_TOKEN') ?? '';
  readonly staticAccessToken = Deno.env.get('RADIO_CO_ACCESS_TOKEN') ?? '';

  get writeConfigured() {
    return !!this.staticAccessToken ||
      (!!this.clientId && !!this.clientSecret && !!this.refreshToken);
  }

  async publicGet(stationId: string, suffix = '') {
    const response = await fetch(
      `${RADIO_PUBLIC}/${encodeURIComponent(stationId)}${suffix}`,
      {
        headers: { accept: 'application/json' },
        cache: 'no-store',
      },
    );
    const body = await parse(response);
    if (!response.ok) {
      throw new HttpError(
        502,
        'RADIOCO_PUBLIC_API_ERROR',
        `Radio.co Public API returned ${response.status}`,
      );
    }
    return body?.data ?? body;
  }

  private async token() {
    if (this.staticAccessToken) return this.staticAccessToken;
    if (this.accessToken && Date.now() < this.tokenExpiresAt - 60_000) {
      return this.accessToken;
    }
    if (!this.clientId || !this.clientSecret || !this.refreshToken) {
      throw new HttpError(
        409,
        'RADIOCO_OAUTH_NOT_CONFIGURED',
        'Radio.co Studio API OAuth credentials are not configured',
      );
    }
    const response = await fetch(`${RADIO_BASE}/oauth/v2/token`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        accept: 'application/json',
      },
      body: JSON.stringify({
        grant_type: 'refresh_token',
        refresh_token: this.refreshToken,
        client_id: this.clientId,
        client_secret: this.clientSecret,
      }),
      cache: 'no-store',
    });
    const body = await parse(response);
    if (!response.ok || !body?.access_token) {
      throw new HttpError(
        502,
        'RADIOCO_OAUTH_FAILED',
        'Radio.co OAuth token refresh failed',
      );
    }
    this.accessToken = String(body.access_token);
    this.tokenExpiresAt = Date.now() + Number(body.expires_in ?? 3600) * 1000;
    return this.accessToken;
  }

  async studio(path: string, init: RequestInit = {}) {
    const token = await this.token();
    const headers = new Headers(init.headers);
    headers.set('authorization', `Bearer ${token}`);
    headers.set('accept', 'application/json');
    if (init.body && !headers.has('content-type')) {
      headers.set('content-type', 'application/json');
    }
    const response = await fetch(`${RADIO_BASE}${path}`, {
      ...init,
      headers,
      cache: 'no-store',
    });
    const body = await parse(response);
    if (!response.ok) {
      const code = response.status === 409
        ? 'RADIOCO_SCHEDULE_COLLISION'
        : 'RADIOCO_STUDIO_API_ERROR';
      throw new HttpError(
        response.status === 409 ? 409 : 502,
        code,
        `Radio.co Studio API returned ${response.status}`,
        typeof body === 'object' ? body : null,
      );
    }
    return body;
  }

  listRelays(stationId: string) {
    return this.studio(`/stations/${encodeURIComponent(stationId)}/relays`);
  }

  createRelay(stationId: string, name: string, url: string) {
    return this.studio(`/stations/${encodeURIComponent(stationId)}/relays`, {
      method: 'POST',
      body: JSON.stringify({ name, url }),
    });
  }

  updateRelay(stationId: string, relayId: string, patch: Obj) {
    return this.studio(
      `/stations/${encodeURIComponent(stationId)}/relays/${encodeURIComponent(relayId)}`,
      {
        method: 'PATCH',
        body: JSON.stringify(patch),
      },
    );
  }

  listSchedule(stationId: string, start: string, end: string) {
    return this.studio(
      `/stations/${encodeURIComponent(stationId)}/schedule?start=${encodeURIComponent(start)}&end=${encodeURIComponent(end)}`,
    );
  }

  createEvent(stationId: string, body: Obj) {
    return this.studio(`/stations/${encodeURIComponent(stationId)}/schedule`, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  updateEvent(stationId: string, eventId: string, body: Obj) {
    return this.studio(
      `/stations/${encodeURIComponent(stationId)}/schedule/${encodeURIComponent(eventId)}`,
      {
        method: 'PATCH',
        body: JSON.stringify(body),
      },
    );
  }

  deleteEvent(stationId: string, eventId: string) {
    return this.studio(
      `/stations/${encodeURIComponent(stationId)}/schedule/${encodeURIComponent(eventId)}`,
      { method: 'DELETE' },
    );
  }
}

interface ManagedRadioService {
  refreshStatus(slug: string): Promise<any>;
  sync(slug: string, requestedBy: string): Promise<any>;
  testRelay(slug: string): Promise<any>;
  failover(slug: string, requestedBy: string, force?: boolean): Promise<any>;
}

function localParts(date: Date, timeZone: string) {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const map: Obj = {};
  for (const part of parts) {
    if (part.type !== 'literal') map[part.type] = Number(part.value);
  }
  return {
    year: map.year,
    month: map.month,
    day: map.day,
    hour: map.hour,
    minute: map.minute,
    second: map.second,
  };
}

function zonedToUtc(
  year: number,
  month: number,
  day: number,
  hour: number,
  minute: number,
  second: number,
  timeZone: string,
) {
  const desired = Date.UTC(year, month - 1, day, hour, minute, second);
  let guess = new Date(desired);
  for (let i = 0; i < 2; i++) {
    const parts = localParts(guess, timeZone);
    const represented = Date.UTC(
      parts.year,
      parts.month - 1,
      parts.day,
      parts.hour,
      parts.minute,
      parts.second,
    );
    guess = new Date(guess.getTime() + (desired - represented));
  }
  return guess;
}

function addDate(year: number, month: number, day: number, days: number) {
  const value = new Date(Date.UTC(year, month - 1, day + days));
  return {
    year: value.getUTCFullYear(),
    month: value.getUTCMonth() + 1,
    day: value.getUTCDate(),
  };
}

function parseTime(value: string) {
  const [h, m, s] = value.split(':').map(Number);
  return { h, m, s: s || 0 };
}

function nextOccurrence(
  days: number[],
  startTime: string,
  endTime: string,
  timeZone: string,
  now = new Date(),
) {
  const local = localParts(now, timeZone);
  const startClock = parseTime(startTime);
  const endClock = parseTime(endTime);
  for (let offset = 0; offset < 8; offset++) {
    const date = addDate(local.year, local.month, local.day, offset);
    const dow = new Date(
      Date.UTC(date.year, date.month - 1, date.day),
    ).getUTCDay();
    if (!days.includes(dow)) continue;
    const start = zonedToUtc(
      date.year,
      date.month,
      date.day,
      startClock.h,
      startClock.m,
      startClock.s,
      timeZone,
    );
    if (start.getTime() < now.getTime() - 30_000) continue;
    const crosses = endClock.h < startClock.h ||
      (endClock.h === startClock.h &&
        (endClock.m < startClock.m ||
          (endClock.m === startClock.m && endClock.s <= startClock.s)));
    const endDate = crosses
      ? addDate(date.year, date.month, date.day, 1)
      : date;
    const end = zonedToUtc(
      endDate.year,
      endDate.month,
      endDate.day,
      endClock.h,
      endClock.m,
      endClock.s,
      timeZone,
    );
    return { start, end };
  }
  throw new HttpError(
    422,
    'SCHEDULE_OCCURRENCE_NOT_FOUND',
    'Could not derive the next schedule occurrence',
  );
}

function repeatPattern(days: number[]) {
  return days.reduce((mask, day) => mask | (1 << day), 0);
}

function dateOnly(date: Date) {
  return date.toISOString().slice(0, 10);
}

function relayName(program: string, role: 'Primary' | 'Secondary') {
  return `Tarteel / ${program.slice(0, 80)} / ${role}`;
}

function asNumberId(value: unknown, field: string) {
  const n = Number(value);
  if (!Number.isInteger(n) || n <= 0) {
    throw new HttpError(
      422,
      'INVALID_PROVIDER_ID',
      `${field} must be a positive Radio.co ID`,
    );
  }
  return n;
}

class TarteelManagedRadioService implements ManagedRadioService {
  constructor(private radio = new RadioCoService()) {}

  private async manifest(slug: string) {
    const raw = await rpc('managed_radio_sync_manifest', { p_slug: slug });
    const value = Array.isArray(raw) ? raw[0] : raw;
    if (!value?.configured || !value?.channel) {
      throw new HttpError(
        404,
        'MANAGED_RADIO_NOT_CONFIGURED',
        'Managed radio channel is not configured',
      );
    }
    return value;
  }

  private async updateConfig(channelId: string, patch: Obj) {
    const rows = await dataApi(
      'app',
      `managed_radio_configs?channel_id=eq.${encodeURIComponent(channelId)}`,
      { method: 'PATCH', body: JSON.stringify(patch) },
    );
    return Array.isArray(rows) ? rows[0] : rows;
  }

  private async beginRun(
    channelId: string,
    operation: string,
    summary: Obj = {},
  ) {
    const rows = await dataApi('app', 'managed_radio_sync_runs', {
      method: 'POST',
      body: JSON.stringify({
        channel_id: channelId,
        provider: 'RADIO_CO',
        operation,
        status: 'RUNNING',
        summary,
      }),
    });
    return (Array.isArray(rows) ? rows[0] : rows) as Obj;
  }

  private async finishRun(
    id: string,
    status: 'SUCCESS' | 'FAILED' | 'BLOCKED',
    summary: Obj,
    errorCode?: string,
    errorMessage?: string,
  ) {
    await dataApi('app', `managed_radio_sync_runs?id=eq.${encodeURIComponent(id)}`, {
      method: 'PATCH',
      body: JSON.stringify({
        status,
        summary,
        error_code: errorCode ?? null,
        error_message: errorMessage ?? null,
        finished_at: new Date().toISOString(),
      }),
    });
  }

  private async bind(scheduleId: string, patch: Obj) {
    const body = { schedule_id: scheduleId, provider: 'RADIO_CO', ...patch };
    const rows = await dataApi('app', 'managed_radio_event_bindings', {
      method: 'POST',
      headers: { prefer: 'resolution=merge-duplicates,return=representation' },
      body: JSON.stringify(body),
    });
    return Array.isArray(rows) ? rows[0] : rows;
  }

  async refreshStatus(slug: string) {
    const manifest = await this.manifest(slug);
    const stationId = manifest.channel.station_external_id;
    if (!stationId) {
      throw new HttpError(
        409,
        'RADIOCO_STATION_NOT_CONFIGURED',
        'Radio.co station ID is missing',
      );
    }
    const [station, status, source, current, next] = await Promise.all([
      this.radio.publicGet(stationId),
      this.radio.publicGet(stationId, '/status'),
      this.radio.publicGet(stationId, '/source'),
      this.radio.publicGet(stationId, '/track/current'),
      this.radio.publicGet(stationId, '/track/next'),
    ]);
    await this.updateConfig(manifest.channel.id, {
      provider_status: status?.status ?? null,
      provider_source: source ?? {},
      provider_now_playing: {
        current: current ?? {},
        next: next ?? {},
        station: {
          name: station?.name ?? null,
          streaming_links: station?.streaming_links ?? [],
        },
      },
      last_provider_check_at: new Date().toISOString(),
    });
    return {
      provider: 'RADIO_CO',
      station_id: stationId,
      fixed_stream_url: manifest.channel.fixed_stream_url,
      status: status?.status ?? null,
      source,
      now_playing: current,
      next,
      write_api_configured: this.radio.writeConfigured,
    };
  }

  private blockers(manifest: any) {
    const blockers: Obj[] = [];
    if (!manifest.channel.sync_enabled) {
      blockers.push({
        code: 'MANAGED_SYNC_DISABLED',
        message: 'Managed provider schedule sync is disabled',
      });
    }
    if (!this.radio.writeConfigured) {
      blockers.push({
        code: 'RADIOCO_OAUTH_NOT_CONFIGURED',
        message: 'Radio.co Studio API OAuth credentials are required',
      });
    }
    const schedules = (manifest.schedules ?? []).filter(
      (s: any) => s.enabled && s.managed_sync_enabled,
    );
    for (const schedule of schedules) {
      if (!schedule.primary?.relay_eligible) {
        blockers.push({
          code: 'PRIMARY_RELAY_NOT_APPROVED',
          schedule_id: schedule.id,
          message: `${schedule.program_title_ar}: primary source is not approved for managed rebroadcast`,
        });
      }
      if (!schedule.backup_playlist_external_id) {
        blockers.push({
          code: 'BACKUP_PLAYLIST_REQUIRED',
          schedule_id: schedule.id,
          message: `${schedule.program_title_ar}: backup playlist is required`,
        });
      }
      if (schedule.secondary && !schedule.secondary.relay_eligible) {
        blockers.push({
          code: 'SECONDARY_RELAY_NOT_APPROVED',
          schedule_id: schedule.id,
          message: `${schedule.program_title_ar}: secondary source is not approved for managed rebroadcast`,
        });
      }
    }
    return blockers;
  }

  private async ensureRelay(
    stationId: string,
    existing: any[],
    desiredName: string,
    source: any,
    preferredId?: string | null,
  ) {
    const url = safeUrl(source?.stream_url);
    if (!url || !source?.relay_eligible) {
      throw new HttpError(
        422,
        'RELAY_SOURCE_NOT_APPROVED',
        'Relay source is not approved for managed rebroadcast',
      );
    }
    let relay = preferredId
      ? existing.find((r) => String(r.id) === String(preferredId))
      : null;
    relay ??= existing.find((r) => String(r.url) === url) ??
      existing.find((r) => String(r.name) === desiredName);
    if (relay) {
      if (String(relay.url) !== url || String(relay.name) !== desiredName) {
        const updated = firstAt(
          await this.radio.updateRelay(stationId, String(relay.id), {
            name: desiredName,
            url,
          }),
          'relays',
        );
        return { relay: updated, created: false, updated: true };
      }
      return { relay, created: false, updated: false };
    }
    const created = firstAt(
      await this.radio.createRelay(stationId, desiredName, url),
      'relays',
    );
    return { relay: created, created: true, updated: false };
  }

  async sync(slug: string, requestedBy: string) {
    const manifest = await this.manifest(slug);
    const run = await this.beginRun(
      manifest.channel.id,
      'SYNC_SCHEDULE',
      { requested_by: requestedBy },
    );
    const blockers = this.blockers(manifest);
    if (blockers.length) {
      await this.updateConfig(manifest.channel.id, {
        last_sync_at: new Date().toISOString(),
        last_sync_status: 'BLOCKED',
        last_sync_error_code: blockers[0].code,
        last_sync_error_message: blockers[0].message,
      });
      await this.finishRun(
        run.id,
        'BLOCKED',
        { blockers },
        blockers[0].code,
        blockers[0].message,
      );
      throw new HttpError(
        409,
        'MANAGED_RADIO_SYNC_BLOCKED',
        'Managed Radio schedule cannot be synchronized yet',
        blockers,
      );
    }

    const stationId = String(manifest.channel.station_external_id);
    const timezone = String(manifest.channel.timezone || 'Asia/Aden');
    try {
      const today = new Date();
      const scheduleEnd = new Date(today.getTime() + 14 * 86_400_000);
      const [relayRaw, scheduleRaw] = await Promise.all([
        this.radio.listRelays(stationId),
        this.radio.listSchedule(
          stationId,
          dateOnly(today),
          dateOnly(scheduleEnd),
        ),
      ]);
      const relays = arrayAt(relayRaw, 'relays');
      const providerPlaylists = arrayAt(scheduleRaw, 'playlists');
      const playlistIds = new Set(
        providerPlaylists.map((playlist) => String(playlist.id)),
      );
      const summary: Obj = {
        schedules_seen: 0,
        schedules_synced: 0,
        relays_created: 0,
        relays_updated: 0,
        events_created: 0,
        events_updated: 0,
        events_deleted: 0,
      };

      for (const schedule of manifest.schedules ?? []) {
        if (!schedule.enabled || !schedule.managed_sync_enabled) {
          if (schedule.binding?.provider_event_id) {
            await this.radio.deleteEvent(
              stationId,
              String(schedule.binding.provider_event_id),
            );
            summary.events_deleted++;
          }
          await this.bind(schedule.id, {
            provider_event_id: null,
            last_synced_at: new Date().toISOString(),
            last_sync_status: 'SUCCESS',
            last_sync_error_code: null,
            last_sync_error_message: null,
          });
          continue;
        }

        summary.schedules_seen++;
        const backup = String(schedule.backup_playlist_external_id);
        if (playlistIds.size && !playlistIds.has(backup)) {
          throw new HttpError(
            422,
            'BACKUP_PLAYLIST_NOT_FOUND',
            `${schedule.program_title_ar}: Radio.co backup playlist ${backup} does not exist`,
          );
        }

        const primary = await this.ensureRelay(
          stationId,
          relays,
          relayName(schedule.program_title_ar, 'Primary'),
          schedule.primary,
          schedule.binding?.primary_relay_external_id,
        );
        if (primary.created) {
          relays.push(primary.relay);
          summary.relays_created++;
        }
        if (primary.updated) summary.relays_updated++;

        let secondary: any = null;
        if (schedule.secondary) {
          secondary = await this.ensureRelay(
            stationId,
            relays,
            relayName(schedule.program_title_ar, 'Secondary'),
            schedule.secondary,
            schedule.binding?.secondary_relay_external_id,
          );
          if (secondary.created) {
            relays.push(secondary.relay);
            summary.relays_created++;
          }
          if (secondary.updated) summary.relays_updated++;
        }

        const occurrence = nextOccurrence(
          (schedule.days_of_week ?? []).map(Number),
          String(schedule.start_time),
          String(schedule.end_time),
          timezone,
        );
        const eventBody = {
          start: occurrence.start.toISOString(),
          end: occurrence.end.toISOString(),
          overrun: false,
          record: false,
          metadata: 'adaptive',
          relay_id: asNumberId(primary.relay.id, 'relay_id'),
          playlist_id: asNumberId(backup, 'playlist_id'),
          repeat: {
            type: 'weekly',
            pattern: repeatPattern(
              (schedule.days_of_week ?? []).map(Number),
            ),
            frequency: 1,
          },
        };
        const hash = await sha256(eventBody);
        let providerEventId = schedule.binding?.provider_event_id
          ? String(schedule.binding.provider_event_id)
          : null;
        if (!providerEventId) {
          const created = firstAt(
            await this.radio.createEvent(stationId, eventBody),
            'events',
          );
          providerEventId = String(created?.id ?? '');
          if (!providerEventId) {
            throw new HttpError(
              502,
              'RADIOCO_INVALID_RESPONSE',
              'Radio.co did not return the created event ID',
            );
          }
          summary.events_created++;
        } else if (schedule.binding?.provider_payload_hash !== hash) {
          await this.radio.updateEvent(stationId, providerEventId, eventBody);
          summary.events_updated++;
        }

        await this.bind(schedule.id, {
          provider_event_id: providerEventId,
          primary_relay_external_id: String(primary.relay.id),
          secondary_relay_external_id: secondary?.relay?.id == null
            ? null
            : String(secondary.relay.id),
          backup_playlist_external_id: backup,
          provider_payload_hash: hash,
          last_synced_at: new Date().toISOString(),
          last_sync_status: 'SUCCESS',
          last_sync_error_code: null,
          last_sync_error_message: null,
        });
        summary.schedules_synced++;
      }

      await this.updateConfig(manifest.channel.id, {
        last_sync_at: new Date().toISOString(),
        last_sync_status: 'SUCCESS',
        last_sync_error_code: null,
        last_sync_error_message: null,
      });
      await this.finishRun(run.id, 'SUCCESS', summary);
      return {
        ...summary,
        station_id: stationId,
        fixed_stream_url: manifest.channel.fixed_stream_url,
      };
    } catch (error) {
      const e = error instanceof HttpError
        ? error
        : new HttpError(
            500,
            'SYNC_FAILED',
            error instanceof Error ? error.message : String(error),
          );
      await this.updateConfig(manifest.channel.id, {
        last_sync_at: new Date().toISOString(),
        last_sync_status: 'FAILED',
        last_sync_error_code: e.code,
        last_sync_error_message: e.message,
      }).catch(() => {});
      await this.finishRun(
        run.id,
        'FAILED',
        {},
        e.code,
        e.message,
      ).catch(() => {});
      throw e;
    }
  }

  async testRelay(slug: string) {
    const manifest = await this.manifest(slug);
    const results: Obj[] = [];
    for (
      const schedule of (manifest.schedules ?? []).filter(
        (value: any) => value.enabled && value.managed_sync_enabled,
      )
    ) {
      for (const role of ['primary', 'secondary'] as const) {
        const source = schedule[role];
        if (!source) continue;
        const probe = await probeStream(source.stream_url);
        results.push({
          schedule_id: schedule.id,
          program_title_ar: schedule.program_title_ar,
          role,
          station_id: source.id,
          station_name: source.name_ar,
          relay_eligible: source.relay_eligible === true,
          ...probe,
        });
      }
    }
    return {
      provider: 'RADIO_CO',
      write_api_configured: this.radio.writeConfigured,
      results,
    };
  }

  async failover(slug: string, requestedBy: string, force = false) {
    const manifest = await this.manifest(slug);
    const run = await this.beginRun(manifest.channel.id, 'FAILOVER', {
      requested_by: requestedBy,
      force,
    });
    if (!this.radio.writeConfigured) {
      await this.finishRun(
        run.id,
        'BLOCKED',
        {},
        'RADIOCO_OAUTH_NOT_CONFIGURED',
        'Radio.co OAuth is required for provider failover',
      );
      throw new HttpError(
        409,
        'RADIOCO_OAUTH_NOT_CONFIGURED',
        'Radio.co Studio API OAuth credentials are required',
      );
    }

    const now = new Date();
    const timezone = String(manifest.channel.timezone || 'Asia/Aden');
    const local = localParts(now, timezone);
    const localMinutes = local.hour * 60 + local.minute;
    const dow = new Date(
      Date.UTC(local.year, local.month - 1, local.day),
    ).getUTCDay();
    const current = (manifest.schedules ?? []).find((schedule: any) => {
      if (
        !schedule.enabled ||
        !schedule.managed_sync_enabled ||
        !(schedule.days_of_week ?? []).map(Number).includes(dow)
      ) {
        return false;
      }
      const start = parseTime(String(schedule.start_time));
      const end = parseTime(String(schedule.end_time));
      const startMinutes = start.h * 60 + start.m;
      const endMinutes = end.h * 60 + end.m;
      return startMinutes < endMinutes
        ? localMinutes >= startMinutes && localMinutes < endMinutes
        : localMinutes >= startMinutes || localMinutes < endMinutes;
    });
    if (!current) {
      throw new HttpError(
        409,
        'NO_ACTIVE_MANAGED_SCHEDULE',
        'No managed schedule is active now',
      );
    }
    if (
      !current.secondary?.relay_eligible ||
      !current.binding?.secondary_relay_external_id ||
      !current.binding?.provider_event_id
    ) {
      throw new HttpError(
        409,
        'SECONDARY_RELAY_NOT_READY',
        'Current schedule has no synchronized secondary relay',
      );
    }

    const primaryProbe = await probeStream(current.primary?.stream_url);
    if (primaryProbe.ok && !force) {
      const summary = {
        changed: false,
        reason: 'PRIMARY_HEALTHY',
        primary: primaryProbe,
      };
      await this.finishRun(run.id, 'SUCCESS', summary);
      return summary;
    }

    const secondaryProbe = await probeStream(current.secondary.stream_url);
    if (!secondaryProbe.ok) {
      throw new HttpError(
        503,
        'SECONDARY_RELAY_UNAVAILABLE',
        'Secondary relay source is unavailable; Radio.co backup playlist remains the final fallback',
      );
    }
    await this.radio.updateEvent(
      String(manifest.channel.station_external_id),
      String(current.binding.provider_event_id),
      {
        relay_id: asNumberId(
          current.binding.secondary_relay_external_id,
          'secondary_relay_id',
        ),
      },
    );
    const summary = {
      changed: true,
      schedule_id: current.id,
      provider_event_id: current.binding.provider_event_id,
      source: 'SECONDARY',
      primary: primaryProbe,
      secondary: secondaryProbe,
    };
    await this.finishRun(run.id, 'SUCCESS', summary);
    return summary;
  }
}

const service = new TarteelManagedRadioService();

Deno.serve(async (req: Request) => {
  const supplied = req.headers.get('x-request-id');
  const requestId = uuid(supplied) ? supplied! : crypto.randomUUID();
  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }
  try {
    const token = bearer(req);
    const url = new URL(req.url);
    const path = url.pathname
      .replace(/^.*\/managed-radio\/?/, '')
      .replace(/^\/+|\/+$/g, '');
    const body = req.method === 'POST'
      ? await req.json().catch(() => ({})) as Obj
      : {};
    const slug = typeof body.slug === 'string'
      ? body.slug
      : (url.searchParams.get('slug') ?? 'tarteel');
    if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
      throw new HttpError(422, 'VALIDATION_ERROR', 'Invalid channel slug');
    }

    if (
      req.method === 'GET' ||
      path === 'status' ||
      body.action === 'status' ||
      body.action === 'refresh-status' ||
      body.action === 'now-playing'
    ) {
      await requirePermission(token, 'schedules.read');
      const data = await service.refreshStatus(slug);
      return reply(
        { data },
        200,
        { 'x-request-id': requestId, 'cache-control': 'no-store' },
      );
    }

    const user = await requirePermission(token, 'schedules.write');
    if (path === 'sync' || body.action === 'sync') {
      const data = await service.sync(slug, user.id);
      return reply(
        { data },
        200,
        { 'x-request-id': requestId, 'cache-control': 'no-store' },
      );
    }
    if (path === 'test-relay' || body.action === 'test-relay') {
      const data = await service.testRelay(slug);
      return reply(
        { data },
        200,
        { 'x-request-id': requestId, 'cache-control': 'no-store' },
      );
    }
    if (path === 'failover' || body.action === 'failover') {
      const data = await service.failover(slug, user.id, body.force === true);
      return reply(
        { data },
        200,
        { 'x-request-id': requestId, 'cache-control': 'no-store' },
      );
    }
    throw new HttpError(404, 'NOT_FOUND', 'Managed Radio action not found');
  } catch (error) {
    return fail(requestId, error);
  }
});
