-- Tarteel: additive, isolated Neon metadata catalog schema.
-- Never run against existing production databases without review.
CREATE SCHEMA IF NOT EXISTS tarteel_catalog;

CREATE TABLE IF NOT EXISTS tarteel_catalog.providers (
 id text PRIMARY KEY,
 name text NOT NULL,
 homepage text,
 terms_url text,
 enabled boolean NOT NULL DEFAULT false,
 sync_policy text NOT NULL DEFAULT 'metadata_only',
 checked_at timestamptz
);
CREATE TABLE IF NOT EXISTS tarteel_catalog.entities (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 kind text NOT NULL CHECK(kind IN ('reciter','recording','radio','translation','mushaf','page_asset','tafsir')),
 canonical_key text NOT NULL,
 title_ar text,
 title_en text,
 language_code text,
 narration text,
 surah_number smallint CHECK(surah_number BETWEEN 1 AND 114),
 ayah_number smallint CHECK(ayah_number > 0),
 edition text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(kind, canonical_key)
);
CREATE TABLE IF NOT EXISTS tarteel_catalog.provider_items (
 provider_id text NOT NULL REFERENCES tarteel_catalog.providers(id),
 external_id text NOT NULL,
 entity_id bigint NOT NULL REFERENCES tarteel_catalog.entities(id),
 source_url text,
 license_id text,
 rights_url text,
 usage_status text NOT NULL DEFAULT 'pending' CHECK(usage_status IN ('pending','approved','restricted','denied')),
 last_seen timestamptz NOT NULL DEFAULT now(),
 metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
 PRIMARY KEY(provider_id, external_id)
);
CREATE INDEX IF NOT EXISTS provider_items_entity_idx ON tarteel_catalog.provider_items(entity_id);
CREATE TABLE IF NOT EXISTS tarteel_catalog.media_endpoints (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 entity_id bigint NOT NULL REFERENCES tarteel_catalog.entities(id),
 normalized_url text NOT NULL,
 url_fingerprint text NOT NULL,
 content_type text NOT NULL DEFAULT 'stream',
 status text NOT NULL DEFAULT 'unverified' CHECK(status IN ('unverified','healthy','unhealthy','blocked')),
 can_download boolean NOT NULL DEFAULT false,
 last_http_status integer,
 checked_at timestamptz,
 UNIQUE(entity_id, url_fingerprint)
);
CREATE INDEX IF NOT EXISTS media_endpoints_fingerprint_idx ON tarteel_catalog.media_endpoints(url_fingerprint);
CREATE TABLE IF NOT EXISTS tarteel_catalog.sync_runs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 provider_id text REFERENCES tarteel_catalog.providers(id),
 started_at timestamptz NOT NULL DEFAULT now(),
 finished_at timestamptz,
 discovered integer NOT NULL DEFAULT 0,
 inserted integer NOT NULL DEFAULT 0,
 matched integer NOT NULL DEFAULT 0,
 rejected integer NOT NULL DEFAULT 0,
 notes text
);
COMMENT ON SCHEMA tarteel_catalog IS 'Additive metadata registry. Quran Foundation cache/content subject to developer terms and Content Sync restrictions.';
