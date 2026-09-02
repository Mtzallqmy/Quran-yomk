-- Baseline repair for brand-new databases.
-- `20260830231340_islamic_radio_api_provider_sync.sql` is already deployed in
-- existing environments and must remain immutable. On a clean database the
-- provider type historically came from seed files, but seeds run only after
-- migrations. This idempotent prerequisite makes the historical migration
-- replayable without changing its deployed contents.
insert into app.content_provider_types(code, description)
values(
  'ISLAMIC_RADIO_API',
  'Islamic Radio API catalog; third-party stream rights are evaluated per station'
)
on conflict(code) do nothing;
