-- Additive identity/version cutover. No Quran text or tafsir bodies in Postgres.
INSERT INTO tarteel_mushaf.mushaf_sources(id,name,url) VALUES
 ('kfgqpc-official','مجمع الملك فهد لطباعة المصحف الشريف','https://qurancomplex.gov.sa/quran-dev/') ON CONFLICT(id) DO NOTHING;
INSERT INTO tarteel_mushaf.mushaf_licenses(id,source_id,url,notice,status) VALUES
 ('kfgqpc-developer-v30','kfgqpc-official','https://qurancomplex.gov.sa/quran-dev/',
  'Official developer platform explicitly supplies Unicode data/font for application development. Preserve publisher attribution and unmodified source text; no unrestricted third-party license asserted.','approved') ON CONFLICT(id) DO NOTHING;
INSERT INTO tarteel_mushaf.mushaf_versions(id,source_id,version,sha256) VALUES
 ('canonical-v2-kfgqpc','kfgqpc-official','kfgqpc-hafs-v30; canonical2','132090d1264257ce816dfe1245014c422e3cd4c491f2397c78447efbe161ee8f') ON CONFLICT(id) DO NOTHING;
ALTER TABLE tarteel_mushaf.canonical_ayahs ADD COLUMN IF NOT EXISTS canonical_id text GENERATED ALWAYS AS ('hafs:' || verse_key) STORED;
CREATE UNIQUE INDEX IF NOT EXISTS canonical_hafs_identity_idx ON tarteel_mushaf.canonical_ayahs(canonical_id);
-- Existing verse_key primary/foreign keys stay valid for bookmarks and all layers.
REVOKE ALL ON tarteel_mushaf.canonical_ayahs FROM PUBLIC;
