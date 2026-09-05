-- Phase 11: Islamic Radio API provider foundation.
-- Catalog metadata is CC0-1.0 as documented upstream. This statement does not
-- assert that the underlying third-party broadcasts/audio are CC0 or owned by Tarteel.

insert into app.content_provider_types(code,description)
values ('ISLAMIC_RADIO_API','Islamic Radio API public catalog')
on conflict(code) do nothing;

insert into app.content_providers(
  name,slug,provider_type,website_url,api_base_url,source_url,is_active,
  production_enabled,rights_status,commercial_use_status,attribution_required,
  attribution_text,terms_url,integration_basis,license_type,license_url,
  redistribution_mode,metadata
)
values(
  'Islamic Radio API','islamic-radio-api','ISLAMIC_RADIO_API',
  'https://github.com/uthumany/islamic-radio-api',
  'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json',
  'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json',
  true,false,'REVIEW_REQUIRED','UNKNOWN',true,
  'Islamic Radio API catalog; audio is streamed directly from the listed broadcaster/provider.',
  'https://github.com/uthumany/islamic-radio-api#license','PUBLIC_API',
  'CC0-1.0 API metadata only; third-party audio rights are not asserted',
  'https://github.com/uthumany/islamic-radio-api#license','DIRECT_EXTERNAL',
  jsonb_build_object(
    'repository','https://github.com/uthumany/islamic-radio-api',
    'catalog_path','client/public/api/stations.json'
  )
)
on conflict (slug) do update set
  name=excluded.name,
  provider_type=excluded.provider_type,
  website_url=excluded.website_url,
  api_base_url=excluded.api_base_url,
  source_url=excluded.source_url,
  attribution_required=excluded.attribution_required,
  attribution_text=excluded.attribution_text,
  terms_url=excluded.terms_url,
  integration_basis=excluded.integration_basis,
  license_type=excluded.license_type,
  license_url=excluded.license_url,
  redistribution_mode=excluded.redistribution_mode,
  metadata=app.content_providers.metadata || excluded.metadata,
  updated_at=now();

-- Synchronization is intentionally privileged. The implementation is finalized
-- in the next migration and is not granted to anon/authenticated roles.
