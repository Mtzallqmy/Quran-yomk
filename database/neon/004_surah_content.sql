-- Metadata-only schema recovered from the verified deployed Tarteel schema.
CREATE SCHEMA IF NOT EXISTS surah_content;
CREATE TABLE IF NOT EXISTS surah_content.surah_ayah_references (
  verse_key text NOT NULL,
  surah integer NOT NULL,
  ayah integer NOT NULL,
  CONSTRAINT surah_ayah_references_surah_check CHECK (((surah >= 1) AND (surah <= 114))),
  CONSTRAINT surah_ayah_references_ayah_check CHECK (((ayah >= 1) AND (ayah <= 286))),
  CONSTRAINT surah_ayah_references_check CHECK ((verse_key = (((surah)::text || ':'::text) || (ayah)::text))),
  CONSTRAINT surah_ayah_references_pkey PRIMARY KEY (verse_key),
  CONSTRAINT surah_ayah_references_surah_ayah_key UNIQUE (surah, ayah)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_content_entries (
  project_slug text NOT NULL,
  location_key text NOT NULL,
  scope text NOT NULL,
  surah integer,
  ayah integer,
  page integer,
  word_number integer,
  version_sha256 text NOT NULL,
  source_url text NOT NULL,
  verified_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT surah_content_entries_scope_check CHECK ((scope = ANY (ARRAY['sura'::text, 'page'::text, 'aya'::text, 'word'::text]))),
  CONSTRAINT surah_content_entries_surah_check CHECK (((surah >= 1) AND (surah <= 114))),
  CONSTRAINT surah_content_entries_ayah_check CHECK (((ayah >= 1) AND (ayah <= 286))),
  CONSTRAINT surah_content_entries_page_check CHECK (((page >= 1) AND (page <= 604))),
  CONSTRAINT surah_content_entries_word_number_check CHECK (((word_number >= 1) AND (word_number <= 256))),
  CONSTRAINT surah_content_entries_source_url_check CHECK ((source_url ~~ 'https://dev.surahapp.com/api/v1/%'::text)),
  CONSTRAINT surah_content_entries_check CHECK ((((scope = 'sura'::text) AND (surah IS NOT NULL) AND (ayah IS NULL) AND (page IS NULL) AND (word_number IS NULL)) OR ((scope = 'page'::text) AND (page IS NOT NULL) AND (surah IS NULL) AND (ayah IS NULL) AND (word_number IS NULL)) OR ((scope = 'aya'::text) AND (surah IS NOT NULL) AND (ayah IS NOT NULL) AND (page IS NULL) AND (word_number IS NULL)) OR ((scope = 'word'::text) AND (surah IS NOT NULL) AND (ayah IS NOT NULL) AND (word_number IS NOT NULL) AND (page IS NULL)))),
  CONSTRAINT surah_content_entries_pkey PRIMARY KEY (project_slug, location_key)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_content_versions (
  project_slug text NOT NULL,
  sha256 text NOT NULL,
  etag text,
  bytes integer NOT NULL,
  verified_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT surah_content_versions_sha256_check CHECK ((sha256 ~ '^[a-f0-9]{64}$'::text)),
  CONSTRAINT surah_content_versions_bytes_check CHECK (((bytes >= 1) AND (bytes <= 2097152))),
  CONSTRAINT surah_content_versions_pkey PRIMARY KEY (project_slug, sha256)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_projects (
  slug text NOT NULL,
  title text NOT NULL,
  scope text NOT NULL,
  published boolean NOT NULL,
  metadata_sha256 text NOT NULL,
  source_url text NOT NULL,
  first_seen timestamp with time zone DEFAULT now() NOT NULL,
  verified_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT surah_projects_slug_check CHECK ((slug ~ '^[A-Za-z0-9][A-Za-z0-9_-]{0,99}$'::text)),
  CONSTRAINT surah_projects_scope_check CHECK ((scope = ANY (ARRAY['sura'::text, 'page'::text, 'aya'::text, 'word'::text]))),
  CONSTRAINT surah_projects_metadata_sha256_check CHECK ((metadata_sha256 ~ '^[a-f0-9]{64}$'::text)),
  CONSTRAINT surah_projects_source_url_check CHECK ((source_url ~~ 'https://dev.surahapp.com/api/v1/%'::text)),
  CONSTRAINT surah_projects_pkey PRIMARY KEY (slug)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_source_rights (
  project_slug text NOT NULL,
  policy text NOT NULL,
  permanent_storage_allowed boolean DEFAULT false NOT NULL,
  redistribution_allowed boolean DEFAULT false NOT NULL,
  terms_url text NOT NULL,
  attribution text NOT NULL,
  review_note text NOT NULL,
  verified_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT surah_source_rights_policy_check CHECK ((policy = ANY (ARRAY['direct_session_only'::text, 'metadata_only'::text]))),
  CONSTRAINT surah_source_rights_permanent_storage_allowed_check CHECK ((NOT permanent_storage_allowed)),
  CONSTRAINT surah_source_rights_redistribution_allowed_check CHECK ((NOT redistribution_allowed)),
  CONSTRAINT surah_source_rights_pkey PRIMARY KEY (project_slug)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_sync_logs (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  catalog_sha256 text NOT NULL,
  discovered integer NOT NULL,
  inserted integer NOT NULL,
  matched integer NOT NULL,
  rejected integer NOT NULL,
  report jsonb NOT NULL,
  completed_at timestamp with time zone DEFAULT now() NOT NULL,
  CONSTRAINT surah_sync_logs_discovered_check CHECK ((discovered >= 0)),
  CONSTRAINT surah_sync_logs_inserted_check CHECK ((inserted >= 0)),
  CONSTRAINT surah_sync_logs_matched_check CHECK ((matched >= 0)),
  CONSTRAINT surah_sync_logs_rejected_check CHECK ((rejected >= 0)),
  CONSTRAINT surah_sync_logs_pkey PRIMARY KEY (id)
);
CREATE TABLE IF NOT EXISTS surah_content.surah_word_references (
  project_slug text NOT NULL,
  verse_key text NOT NULL,
  word_number integer NOT NULL,
  CONSTRAINT surah_word_references_word_number_check CHECK (((word_number >= 1) AND (word_number <= 256))),
  CONSTRAINT surah_word_references_pkey PRIMARY KEY (project_slug, verse_key, word_number)
);
REVOKE ALL ON ALL TABLES IN SCHEMA surah_content FROM PUBLIC;

DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_source_rights'::regclass AND conname='surah_source_rights_project_slug_fkey') THEN ALTER TABLE surah_content.surah_source_rights ADD CONSTRAINT surah_source_rights_project_slug_fkey FOREIGN KEY (project_slug) REFERENCES surah_content.surah_projects(slug); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_ayah_references'::regclass AND conname='surah_ayah_references_verse_key_fkey') THEN ALTER TABLE surah_content.surah_ayah_references ADD CONSTRAINT surah_ayah_references_verse_key_fkey FOREIGN KEY (verse_key) REFERENCES tarteel_mushaf.canonical_ayahs(verse_key); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_word_references'::regclass AND conname='surah_word_references_project_slug_fkey') THEN ALTER TABLE surah_content.surah_word_references ADD CONSTRAINT surah_word_references_project_slug_fkey FOREIGN KEY (project_slug) REFERENCES surah_content.surah_projects(slug); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_word_references'::regclass AND conname='surah_word_references_verse_key_fkey') THEN ALTER TABLE surah_content.surah_word_references ADD CONSTRAINT surah_word_references_verse_key_fkey FOREIGN KEY (verse_key) REFERENCES surah_content.surah_ayah_references(verse_key); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_content_versions'::regclass AND conname='surah_content_versions_project_slug_fkey') THEN ALTER TABLE surah_content.surah_content_versions ADD CONSTRAINT surah_content_versions_project_slug_fkey FOREIGN KEY (project_slug) REFERENCES surah_content.surah_projects(slug); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_content_entries'::regclass AND conname='surah_content_entries_project_slug_fkey') THEN ALTER TABLE surah_content.surah_content_entries ADD CONSTRAINT surah_content_entries_project_slug_fkey FOREIGN KEY (project_slug) REFERENCES surah_content.surah_projects(slug); END IF; END $$;
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='surah_content.surah_content_entries'::regclass AND conname='surah_content_entries_project_slug_version_sha256_fkey') THEN ALTER TABLE surah_content.surah_content_entries ADD CONSTRAINT surah_content_entries_project_slug_version_sha256_fkey FOREIGN KEY (project_slug, version_sha256) REFERENCES surah_content.surah_content_versions(project_slug, sha256); END IF; END $$;
CREATE OR REPLACE VIEW surah_content.public_projects AS  SELECT p.slug,
    p.title,
    p.scope,
    p.source_url,
    p.metadata_sha256,
    p.verified_at,
    r.policy,
    r.permanent_storage_allowed,
    r.redistribution_allowed,
    r.terms_url,
    r.attribution
   FROM surah_content.surah_projects p
     JOIN surah_content.surah_source_rights r ON r.project_slug = p.slug
  WHERE p.published;;
REVOKE ALL ON ALL TABLES IN SCHEMA surah_content FROM PUBLIC;
GRANT USAGE ON SCHEMA surah_content TO tarteel_catalog_reader;
GRANT SELECT ON surah_content.public_projects TO tarteel_catalog_reader;


