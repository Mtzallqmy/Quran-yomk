-- EXPERIMENT ONLY: apply to isolated Neon branch, not production.
-- Read-only, security-barrier public projections over approved pinned datasets.
-- Keep Quran words and licensed tafsir bodies out of this API.
CREATE OR REPLACE VIEW tarteel_mushaf.public_ayah_positions
WITH (security_barrier = true) AS
SELECT p.edition_id,p.page,p.verse_key,p.source_bounds
FROM tarteel_mushaf.mushaf_ayah_positions p
JOIN tarteel_mushaf.public_editions e ON e.id = p.edition_id
WHERE e.rights_status = 'approved';

CREATE OR REPLACE VIEW tarteel_mushaf.public_thematic_sections
WITH (security_barrier = true) AS
SELECT s.id,s.title_ar,s.source_id
FROM tarteel_mushaf.thematic_sections s
WHERE EXISTS (
  SELECT 1 FROM tarteel_mushaf.mushaf_licenses l
  WHERE l.source_id = s.source_id AND l.status = 'approved'
);

CREATE OR REPLACE VIEW tarteel_mushaf.public_thematic_ayahs
WITH (security_barrier = true) AS
SELECT r.section_id,r.verse_key
FROM tarteel_mushaf.thematic_ayah_ranges r
JOIN tarteel_mushaf.public_thematic_sections s ON s.id = r.section_id;

GRANT SELECT ON tarteel_mushaf.public_ayah_positions,
  tarteel_mushaf.public_thematic_sections,
  tarteel_mushaf.public_thematic_ayahs TO tarteel_catalog_reader;
