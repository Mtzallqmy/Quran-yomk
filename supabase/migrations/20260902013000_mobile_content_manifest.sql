insert into app.app_config (key, value, value_type, is_public, description) values
  ('content_manifest_version', '"2026.09.02.1"', 'STRING', true, 'Monotonic public mobile content-manifest version'),
  ('content_manifest', '{"schema_version":1,"home_sections":["featured","stations","reciters","offline","categories"],"seasonal_cards":[],"reciter_of_day":null,"radio":{"show_next_program":true},"updated_at":"2026-09-02T00:00:00Z"}', 'JSON', true, 'Validated non-executable listener content manifest; never contains Dart or script code')
on conflict (key) do update set
  value = excluded.value,
  value_type = excluded.value_type,
  is_public = excluded.is_public,
  description = excluded.description;
