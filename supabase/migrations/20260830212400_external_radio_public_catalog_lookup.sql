drop function if exists app.public_station_catalog(text,text,text,text,text,integer,integer);
create or replace function app.public_station_catalog(p_environment text default 'production',p_source text default null,p_category text default null,p_provider text default null,p_search text default null,p_limit integer default 100,p_offset integer default 0,p_slug text default null)
returns table(id uuid,slug text,name_ar text,name_en text,description text,logo_url text,category_id uuid,category text,station_source text,stream_type text,playback_url text,timezone text,status text,health_status text,is_featured boolean,provider text,provider_name text,integration_basis text,attribution text,terms_url text,license_url text,availability_status text)
language sql stable security definer set search_path='' as $$
  select s.id,s.slug,s.name_ar,s.name_en,s.description,s.logo_url,s.category_id,c.slug,s.station_source::text,s.stream_type,case when s.station_source='EXTERNAL' then s.stream_url else null end,s.timezone,s.status::text,s.health_status::text,s.is_featured,p.slug,p.name,s.integration_basis,case when s.attribution_required then s.attribution_text else null end,s.terms_url,s.license_url,s.availability_status
  from app.stations s left join app.categories c on c.id=s.category_id left join app.content_providers p on p.id=s.provider_id
  where s.deleted_at is null and s.is_active=true
    and (p_slug is null or s.slug=p_slug)
    and (p_source is null or s.station_source::text=upper(p_source)) and (p_category is null or c.slug=upper(p_category)) and (p_provider is null or p.slug=lower(p_provider))
    and (p_search is null or p_search='' or s.name_ar ilike '%'||p_search||'%' or coalesce(s.name_en,'') ilike '%'||p_search||'%')
    and ((s.station_source='INTERNAL' and (lower(p_environment)='development' or s.production_enabled=true)) or (s.station_source='EXTERNAL' and (((lower(p_environment)='development') and s.availability_status in ('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE') and s.health_status in ('HEALTHY','DEGRADED')) or (lower(p_environment)<>'development' and s.availability_status='APPROVED_FOR_PUBLIC_RELEASE' and s.production_enabled=true and s.rights_status='APPROVED' and s.commercial_use_status='ALLOWED'))))
  order by s.sort_order,s.name_ar limit greatest(1,least(coalesce(p_limit,100),200)) offset greatest(coalesce(p_offset,0),0);
$$;
revoke all on function app.public_station_catalog(text,text,text,text,text,integer,integer,text) from public;
grant execute on function app.public_station_catalog(text,text,text,text,text,integer,integer,text) to anon,authenticated,service_role;
