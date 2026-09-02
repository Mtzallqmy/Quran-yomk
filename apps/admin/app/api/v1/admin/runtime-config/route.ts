import { adminContext, requirePermission } from '@/lib/auth';
import { ApiError } from '@/lib/contracts';
import { body, json, sameOrigin } from '@/lib/http';
import { rateLimit } from '@/lib/rate-limit';
import { db } from '@/lib/supabase';

const allowedKeys = new Set([
  'radio_enabled',
  'virtual_radio_enabled',
  'virtual_radio_show_next_program',
  'virtual_radio_allow_degraded_fallback',
  'virtual_radio_max_failed_sources',
  'offline_downloads_enabled',
  'mushaf_tajweed_enabled',
  'elysia_api_enabled',
  'reciters_page_size',
  'home_sections',
  'content_manifest_version',
  'content_manifest',
  'minimum_android_version',
  'latest_android_version',
]);

const booleanKeys = new Set([
  'radio_enabled',
  'virtual_radio_enabled',
  'virtual_radio_show_next_program',
  'virtual_radio_allow_degraded_fallback',
  'offline_downloads_enabled',
  'mushaf_tajweed_enabled',
  'elysia_api_enabled',
]);
const numberKeys = new Set(['virtual_radio_max_failed_sources', 'reciters_page_size']);
const homeSections = new Set(['featured', 'stations', 'reciters', 'offline', 'categories']);
const forbiddenManifestKeys = new Set(['script', 'javascript', 'dart', 'code', 'eval']);

function serialize(key: string, value: unknown) {
  if (!allowedKeys.has(key)) throw new ApiError(422, 'CONFIG_KEY_NOT_ALLOWED', `Unsupported runtime key: ${key}`);
  if (booleanKeys.has(key)) {
    if (typeof value !== 'boolean') throw new ApiError(422, 'VALIDATION_ERROR', `${key} must be boolean`);
    return JSON.stringify(value);
  }
  if (numberKeys.has(key)) {
    if (!Number.isInteger(value)) throw new ApiError(422, 'VALIDATION_ERROR', `${key} must be an integer`);
    const number = Number(value);
    if (key === 'virtual_radio_max_failed_sources' && (number < 1 || number > 12)) {
      throw new ApiError(422, 'VALIDATION_ERROR', `${key} must be between 1 and 12`);
    }
    if (key === 'reciters_page_size' && (number < 30 || number > 300)) {
      throw new ApiError(422, 'VALIDATION_ERROR', `${key} must be between 30 and 300`);
    }
    return JSON.stringify(number);
  }
  if (key === 'home_sections') {
    if (!Array.isArray(value) || value.some((item) => typeof item !== 'string' || !homeSections.has(item))) {
      throw new ApiError(422, 'VALIDATION_ERROR', 'home_sections contains an unsupported section');
    }
    return JSON.stringify([...new Set(value)]);
  }
  if (key === 'content_manifest') {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      throw new ApiError(422, 'VALIDATION_ERROR', 'content_manifest must be an object');
    }
    const manifest = value as Record<string, unknown>;
    if (manifest.schema_version !== 1) {
      throw new ApiError(422, 'VALIDATION_ERROR', 'Unsupported content manifest schema_version');
    }
    if (Object.keys(manifest).some((item) => forbiddenManifestKeys.has(item.toLowerCase()))) {
      throw new ApiError(422, 'VALIDATION_ERROR', 'Executable fields are forbidden in content manifests');
    }
    if (manifest.home_sections !== undefined) serialize('home_sections', manifest.home_sections);
    return JSON.stringify(manifest);
  }
  if (typeof value !== 'string' || value.length > 1024) {
    throw new ApiError(422, 'VALIDATION_ERROR', `${key} must be a short string`);
  }
  return JSON.stringify(value.trim());
}

function decode(value: unknown) {
  if (typeof value !== 'string') return value;
  try { return JSON.parse(value); } catch { return value; }
}

export async function GET(request: Request) {
  const ctx = await adminContext(request);
  requirePermission(ctx, 'schedules.read');
  const keys = [...allowedKeys].map(encodeURIComponent).join(',');
  const result = await db('app', `app_config?key=in.(${keys})&select=key,value,value_type,is_public,description&order=key.asc`);
  const rows = (result.data as Array<Record<string, unknown>>).map((row) => ({ ...row, value: decode(row.value) }));
  return json({ data: rows });
}

export async function PUT(request: Request) {
  const ctx = await adminContext(request);
  requirePermission(ctx, 'schedules.write');
  sameOrigin(request);
  rateLimit(`runtime-config:${ctx.userId}`, 20, 60_000);
  const payload = await body(request) as { updates?: Record<string, unknown> };
  if (!payload.updates || typeof payload.updates !== 'object' || Array.isArray(payload.updates)) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'updates object is required');
  }
  const entries = Object.entries(payload.updates);
  if (!entries.length || entries.length > allowedKeys.size) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'No valid updates supplied');
  }
  const changed: Array<Record<string, unknown>> = [];
  for (const [key, value] of entries) {
    const encoded = serialize(key, value);
    const result = await db(
      'app',
      `app_config?key=eq.${encodeURIComponent(key)}`,
      { method: 'PATCH', body: JSON.stringify({ value: encoded }) },
    );
    const row = Array.isArray(result.data) ? result.data[0] : null;
    if (!row) throw new ApiError(404, 'CONFIG_KEY_NOT_FOUND', `Runtime config key not seeded: ${key}`);
    changed.push({ ...row, value: decode((row as Record<string, unknown>).value) });
  }
  return json({ data: changed });
}
