-- Public runtime configuration consumed by Flutter through /app-config.
-- These values may change without shipping a new APK. They are data/config only;
-- executable Dart code is never delivered through this mechanism.
insert into app.app_config (key, value, value_type, is_public, description) values
  ('offline_downloads_enabled', 'true', 'BOOLEAN', true, 'Enable Quran offline download UX'),
  ('mushaf_tajweed_enabled', 'true', 'BOOLEAN', true, 'Enable Tajweed Mushaf edition'),
  ('reciters_page_size', '100', 'INTEGER', true, 'Preferred audio reciter catalog page size'),
  ('content_manifest_version', '"v1"', 'STRING', true, 'Versioned remote content manifest identifier'),
  ('elysia_api_enabled', 'false', 'BOOLEAN', true, 'Route supported read-only requests through the optional Elysia BFF'),
  ('elysia_api_base_url', '""', 'URL', true, 'Optional Elysia BFF public base URL; empty keeps Supabase API active')
on conflict (key) do update set
  value = excluded.value,
  value_type = excluded.value_type,
  is_public = excluded.is_public,
  description = excluded.description,
  updated_at = now();
