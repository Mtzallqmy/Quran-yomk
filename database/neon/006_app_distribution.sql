-- Public data-only distribution manifest. Does not grant content reuse rights.
CREATE TABLE IF NOT EXISTS tarteel_catalog.app_releases (
 application_id text NOT NULL CHECK(application_id='app.tarteel.tarteel'),
 version_code integer NOT NULL CHECK(version_code>2074),
 version_name text NOT NULL,
 architecture text NOT NULL CHECK(architecture='arm64-v8a'),
 minimum_sdk integer NOT NULL CHECK(minimum_sdk>=26),
 apk_url text NOT NULL CHECK(apk_url LIKE 'https://github.com/Mtzallqmy/Quran-yomk/releases/download/%'),
 apk_sha256 text NOT NULL CHECK(apk_sha256 ~ '^[a-f0-9]{64}$'),
 certificate_sha256 text NOT NULL CHECK(certificate_sha256 ~ '^[a-f0-9]{64}$'),
 channel text NOT NULL CHECK(channel='preview'),
 published_at timestamptz NOT NULL,
 PRIMARY KEY(application_id,version_code,architecture)
);
REVOKE ALL ON tarteel_catalog.app_releases FROM PUBLIC,tarteel_catalog_reader;
CREATE OR REPLACE VIEW tarteel_catalog.public_app_releases AS
 SELECT * FROM tarteel_catalog.app_releases;
GRANT SELECT ON tarteel_catalog.public_app_releases TO tarteel_catalog_reader;
INSERT INTO tarteel_catalog.app_releases VALUES (
 'app.tarteel.tarteel',2094,'0.9.2-beta.2','arm64-v8a',26,
 'https://github.com/Mtzallqmy/Quran-yomk/releases/download/v0.9.2-beta.2-preview.2094/Tarteel-0.9.2-beta.2-2094-ARM64-PREVIEW.apk',
 '18f7103c3ef8efde6577872e6ee5cacfe5788cf80a43949fa7e8023e0e050429',
 '5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8',
 'preview','2026-10-25T13:09:47Z'
) ON CONFLICT DO NOTHING;
