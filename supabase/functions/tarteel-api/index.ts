import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "apikey,content-type,x-request-id",
  "access-control-allow-methods": "GET,OPTIONS",
  "content-type": "application/json; charset=utf-8",
};
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");
const publishableMap = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}");
const ALLOWED_KEYS = new Set(Object.values(publishableMap).map(String));
const legacyAnon = Deno.env.get("SUPABASE_ANON_KEY");
if (legacyAnon) ALLOWED_KEYS.add(legacyAnon);

const MP3QURAN_RECITERS = "https://www.mp3quran.net/api/v3/reciters?language=ar";
const EXTERNAL_UUID_PREFIX = "00000000-0000-4001-9000-";
let mp3Cache: { expiresAt: number; rows: Record<string, unknown>[] } | null = null;

function response(data: unknown, status = 200, extra: HeadersInit = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, ...Object.fromEntries(new Headers(extra)) },
  });
}
function fail(status: number, code: string, message: string, requestId: string) {
  return response({ error: { code, message, request_id: requestId } }, status, {
    "x-request-id": requestId,
    "cache-control": "no-store",
  });
}
async function read(r: Response) {
  const text = await r.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return text; }
}
async function rpc(name: string, args: Record<string, unknown>, apiKey: string) {
  const r = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: { apikey: apiKey, "content-type": "application/json", accept: "application/json" },
    body: JSON.stringify(args),
    cache: "no-store",
  });
  const data = await read(r);
  if (!r.ok) {
    const message = typeof data === "object" && data && "message" in data
      ? String((data as Record<string, unknown>).message)
      : `Data API ${r.status}`;
    const error = new Error(message) as Error & { status?: number };
    error.status = r.status;
    throw error;
  }
  return data;
}
function int(value: string | null, fallback: number, min: number, max: number) {
  const n = Number(value ?? fallback);
  return Number.isInteger(n) && n >= min && n <= max ? n : fallback;
}
function asArray(value: unknown): unknown[] { return Array.isArray(value) ? value : []; }
function asObject(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}
function externalUuid(id: number) {
  return `${EXTERNAL_UUID_PREFIX}${String(id).padStart(12, "0")}`;
}
function externalId(uuid: string) {
  const match = uuid.match(/^00000000-0000-4001-9000-(\d{12})$/);
  return match ? Number(match[1]) : null;
}
function surahSet(moshaf: Record<string, unknown>) {
  return new Set(String(moshaf.surah_list ?? "").split(",").map((x) => Number(x.trim())).filter((x) => Number.isInteger(x) && x >= 1 && x <= 114));
}
function bestMoshaf(reciter: Record<string, unknown>, requiredSurah?: number) {
  const rows = asArray(reciter.moshaf).map(asObject).filter((m) => {
    const server = String(m.server ?? "");
    if (!server.startsWith("https://")) return false;
    return requiredSurah == null || surahSet(m).has(requiredSurah);
  });
  rows.sort((a, b) => Number(b.surah_total ?? 0) - Number(a.surah_total ?? 0));
  return rows[0] ?? null;
}
function mapExternalReciter(reciter: Record<string, unknown>, requiredSurah?: number) {
  const id = Number(reciter.id);
  const moshaf = bestMoshaf(reciter, requiredSurah);
  if (!Number.isInteger(id) || id <= 0 || !moshaf) return null;
  return {
    id: externalUuid(id),
    slug: `mp3quran-${id}`,
    name_ar: String(reciter.name ?? `قارئ ${id}`),
    name_en: null,
    image_url: null,
    country: null,
    rewaya: String(moshaf.name ?? "") || null,
    description: "تلاوة خارجية عبر واجهة MP3Quran العامة",
    provider: "mp3quran",
  };
}
async function mp3ReciterRows() {
  if (mp3Cache && mp3Cache.expiresAt > Date.now()) return mp3Cache.rows;
  const r = await fetch(MP3QURAN_RECITERS, {
    headers: { accept: "application/json", "user-agent": "Tarteel-Public-API/1.0" },
  });
  if (!r.ok) throw new Error(`MP3Quran reciters ${r.status}`);
  const body = asObject(await r.json());
  const rows = asArray(body.reciters).map(asObject);
  if (!rows.length) throw new Error("MP3Quran reciter catalog is empty");
  mp3Cache = { rows, expiresAt: Date.now() + 15 * 60 * 1000 };
  return rows;
}
async function externalReciters(search: string | null = null, requiredSurah?: number) {
  const normalized = (search ?? "").trim().toLocaleLowerCase("ar");
  return (await mp3ReciterRows())
    .map((r) => mapExternalReciter(r, requiredSurah))
    .filter((r): r is NonNullable<typeof r> => Boolean(r))
    .filter((r) => !normalized || r.name_ar.toLocaleLowerCase("ar").includes(normalized));
}
async function externalReciterByUuid(uuid: string) {
  const id = externalId(uuid);
  if (id == null) return null;
  const row = (await mp3ReciterRows()).find((r) => Number(r.id) === id);
  return row ? mapExternalReciter(row) : null;
}
async function externalTracks(uuid: string, apiKey: string) {
  const id = externalId(uuid);
  if (id == null) return null;
  const reciter = (await mp3ReciterRows()).find((r) => Number(r.id) === id);
  if (!reciter) return [];
  const moshaf = bestMoshaf(reciter);
  if (!moshaf) return [];
  const base = String(moshaf.server ?? "").replace(/\/?$/, "/");
  const available = surahSet(moshaf);
  const surahs = asArray(await rpc("tarteel_public_surahs", {}, apiKey)).map(asObject);
  return surahs
    .filter((s) => available.has(Number(s.number)))
    .map((s) => {
      const number = Number(s.number);
      return {
        surah: s,
        track: {
          id: `mp3quran-${id}-${number}`,
          media_id: null,
          duration_ms: null,
          quality: "EXTERNAL",
          rewaya: String(moshaf.name ?? "") || "UNKNOWN",
          format: "mp3",
          bitrate_kbps: null,
          playback_url: `${base}${String(number).padStart(3, "0")}.mp3`,
          provider: "mp3quran",
        },
      };
    });
}
async function catalog(params: URLSearchParams, apiKey: string, slug: string | null = null) {
  const page = int(params.get("page"), 1, 1, 100000);
  const limit = int(params.get("limit"), 50, 1, 200);
  const raw = asArray(await rpc("tarteel_public_station_catalog", {
    p_environment: Deno.env.get("TARTEEL_PUBLIC_ENVIRONMENT") ?? "development",
    p_source: params.get("source"),
    p_category: params.get("category"),
    p_provider: params.get("provider"),
    p_search: params.get("search") ?? params.get("q"),
    p_limit: slug ? 1 : limit,
    p_offset: slug ? 0 : (page - 1) * limit,
    p_slug: slug,
  }, apiKey)).map(asObject);
  // The internal development station has no public Icecast endpoint yet. Do not
  // put a dead card in the default public catalog; it remains queryable through
  // source=INTERNAL for diagnostics/admin use.
  const rows = !slug && !params.get("source")
    ? raw.filter((r) => r.station_source !== "INTERNAL" || Boolean(r.playback_url))
    : raw;
  return { rows, page, limit };
}

Deno.serve(async (req: Request) => {
  const supplied = req.headers.get("x-request-id");
  const requestId = supplied && /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(supplied)
    ? supplied
    : crypto.randomUUID();
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") return fail(405, "METHOD_NOT_ALLOWED", "Only public GET endpoints are exposed", requestId);
  const apiKey = req.headers.get("apikey") ?? "";
  if (!apiKey || !ALLOWED_KEYS.has(apiKey)) return fail(401, "INVALID_API_KEY", "A valid Tarteel publishable API key is required", requestId);
  if (!SUPABASE_URL) return fail(503, "SERVER_NOT_CONFIGURED", "Public API runtime is not configured", requestId);

  try {
    const u = new URL(req.url);
    const marker = "/tarteel-api";
    const idx = u.pathname.indexOf(marker);
    const path = (idx >= 0 ? u.pathname.slice(idx + marker.length) : u.pathname).replace(/^\/+|\/+$/g, "");
    const parts = path ? path.split("/") : [];

    if (parts[0] === "stations") {
      if (parts.length === 1) {
        const { rows, page, limit } = await catalog(u.searchParams, apiKey);
        return response({ data: rows, page, limit, total: rows.length, next_page: rows.length === limit ? page + 1 : null }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=15, s-maxage=60" });
      }
      const slug = decodeURIComponent(parts[1]);
      const { rows } = await catalog(new URLSearchParams(), apiKey, slug);
      const station = rows[0];
      if (!station) return fail(404, "NOT_FOUND", "Station not found", requestId);
      if (parts.length === 2) return response({ data: station }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=15, s-maxage=60" });
      if (parts[2] === "now-playing") {
        if (station.station_source !== "INTERNAL") {
          return response({ data: { station: { id: station.id, slug: station.slug, name_ar: station.name_ar, name_en: station.name_en }, media: null, title: null, subtitle: null, started_at: null, expected_end_at: null, source: "EXTERNAL_STREAM", is_live: true, server_time: new Date().toISOString() } }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=3" });
        }
        const data = await rpc("tarteel_public_now_playing", { p_station_slug: slug }, apiKey);
        return response({ data }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=3" });
      }
    }

    if (parts[0] === "content-sources" && parts.length === 1) {
      return response({ data: asArray(await rpc("tarteel_public_content_sources", {}, apiKey)) }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=300, s-maxage=3600" });
    }
    if (parts[0] === "categories" && parts.length === 1) {
      return response({ data: asArray(await rpc("tarteel_public_categories", {}, apiKey)) }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=300, s-maxage=3600" });
    }
    if (parts[0] === "surahs" && parts.length === 1) {
      const data = asArray(await rpc("tarteel_public_surahs", {}, apiKey));
      if (data.length !== 114) return fail(503, "CATALOG_INTEGRITY", "Surah catalog is incomplete", requestId);
      return response({ data }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=300, s-maxage=3600" });
    }
    if (parts[0] === "reciters") {
      const page = int(u.searchParams.get("page"), 1, 1, 100000);
      const limit = int(u.searchParams.get("limit"), 30, 1, 100);
      if (parts.length === 1) {
        const q = (u.searchParams.get("q") ?? "").trim() || null;
        const sura = u.searchParams.has("sura") ? int(u.searchParams.get("sura"), 0, 1, 114) : undefined;
        const dbRows = sura == null
          ? asArray(await rpc("tarteel_public_reciters", { p_search: q, p_limit: 100, p_offset: 0, p_id: null }, apiKey)).map(asObject)
          : [];
        let remote: Record<string, unknown>[] = [];
        try { remote = await externalReciters(q, sura); }
        catch (error) { console.error(JSON.stringify({ event: "MP3QURAN_RECITERS_DEGRADED", request_id: requestId, message: String(error) })); }
        const merged = [...dbRows, ...remote];
        const offset = (page - 1) * limit;
        const data = merged.slice(offset, offset + limit);
        return response({ data, page, limit, total: merged.length, next_page: offset + limit < merged.length ? page + 1 : null }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=60, s-maxage=300" });
      }
      const id = parts[1];
      if (!/^[0-9a-f-]{36}$/i.test(id)) return fail(422, "VALIDATION_ERROR", "Invalid reciter id", requestId);
      const extId = externalId(id);
      if (parts.length === 2) {
        if (extId != null) {
          const row = await externalReciterByUuid(id);
          if (!row) return fail(404, "NOT_FOUND", "Reciter not found", requestId);
          return response({ data: row }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=60, s-maxage=300" });
        }
        const rows = asArray(await rpc("tarteel_public_reciters", { p_search: null, p_limit: 1, p_offset: 0, p_id: id }, apiKey));
        if (!rows[0]) return fail(404, "NOT_FOUND", "Reciter not found", requestId);
        return response({ data: rows[0] }, 200, { "x-request-id": requestId });
      }
      if (parts[2] === "surahs") {
        if (extId != null) return response({ data: await externalTracks(id, apiKey) ?? [] }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=60, s-maxage=300" });
        return response({ data: asArray(await rpc("tarteel_public_reciter_tracks", { p_reciter_id: id }, apiKey)) }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=30" });
      }
    }
    if (parts[0] === "featured" && parts.length === 1) {
      const { rows } = await catalog(new URLSearchParams(), apiKey);
      const data = rows.filter((r) => Boolean(r.is_featured) && Boolean(r.playback_url)).slice(0, 12).map((r) => ({ type: "STATION", id: r.id, slug: r.slug, name_ar: r.name_ar, name_en: r.name_en, logo_url: r.logo_url, playback_url: r.playback_url }));
      return response({ data }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=30, s-maxage=300" });
    }
    if (parts[0] === "app-config" && parts.length === 1) {
      const data = await rpc("tarteel_public_app_config", {}, apiKey);
      return response({ data: data && typeof data === "object" ? data : {} }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=30, s-maxage=300" });
    }
    if (parts[0] === "search" && parts.length === 1) {
      const q = (u.searchParams.get("q") ?? "").trim();
      if (q.length < 2) return fail(422, "VALIDATION_ERROR", "q must contain at least 2 characters", requestId);
      const stations = (await catalog(new URLSearchParams({ search: q, limit: "10" }), apiKey)).rows;
      const [dbReciterRaw, surahRaw] = await Promise.all([
        rpc("tarteel_public_reciters", { p_search: q, p_limit: 10, p_offset: 0, p_id: null }, apiKey),
        rpc("tarteel_public_surahs", {}, apiKey),
      ]);
      let external: Record<string, unknown>[] = [];
      try { external = (await externalReciters(q)).slice(0, 10); } catch (_) { /* degraded external catalog */ }
      const normalized = q.toLowerCase();
      const surahs = asArray(surahRaw).filter((item) => {
        const s = asObject(item);
        return String(s.name_ar ?? "").includes(q) || String(s.name_en ?? "").toLowerCase().includes(normalized);
      }).slice(0, 10);
      return response({ data: { stations, reciters: [...asArray(dbReciterRaw), ...external].slice(0, 10), surahs } }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=30" });
    }
    return fail(404, "NOT_FOUND", "Endpoint not found", requestId);
  } catch (error) {
    const status = Number((error as Error & { status?: number })?.status ?? 500);
    console.error(JSON.stringify({ event: "TARTEEL_PUBLIC_API_ERROR", request_id: requestId, status, message: error instanceof Error ? error.message : String(error) }));
    if (status === 401 || status === 403) return fail(status, "UPSTREAM_AUTH_ERROR", "Public data authorization failed", requestId);
    return fail(500, "INTERNAL_ERROR", "Unexpected public API error", requestId);
  }
});
