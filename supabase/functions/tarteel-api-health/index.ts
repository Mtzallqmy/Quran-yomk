import { fetchJsonResponse } from '../_shared/http.ts';

function playable(value: unknown): boolean {
  try { const url = new URL(String(value)); return url.protocol === 'https:' && !!url.hostname && !url.username && !url.password; }
  catch { return false; }
}

export async function apiHealth(_request: Request, env: (name: string) => string | undefined): Promise<Response> {
  const id = crypto.randomUUID();
  const headers = { 'cache-control': 'no-store', 'x-request-id': id };
  try {
    const base = env('SUPABASE_URL')?.replace(/\/$/, '');
    const keys = JSON.parse(env('SUPABASE_PUBLISHABLE_KEYS') ?? '{}');
    const key = Object.values(keys)[0] ?? env('SUPABASE_ANON_KEY');
    if (!base || typeof key !== 'string' || !key) throw new Error();
    const get = async (path: string) => {
      const response = await fetchJsonResponse(`${base}/functions/v1/tarteel-api/${path}`, {
        headers: { apikey: key, 'x-request-id': id },
      }, { timeoutMs: 2000, maxBytes: 256 * 1024 });
      return { status: response.status, body: response.ok ? await response.json() : null };
    };
    const [stations, reciters] = await Promise.all([get('stations?limit=50'), get('reciters?limit=5')]);
    const stationRows = Array.isArray(stations.body?.data) ? stations.body.data : [];
    const reciterRows = Array.isArray(reciters.body?.data) ? reciters.body.data : [];
    const first = reciterRows[0];
    const tracks = typeof first?.id === 'string' && /^[0-9a-f-]{36}$/i.test(first.id)
      ? await get(`reciters/${encodeURIComponent(first.id)}/surahs`) : { status: 0, body: null };
    const trackRows = Array.isArray(tracks.body?.data) ? tracks.body.data : [];
    const playableStations = stationRows.filter((row: { playback_url?: unknown }) => playable(row?.playback_url)).length;
    const playableTracks = trackRows.filter((row: { track?: { playback_url?: unknown } }) => playable(row?.track?.playback_url)).length;
    const ok = stations.status === 200 && reciters.status === 200 && tracks.status === 200 && playableStations > 0 && playableTracks > 0;
    if (!ok) console.error(JSON.stringify({ event: 'API_HEALTH_NOT_READY', request_id: id }));
    return Response.json({ ok, request_id: id, stations_status: stations.status, stations: stationRows.length, playable_stations: playableStations,
      reciters_status: reciters.status, reciters: reciterRows.length, tracks_status: tracks.status, tracks: trackRows.length, playable_tracks: playableTracks }, { status: ok ? 200 : 503, headers });
  } catch {
    console.error(JSON.stringify({ event: 'API_HEALTH_FAILED', request_id: id }));
    return Response.json({ ok: false, error: { code: 'DEPENDENCY_UNAVAILABLE', request_id: id } }, { status: 503, headers });
  }
}

if (typeof Deno !== 'undefined') Deno.serve(request => apiHealth(request, name => Deno.env.get(name)));
