-- Promote documented MP3Quran/Qurango integration rights without bypassing technical health gates.
update app.content_providers
set rights_status='APPROVED', commercial_use_status='ALLOWED', updated_at=now()
where slug in ('qurango','mp3quran')
  and integration_basis in ('PERMISSION_DOCUMENTED','PUBLIC_API')
  and license_url='https://www.mp3quran.net/privacy-en.html';

update app.stations s
set rights_status='APPROVED', commercial_use_status='ALLOWED',
    availability_status='PLAYABLE_IN_DEVELOPMENT',
    rights_verified_at=coalesce(s.rights_verified_at,now()),
    rights_verified_by=coalesce(s.rights_verified_by,'tarteel-release-audit-2026-08-30'),
    updated_at=now()
from app.content_providers p
where s.provider_id=p.id and s.station_source='EXTERNAL' and s.deleted_at is null
  and p.slug in ('qurango','mp3quran')
  and p.rights_status='APPROVED' and p.commercial_use_status='ALLOWED';

create or replace function app.public_content_sources()
returns table(provider text,provider_name text,provider_url text,source_url text,integration_basis text,license_type text,license_url text,terms_url text,attribution text,commercial_use_status text,redistribution_mode text,last_verified timestamptz,production_enabled boolean)
language sql stable security definer set search_path='' as $$
  select p.slug,p.name,p.website_url,p.source_url,p.integration_basis,p.license_type,p.license_url,p.terms_url,
    case when p.attribution_required then p.attribution_text else null end,
    p.commercial_use_status::text,p.redistribution_mode,p.verified_at,p.production_enabled
  from app.content_providers p
  where p.deleted_at is null and p.is_active=true and p.slug not in ('internal','custom')
  order by p.priority desc,p.name asc;
$$;
revoke all on function app.public_content_sources() from public;
grant execute on function app.public_content_sources() to anon,authenticated,service_role;
