import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const CORS = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "apikey,content-type,x-request-id",
  "access-control-allow-methods": "GET,OPTIONS",
  "content-type": "application/json; charset=utf-8",
};
const SUPABASE_URL = (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, "");

function firstSecretKey(raw: string | undefined) {
  if (!raw) return "";
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    for (const value of Object.values(parsed)) {
      if (typeof value === "string" && value) return value;
      if (value && typeof value === "object") {
        const candidate = (value as Record<string, unknown>).secret ??
          (value as Record<string, unknown>).key ??
          (value as Record<string, unknown>).value;
        if (typeof candidate === "string" && candidate) return candidate;
      }
    }
  } catch {
    return "";
  }
  return "";
}

const INTERNAL_API_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  firstSecretKey(Deno.env.get("SUPABASE_SECRET_KEYS"));
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

function asArray(value: unknown): unknown[] {
  return Array.isArray(value) ? value : [];
}

function integer(value: string | null, fallback: number, min: number, max: number) {
  const parsed = Number(value ?? fallback);
  return Number.isInteger(parsed) && parsed >= min && parsed <= max ? parsed : fallback;
}

function nullableParam(value: string | null, maxLength = 100) {
  if (value == null) return null;
  const normalized = value.trim();
  if (!normalized) return null;
  if (normalized.length > maxLength) {
    throw Object.assign(new Error("parameter too long"), { status: 422 });
  }
  return normalized;
}

function publicObjectUrl(bucket: unknown, path: unknown) {
  if (typeof bucket !== "string" || typeof path !== "string" || !bucket || !path) return null;
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  return `${SUPABASE_URL}/storage/v1/object/public/${encodeURIComponent(bucket)}/${encodedPath}`;
}

function enrichAudio(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;
  const row = { ...(value as Record<string, unknown>) };
  row.audio_url = publicObjectUrl(row.storage_bucket, row.storage_path);
  row.offline_cache_key = typeof row.sha256 === "string" ? `islamic-audio:${row.sha256}` : null;
  return row;
}

function enrichContent(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return value;
  const row = { ...(value as Record<string, unknown>) };
  if (row.audio) row.audio = enrichAudio(row.audio);
  return row;
}

async function readJson(response: Response) {
  const raw = await response.text();
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    throw Object.assign(new Error("invalid internal JSON"), { status: 502 });
  }
}

async function rpc(name: string, args: Record<string, unknown>) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: INTERNAL_API_KEY,
      authorization: `Bearer ${INTERNAL_API_KEY}`,
      accept: "application/json",
      "content-type": "application/json",
    },
    body: JSON.stringify(args),
    cache: "no-store",
  });
  const data = await readJson(response);
  if (!response.ok) {
    const error = new Error(`database request failed (${response.status})`) as Error & { status?: number };
    error.status = response.status === 404 ? 404 : response.status === 400 ? 422 : 500;
    throw error;
  }
  return data;
}

Deno.serve(async (req: Request) => {
  const supplied = req.headers.get("x-request-id");
  const requestId = supplied && /^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(supplied)
    ? supplied
    : crypto.randomUUID();

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: CORS });
  if (req.method !== "GET") {
    return fail(405, "METHOD_NOT_ALLOWED", "Only GET endpoints are exposed", requestId);
  }
  const apiKey = req.headers.get("apikey") ?? "";
  if (!apiKey || !ALLOWED_KEYS.has(apiKey)) {
    return fail(401, "INVALID_API_KEY", "A valid publishable API key is required", requestId);
  }
  if (!SUPABASE_URL || !INTERNAL_API_KEY) {
    return fail(503, "SERVER_NOT_CONFIGURED", "Islamic library API is not configured", requestId);
  }

  try {
    const url = new URL(req.url);
    const marker = "/islamic-library";
    const at = url.pathname.indexOf(marker);
    const path = (at >= 0 ? url.pathname.slice(at + marker.length) : url.pathname)
      .replace(/^\/+|\/+$/g, "");
    const parts = path ? path.split("/") : [];
    const cache = { "x-request-id": requestId, "cache-control": "public, max-age=60, s-maxage=300" };

    if (parts.length === 0 || parts[0] === "health") {
      const [categories, audio] = await Promise.all([
        rpc("tarteel_public_islamic_categories", {}),
        rpc("tarteel_public_islamic_audio", { p_kind: null, p_limit: 100, p_offset: 0 }),
      ]);
      return response({
        data: {
          ready: true,
          schema_version: 1,
          categories: asArray(categories).length,
          approved_audio: asArray(audio).length,
          offline_first: true,
          rights_policy: "per-item-audio-license-required",
        },
      }, 200, cache);
    }

    if (parts[0] === "sources" && parts.length === 1) {
      return response({ data: asArray(await rpc("tarteel_public_islamic_sources", {})) }, 200, cache);
    }

    if (parts[0] === "categories" && parts.length === 1) {
      return response({ data: asArray(await rpc("tarteel_public_islamic_categories", {})) }, 200, cache);
    }

    if (parts[0] === "schedules" && parts.length === 1) {
      return response({ data: asArray(await rpc("tarteel_public_islamic_schedules", {})) }, 200, cache);
    }

    if (parts[0] === "audio" && parts.length === 1) {
      const page = integer(url.searchParams.get("page"), 1, 1, 100000);
      const limit = integer(url.searchParams.get("limit"), 50, 1, 100);
      const kind = nullableParam(url.searchParams.get("kind"), 30);
      if (kind && !["adhan", "iqamah", "dua", "dhikr", "other"].includes(kind)) {
        return fail(422, "VALIDATION_ERROR", "Invalid audio kind", requestId);
      }
      const rows = asArray(await rpc("tarteel_public_islamic_audio", {
        p_kind: kind,
        p_limit: limit,
        p_offset: (page - 1) * limit,
      })).map(enrichAudio);
      return response({
        data: rows,
        page,
        limit,
        next_page: rows.length === limit ? page + 1 : null,
      }, 200, cache);
    }

    if (parts[0] === "content") {
      const id = parts.length === 2 ? decodeURIComponent(parts[1]) : null;
      if (id && !/^[0-9a-f]{8}-[0-9a-f-]{27}$/i.test(id)) {
        return fail(422, "VALIDATION_ERROR", "Invalid content id", requestId);
      }
      const page = integer(url.searchParams.get("page"), 1, 1, 100000);
      const limit = id ? 1 : integer(url.searchParams.get("limit"), 50, 1, 200);
      const rows = asArray(await rpc("tarteel_public_islamic_content", {
        p_category: nullableParam(url.searchParams.get("category"), 50),
        p_search: nullableParam(url.searchParams.get("q") ?? url.searchParams.get("search"), 120),
        p_source: nullableParam(url.searchParams.get("source"), 80),
        p_limit: limit,
        p_offset: id ? 0 : (page - 1) * limit,
        p_id: id,
      })).map(enrichContent);
      if (id) {
        if (!rows[0]) return fail(404, "NOT_FOUND", "Content item not found", requestId);
        return response({ data: rows[0] }, 200, cache);
      }
      return response({
        data: rows,
        page,
        limit,
        next_page: rows.length === limit ? page + 1 : null,
      }, 200, cache);
    }

    return fail(404, "NOT_FOUND", "Endpoint not found", requestId);
  } catch (error) {
    const status = Number((error as Error & { status?: number })?.status ?? 500);
    console.error(JSON.stringify({
      event: "ISLAMIC_LIBRARY_API_ERROR",
      request_id: requestId,
      status,
      message: error instanceof Error ? error.message : String(error),
    }));
    if (status === 422) return fail(422, "VALIDATION_ERROR", "Invalid request parameters", requestId);
    if (status === 404) return fail(404, "NOT_FOUND", "Resource not found", requestId);
    return fail(500, "INTERNAL_ERROR", "Islamic library request failed", requestId);
  }
});
