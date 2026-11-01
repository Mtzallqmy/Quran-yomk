-- Additive, repeatable. Test on mushaf-library-validation before applying to main.
-- No Quran text is copied: verse identities point at the existing pinned corpus.
CREATE SCHEMA IF NOT EXISTS tarteel_mushaf;
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_sources (
 id text PRIMARY KEY, name text NOT NULL, url text NOT NULL CHECK(url LIKE 'https://%')
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_licenses (
 id text PRIMARY KEY, source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 url text NOT NULL, notice text NOT NULL,
 status text NOT NULL CHECK(status IN ('approved','pending','rejected'))
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_riwayat (
 id text PRIMARY KEY, name_ar text NOT NULL UNIQUE, ayah_count integer NOT NULL CHECK(ayah_count>0)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_versions (
 id text PRIMARY KEY, source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 version text NOT NULL, sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'),
 verified_at timestamptz NOT NULL DEFAULT now(), UNIQUE(source_id,version,sha256)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_editions (
 id text PRIMARY KEY, riwayah_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_riwayat,
 source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 license_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_licenses,
 version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 publisher text NOT NULL, edition text NOT NULL, text_version text NOT NULL,
 page_layout text NOT NULL, content_type text NOT NULL, title_ar text NOT NULL,
 fingerprint text NOT NULL CHECK(fingerprint ~ '^[a-f0-9]{64}$'),
 UNIQUE(riwayah_id,publisher,edition,text_version,page_layout,content_type,fingerprint)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.canonical_ayahs (
 verse_key text PRIMARY KEY, surah integer NOT NULL CHECK(surah BETWEEN 1 AND 114),
 ayah integer NOT NULL CHECK(ayah BETWEEN 1 AND 286),
 text_sha256 text NOT NULL CHECK(text_sha256 ~ '^[a-f0-9]{64}$'),
 version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 juz integer NOT NULL CHECK(juz BETWEEN 1 AND 30),
 hizb_quarter integer NOT NULL CHECK(hizb_quarter BETWEEN 1 AND 240),
 UNIQUE(surah,ayah), CHECK(verse_key=surah::text||':'||ayah::text)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_pages (
 edition_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_editions,
 page integer NOT NULL CHECK(page BETWEEN 1 AND 604), PRIMARY KEY(edition_id,page)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_assets (
 edition_id text NOT NULL, page integer NOT NULL, kind text NOT NULL CHECK(kind IN ('image','bounds')),
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'), bytes bigint NOT NULL CHECK(bytes>0),
 PRIMARY KEY(edition_id,page,kind), FOREIGN KEY(edition_id,page) REFERENCES tarteel_mushaf.mushaf_pages
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_ayah_positions (
 edition_id text NOT NULL, page integer NOT NULL, verse_key text NOT NULL REFERENCES tarteel_mushaf.canonical_ayahs,
 source_bounds jsonb NOT NULL CHECK(jsonb_typeof(source_bounds)='array'),
 PRIMARY KEY(edition_id,page,verse_key), FOREIGN KEY(edition_id,page) REFERENCES tarteel_mushaf.mushaf_pages
);
CREATE INDEX IF NOT EXISTS mushaf_ayah_lookup_idx ON tarteel_mushaf.mushaf_ayah_positions(verse_key,edition_id);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_words (
 verse_key text NOT NULL REFERENCES tarteel_mushaf.canonical_ayahs, position integer NOT NULL CHECK(position>0),
 version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 source_word_id text NOT NULL, PRIMARY KEY(verse_key,position,version_id)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.tajweed_rules (
 id text PRIMARY KEY, source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 label_ar text NOT NULL, explanation_ar text NOT NULL,
 reviewed boolean NOT NULL DEFAULT false, review_reference text,
 CHECK(NOT reviewed OR review_reference IS NOT NULL)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.tajweed_annotations (
 verse_key text NOT NULL REFERENCES tarteel_mushaf.canonical_ayahs,
 rule_id text NOT NULL REFERENCES tarteel_mushaf.tajweed_rules,
 version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 text_sha256 text NOT NULL CHECK(text_sha256 ~ '^[a-f0-9]{64}$'),
 start_codepoint integer NOT NULL CHECK(start_codepoint>=0),
 end_codepoint integer NOT NULL CHECK(end_codepoint>start_codepoint),
 PRIMARY KEY(verse_key,rule_id,version_id,start_codepoint,end_codepoint)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.thematic_categories (
 id text PRIMARY KEY, source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 title_ar text NOT NULL
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.thematic_sections (
 id text PRIMARY KEY, source_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_sources,
 version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 category_id text NOT NULL REFERENCES tarteel_mushaf.thematic_categories,
 parent_id text REFERENCES tarteel_mushaf.thematic_sections DEFERRABLE INITIALLY DEFERRED,
 source_key text NOT NULL, title_ar text NOT NULL,
 UNIQUE(source_id,version_id,source_key)
);
CREATE INDEX IF NOT EXISTS thematic_parent_idx ON tarteel_mushaf.thematic_sections(parent_id);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.thematic_ayah_ranges (
 section_id text NOT NULL REFERENCES tarteel_mushaf.thematic_sections,
 verse_key text NOT NULL REFERENCES tarteel_mushaf.canonical_ayahs,
 PRIMARY KEY(section_id,verse_key)
);
CREATE INDEX IF NOT EXISTS thematic_verse_idx ON tarteel_mushaf.thematic_ayah_ranges(verse_key);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_download_packages (
 id text PRIMARY KEY, edition_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_editions,
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'), bytes bigint NOT NULL CHECK(bytes>0),
 sha256 text NOT NULL CHECK(sha256 ~ '^[a-f0-9]{64}$'), UNIQUE(edition_id,sha256)
);
CREATE TABLE IF NOT EXISTS tarteel_mushaf.mushaf_sync_logs (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, version_id text NOT NULL REFERENCES tarteel_mushaf.mushaf_versions,
 inserted integer NOT NULL CHECK(inserted>=0), matched integer NOT NULL CHECK(matched>=0),
 report jsonb NOT NULL, completed_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON SCHEMA tarteel_mushaf FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA tarteel_mushaf FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA tarteel_mushaf FROM PUBLIC;
GRANT USAGE ON SCHEMA tarteel_mushaf TO tarteel_catalog_reader;
CREATE OR REPLACE VIEW tarteel_mushaf.public_editions WITH(security_barrier=true) AS
 SELECT e.id,e.title_ar,e.edition,e.text_version,e.page_layout,e.content_type,
 r.name_ar AS riwayah,s.name AS source,s.url AS source_url,l.url AS license_url,l.status AS rights_status
 FROM tarteel_mushaf.mushaf_editions e
 JOIN tarteel_mushaf.mushaf_sources s ON s.id=e.source_id
 JOIN tarteel_mushaf.mushaf_riwayat r ON r.id=e.riwayah_id
 JOIN tarteel_mushaf.mushaf_licenses l ON l.id=e.license_id WHERE l.status='approved';
CREATE OR REPLACE VIEW tarteel_mushaf.public_packages WITH(security_barrier=true) AS
 SELECT p.* FROM tarteel_mushaf.mushaf_download_packages p
 JOIN tarteel_mushaf.public_editions e ON e.id=p.edition_id;
GRANT SELECT ON tarteel_mushaf.public_editions,tarteel_mushaf.public_packages TO tarteel_catalog_reader;
CREATE OR REPLACE VIEW tarteel_mushaf.public_library_status WITH(security_barrier=true) AS
 SELECT (SELECT count(*) FROM tarteel_mushaf.canonical_ayahs) AS canonical_ayahs,
 (SELECT count(*) FROM tarteel_mushaf.thematic_sections) AS topics,
 (SELECT count(DISTINCT verse_key) FROM tarteel_mushaf.thematic_ayah_ranges) AS covered_ayahs,
 '2026-10-24'::text AS topic_version,
 'https://quranpedia.net/dumps'::text AS topic_source,
 false AS complete_reviewed_tajweed_available;
GRANT SELECT ON tarteel_mushaf.public_library_status TO tarteel_catalog_reader;
