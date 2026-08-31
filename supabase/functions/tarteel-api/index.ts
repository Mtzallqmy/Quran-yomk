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
function uuidList(value: string | null) {
  if (!value) return [] as string[];
  const values = value.split(",").map((item) => item.trim()).filter(Boolean);
  if (values.length > 8 || values.some((item) => !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(item))) {
    throw Object.assign(new Error("Invalid failed station ids"), { status: 422 });
  }
  return values;
}
async function catalog(params: URLSearchParams, apiKey: string, slug: string | null = null) {
  const page = int(params.get("page"), 1, 1, 100000);
  const limit = int(params.get("limit"), 50, 1, 200);
  const rows = await rpc("tarteel_public_station_catalog", {
    p_environment: Deno.env.get("TARTEEL_PUBLIC_ENVIRONMENT") ?? "development",
    p_source: params.get("source"),
    p_category: params.get("category"),
    p_provider: params.get("provider"),
    p_search: params.get("search") ?? params.get("q"),
    p_limit: slug ? 1 : limit,
    p_offset: slug ? 0 : (page - 1) * limit,
    p_slug: slug,
  }, apiKey);
  return { rows: asArray(rows), page, limit };
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

    if (parts[0] === "virtual-radio") {
      const slug = decodeURIComponent(parts[1] ?? "tarteel");
      if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(slug)) {
        return fail(422, "VALIDATION_ERROR", "Invalid virtual radio slug", requestId);
      }
      const excluded = uuidList(u.searchParams.get("failed_station_ids"));
      const data = await rpc("tarteel_public_virtual_radio_managed", {
        p_slug: slug,
        p_environment: Deno.env.get("TARTEEL_PUBLIC_ENVIRONMENT") ?? "development",
        p_exclude_station_ids: excluded,
        p_now: new Date().toISOString(),
      }, apiKey) as Record<string, unknown> | null;
      const available = data?.available === true;
      console.info(JSON.stringify({
        event: "VIRTUAL_RADIO_RESOLUTION",
        request_id: requestId,
        slug,
        available,
        station_id: available && data?.station && typeof data.station === "object"
          ? (data.station as Record<string, unknown>).id ?? null
          : null,
        excluded_count: excluded.length,
      }));
      if (!available) {
        const code = String(data?.error_code ?? "NO_VIRTUAL_SOURCE_AVAILABLE");
        return response({ data, error: { code, message: "لا يوجد مصدر متاح لإذاعة ترتيل حاليًا", request_id: requestId } }, 503, {
          "x-request-id": requestId,
          "cache-control": "no-store",
        });
      }
      return response({ data }, 200, {
        "x-request-id": requestId,
        "cache-control": "public, max-age=0, s-maxage=3",
      });
    }

    if (parts[0] === "stations") {
      if (parts.length === 1) {
        const { rows, page, limit } = await catalog(u.searchParams, apiKey);
        return response({ data: rows, page, limit, total: rows.length, next_page: rows.length === limit ? page + 1 : null }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=30, s-maxage=300" });
      }
      const slug = decodeURIComponent(parts[1]);
      const { rows } = await catalog(new URLSearchParams(), apiKey, slug);
      const station = rows[0] as Record<string, unknown> | undefined;
      if (!station) return fail(404, "NOT_FOUND", "Station not found", requestId);
      if (parts.length === 2) return response({ data: station }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=30, s-maxage=300" });
      if (parts[2] === "now-playing") {
        if (station.station_source !== "INTERNAL") {
          return response({ data: { station: { id: station.id, slug: station.slug, name_ar: station.name_ar, name_en: station.name_en }, media: null, title: null, subtitle: null, started_at: null, expected_end_at: null, source: null, is_live: true, server_time: new Date().toISOString() } }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=3" });
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
        const data = asArray(await rpc("tarteel_public_reciters", { p_search: (u.searchParams.get("q") ?? "").trim() || null, p_limit: limit, p_offset: (page - 1) * limit, p_id: null }, apiKey));
        return response({ data, page, limit, total: data.length, next_page: data.length === limit ? page + 1 : null }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=30, s-maxage=300" });
      }
      const id = parts[1];
      if (!/^[0-9a-f-]{36}$/i.test(id)) return fail(422, "VALIDATION_ERROR", "Invalid reciter id", requestId);
      if (parts.length === 2) {
        const rows = asArray(await rpc("tarteel_public_reciters", { p_search: null, p_limit: 1, p_offset: 0, p_id: id }, apiKey));
        if (!rows[0]) return fail(404, "NOT_FOUND", "Reciter not found", requestId);
        return response({ data: rows[0] }, 200, { "x-request-id": requestId });
      }
      if (parts[2] === "surahs") {
        return response({ data: asArray(await rpc("tarteel_public_reciter_tracks", { p_reciter_id: id }, apiKey)) }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=30" });
      }
    }
    if (parts[0] === "featured" && parts.length === 1) {
      const { rows } = await catalog(new URLSearchParams(), apiKey);
      const data = (rows as Record<string, unknown>[]).filter((r) => r.is_featured).slice(0, 12).map((r) => ({ type: "STATION", id: r.id, slug: r.slug, name_ar: r.name_ar, name_en: r.name_en, logo_url: r.logo_url, playback_url: r.playback_url }));
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
      const [reciterRaw, surahRaw] = await Promise.all([
        rpc("tarteel_public_reciters", { p_search: q, p_limit: 10, p_offset: 0, p_id: null }, apiKey),
        rpc("tarteel_public_surahs", {}, apiKey),
      ]);
      const normalized = q.toLowerCase();
      const surahs = asArray(surahRaw).filter((item) => {
        const s = item as Record<string, unknown>;
        return String(s.name_ar ?? "").includes(q) || String(s.name_en ?? "").toLowerCase().includes(normalized);
      }).slice(0, 10);
      return response({ data: { stations, reciters: asArray(reciterRaw), surahs } }, 200, { "x-request-id": requestId, "cache-control": "public, max-age=0, s-maxage=3" });
    }
    return fail(404, "NOT_FOUND", "Endpoint not found", requestId);
  } catch (error) {
    const status = Number((error as Error & { status?: number })?.status ?? 500);
    console.error(JSON.stringify({ event: "TARTEEL_PUBLIC_API_ERROR", request_id: requestId, status, message: error instanceof Error ? error.message : String(error) }));
    if (status === 401 || status === 403) return fail(status, "UPSTREAM_AUTH_ERROR", "Public data authorization failed", requestId);
    if (status === 422) return fail(422, "VALIDATION_ERROR", "Invalid request parameters", requestId);
    return fail(500, "INTERNAL_ERROR", "Unexpected public API error", requestId);
  }
});
