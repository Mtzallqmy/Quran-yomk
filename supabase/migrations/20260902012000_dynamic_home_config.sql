insert into app.app_config (key, value, value_type, is_public, description) values
  ('home_sections', '["featured","stations","reciters","offline","categories"]', 'JSON', true, 'Ordered whitelist of listener home sections rendered by the mobile client')
on conflict (key) do update set
  value = excluded.value,
  value_type = excluded.value_type,
  is_public = excluded.is_public,
  description = excluded.description;
