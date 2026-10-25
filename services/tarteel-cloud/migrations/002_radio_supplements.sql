-- Optional public metadata only. No existing station or user tables are moved.
CREATE TABLE IF NOT EXISTS tarteel_cloud.radio_supplements (
  id uuid PRIMARY KEY,
  provider text NOT NULL,
  provider_station_id text NOT NULL,
  name_ar text NOT NULL CHECK (length(name_ar) BETWEEN 1 AND 180),
  canonical_stream text NOT NULL UNIQUE,
  playback_url text NOT NULL CHECK (playback_url ~ '^https://'),
  category text NOT NULL,
  source_url text NOT NULL CHECK (source_url ~ '^https://'),
  attribution text NOT NULL,
  checked_at timestamptz NOT NULL,
  enabled boolean NOT NULL DEFAULT false,
  UNIQUE(provider, provider_station_id)
);
REVOKE ALL ON tarteel_cloud.radio_supplements FROM PUBLIC, tarteel_cloud_client;
CREATE INDEX IF NOT EXISTS radio_supplements_enabled_idx
  ON tarteel_cloud.radio_supplements(name_ar) WHERE enabled;
