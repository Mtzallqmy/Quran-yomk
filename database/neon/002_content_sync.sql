-- Additive migration; run after001 on an isolated branch before main.
ALTER TABLE tarteel_catalog.entities ADD COLUMN IF NOT EXISTS is_supplement boolean NOT NULL DEFAULT false;
ALTER TABLE tarteel_catalog.entities ADD COLUMN IF NOT EXISTS metadata jsonb NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE tarteel_catalog.sync_runs ADD COLUMN IF NOT EXISTS dead_links integer NOT NULL DEFAULT 0;
ALTER TABLE tarteel_catalog.sync_runs ADD COLUMN IF NOT EXISTS rights_rejected integer NOT NULL DEFAULT 0;
ALTER TABLE tarteel_catalog.sync_runs ADD COLUMN IF NOT EXISTS errors integer NOT NULL DEFAULT 0;
CREATE TABLE IF NOT EXISTS tarteel_catalog.identity_aliases(kind text NOT NULL,fingerprint text NOT NULL,entity_id bigint NOT NULL REFERENCES tarteel_catalog.entities(id),PRIMARY KEY(kind,fingerprint));
CREATE TABLE IF NOT EXISTS tarteel_catalog.api_budgets(principal text PRIMARY KEY,window_at timestamptz NOT NULL DEFAULT now(),requests integer NOT NULL DEFAULT 1);
CREATE INDEX IF NOT EXISTS catalog_kind_supplement_idx ON tarteel_catalog.entities(kind,is_supplement,id);
REVOKE ALL ON SCHEMA tarteel_catalog FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA tarteel_catalog FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA tarteel_catalog FROM PUBLIC;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='tarteel_catalog_reader') THEN CREATE ROLE tarteel_catalog_reader NOLOGIN; END IF;
END $$;
GRANT USAGE ON SCHEMA tarteel_catalog TO tarteel_catalog_reader;
CREATE OR REPLACE VIEW tarteel_catalog.public_catalog WITH(security_barrier=true) AS
 SELECT e.id,e.kind,e.title_ar,e.language_code,e.edition,e.metadata FROM tarteel_catalog.entities e WHERE e.is_supplement AND COALESCE(e.metadata->>'active','true')<>'false' AND EXISTS(SELECT 1 FROM tarteel_catalog.provider_items p WHERE p.entity_id=e.id AND p.usage_status='approved');
GRANT SELECT ON tarteel_catalog.public_catalog TO tarteel_catalog_reader;
GRANT tarteel_catalog_reader TO tarteel_owner;
