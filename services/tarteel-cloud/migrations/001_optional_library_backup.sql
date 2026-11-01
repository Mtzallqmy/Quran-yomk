-- Isolated, non-prayer cloud data only. Safe to run repeatedly.
CREATE SCHEMA IF NOT EXISTS tarteel_cloud;
REVOKE ALL ON SCHEMA tarteel_cloud FROM PUBLIC;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'tarteel_cloud_client') THEN
    CREATE ROLE tarteel_cloud_client NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS;
  END IF;
END $$;
GRANT tarteel_cloud_client TO tarteel_owner;
GRANT USAGE ON SCHEMA tarteel_cloud TO tarteel_cloud_client;
CREATE TABLE IF NOT EXISTS tarteel_cloud.devices (
  id uuid PRIMARY KEY,
  token_hash char(64) NOT NULL UNIQUE CHECK (token_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);
CREATE TABLE IF NOT EXISTS tarteel_cloud.library_backups (
  device_id uuid PRIMARY KEY REFERENCES tarteel_cloud.devices(id) ON DELETE CASCADE,
  revision bigint NOT NULL CHECK (revision > 0),
  payload jsonb NOT NULL CHECK (
    jsonb_typeof(payload) = 'object' AND octet_length(payload::text) <= 65536
    AND payload ?& ARRAY['stations','reciters','tracks']
    AND payload - ARRAY['stations','reciters','tracks'] = '{}'::jsonb
    AND jsonb_typeof(payload->'stations') = 'array'
    AND jsonb_typeof(payload->'reciters') = 'array'
    AND jsonb_typeof(payload->'tracks') = 'array'
  ),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS library_backups_updated_idx ON tarteel_cloud.library_backups(updated_at);
CREATE TABLE IF NOT EXISTS tarteel_cloud.request_budgets (
  principal text PRIMARY KEY CHECK (length(principal) <= 100),
  window_start timestamptz NOT NULL,
  request_count integer NOT NULL CHECK (request_count > 0)
);
REVOKE ALL ON ALL TABLES IN SCHEMA tarteel_cloud FROM PUBLIC;
ALTER TABLE tarteel_cloud.library_backups ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarteel_cloud.library_backups FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='tarteel_cloud' AND tablename='library_backups' AND policyname='own_device_backup') THEN
    CREATE POLICY own_device_backup ON tarteel_cloud.library_backups
      FOR ALL TO tarteel_cloud_client
      USING (device_id::text = current_setting('tarteel.device_id', true))
      WITH CHECK (device_id::text = current_setting('tarteel.device_id', true));
  END IF;
END $$;
GRANT SELECT, INSERT, UPDATE, DELETE ON tarteel_cloud.library_backups TO tarteel_cloud_client;
