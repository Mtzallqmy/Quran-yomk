insert into app.app_config (key, value, value_type, is_public, description) values
  ('virtual_radio_enabled', 'true', 'BOOLEAN', true, 'Enable the curated Tarteel virtual radio experience'),
  ('virtual_radio_show_next_program', 'true', 'BOOLEAN', true, 'Show the next scheduled virtual-radio program when available'),
  ('virtual_radio_allow_degraded_fallback', 'true', 'BOOLEAN', true, 'Allow resolver fallback to degraded-but-playable external sources'),
  ('virtual_radio_max_failed_sources', '8', 'INTEGER', true, 'Maximum failed source identities retained by the listener failover loop')
on conflict (key) do update set
  value = excluded.value,
  value_type = excluded.value_type,
  is_public = excluded.is_public,
  description = excluded.description;
