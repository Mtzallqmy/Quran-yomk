-- External radio licensing / provenance activation.
-- This migration records factual integration basis without claiming public-domain ownership.

alter table app.content_providers
  add column if not exists integration_basis text not null default 'REVIEW_REQUIRED',
  add column if not exists license_type text,
  add column if not exists license_url text,
  add column if not exists redistribution_mode text not null default 'DIRECT_EXTERNAL',
  add column if not exists verified_by text;

alter table app.stations
  add column if not exists integration_basis text not null default 'REVIEW_REQUIRED',
  add column if not exists license_type text,
  add column if not exists license_url text,
  add column if not exists redistribution_mode text not null default 'DIRECT_EXTERNAL',
  add column if not exists rights_verified_by text,
  add column if not exists availability_status text not null default 'REVIEW_REQUIRED';

do $$ begin
  alter table app.content_providers add constraint content_providers_integration_basis_check
    check (integration_basis in ('PUBLIC_API','PUBLIC_STREAM','PERMISSION_DOCUMENTED','LICENSE_VERIFIED','REVIEW_REQUIRED','RESTRICTED'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table app.content_providers add constraint content_providers_redistribution_mode_check
    check (redistribution_mode in ('DIRECT_EXTERNAL','PROVIDER_EMBED','RESTRICTED'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table app.stations add constraint stations_integration_basis_check
    check (integration_basis in ('PUBLIC_API','PUBLIC_STREAM','PERMISSION_DOCUMENTED','LICENSE_VERIFIED','REVIEW_REQUIRED','RESTRICTED'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table app.stations add constraint stations_redistribution_mode_check
    check (redistribution_mode in ('DIRECT_EXTERNAL','PROVIDER_EMBED','RESTRICTED'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table app.stations add constraint stations_availability_status_check
    check (availability_status in ('REVIEW_REQUIRED','PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE','DISABLED'));
exception when duplicate_object then null; end $$;

update app.content_providers set
  integration_basis='PERMISSION_DOCUMENTED', license_type='SITE_PERMISSION',
  license_url='https://www.mp3quran.net/privacy-en.html', terms_url='https://www.mp3quran.net/privacy-en.html',
  redistribution_mode='DIRECT_EXTERNAL', attribution_required=true, attribution_text='Qurango',
  verified_at=now(), verified_by='tarteel-release-audit-2026-08-30'
where slug='qurango';

update app.content_providers set
  integration_basis='PUBLIC_API', license_type='PUBLIC_DEVELOPER_API_AND_SITE_PERMISSION',
  license_url='https://www.mp3quran.net/privacy-en.html', terms_url='https://www.mp3quran.net/privacy-en.html',
  redistribution_mode='DIRECT_EXTERNAL', attribution_required=true, attribution_text='MP3Quran',
  verified_at=now(), verified_by='tarteel-release-audit-2026-08-30'
where slug='mp3quran';

update app.content_providers set
  integration_basis='PUBLIC_API', license_type='MP3QURAN_API_LINK_PERMISSION',
  license_url='https://www.mp3quran.net/privacy-en.html', terms_url='https://www.mp3quran.net/privacy-en.html',
  redistribution_mode='DIRECT_EXTERNAL', attribution_required=true, attribution_text='MP3Quran / Holol Live',
  verified_at=now(), verified_by='tarteel-release-audit-2026-08-30'
where slug='holol';

update app.content_providers set
  integration_basis='PUBLIC_STREAM', license_type='PUBLIC_STREAM_LINK',
  terms_url='https://support.radiojar.com/support/solutions/articles/5000014578-how-can-my-audience-listen-to-my-station-',
  redistribution_mode='DIRECT_EXTERNAL', attribution_required=true, attribution_text='Saudi Quran Radio / Radiojar',
  verified_at=now(), verified_by='tarteel-release-audit-2026-08-30'
where slug='radiojar';

update app.stations s set
  integration_basis=p.integration_basis, license_type=p.license_type, license_url=p.license_url,
  redistribution_mode=p.redistribution_mode, rights_verified_at=coalesce(s.rights_verified_at,p.verified_at),
  rights_verified_by=p.verified_by, attribution_required=p.attribution_required,
  attribution_text=coalesce(s.attribution_text,p.attribution_text), terms_url=coalesce(s.terms_url,p.terms_url),
  availability_status='PLAYABLE_IN_DEVELOPMENT'
from app.content_providers p
where s.provider_id=p.id and s.station_source='EXTERNAL' and s.deleted_at is null
  and p.slug in ('qurango','mp3quran','holol','radiojar');
