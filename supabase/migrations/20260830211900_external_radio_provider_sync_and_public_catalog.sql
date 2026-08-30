create extension if not exists http with schema extensions;

create or replace function app.external_stream_canonical(p_url text)
returns text language sql immutable strict set search_path='' as $$
  select regexp_replace(regexp_replace(lower(trim(p_url)), '^https?://', ''), '/+$', '');
$$;
revoke all on function app.external_stream_canonical(text) from public;
grant execute on function app.external_stream_canonical(text) to service_role;

create or replace function app.external_station_category_slug(p_name text,p_url text)
returns text language sql immutable set search_path='' as $$
  select case
    when coalesce(p_name,'') ~* '(ترجم|translation|باللغة)' or coalesce(p_url,'') ~* 'translation|mokhtasr-(english|french|urdo|grgstan|husa)|farsi-(trans|tadabor)' then 'QURAN_TRANSLATION'
    when coalesce(p_name,'') ~* '(تفسير|غريب القرآن|الطبري)' or coalesce(p_url,'') ~* 'tafseer|tafsir|tabri|gareeb-quran' then 'TAFSEER'
    when coalesce(p_name,'') ~* '(البخاري|مسلم|رياض الصالحين|حديث)' or coalesce(p_url,'') ~* 'bokharee|muslim|riyad' then 'HADITH'
    when coalesce(p_name,'') ~* '(السيرة|الأنبياء)' or coalesce(p_url,'') ~* 'alsiyra|alanbiya' then 'SEERAH'
    when coalesce(p_name,'') ~* '(الصحابة)' or coalesce(p_url,'') ~* 'sahabah' then 'SAHABAH'
    when coalesce(p_name,'') ~* '(أذكار)' or coalesce(p_url,'') ~* 'athkar' then 'ADHKAR'
    when coalesce(p_name,'') ~* '(رقية)' or coalesce(p_url,'') ~* 'roqiah' then 'RUQYAH'
    when coalesce(p_name,'') ~* '(فتاوى|الفتاوى)' or coalesce(p_url,'') ~* 'fatwa' then 'FATWA'
    when coalesce(p_name,'') ~* '(سورة )' or coalesce(p_url,'') ~* 'albaqarah|surah_' then 'QURAN_SURAH'
    when coalesce(p_name,'') ~* '(إذاعة|الإذاعة|تلاوات|تراتيل|السكينة|تكبيرات|شوال|ذي الحجة)' then 'QURAN_GENERAL'
    else 'RECITER'
  end;
$$;
revoke all on function app.external_station_category_slug(text,text) from public;
grant execute on function app.external_station_category_slug(text,text) to service_role;

create or replace function app.sync_mp3quran_radios()
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_provider app.content_providers%rowtype; v_run_id uuid; v_response extensions.http_response; v_payload jsonb; v_radios jsonb; v_item jsonb;
  v_external_key text; v_name text; v_url text; v_canonical text; v_station_id uuid; v_category_id uuid; v_category_slug text; v_stream_type text;
  v_created int:=0; v_updated int:=0; v_unchanged int:=0; v_invalid int:=0; v_fetched int:=0; v_missing int:=0;
begin
  select * into v_provider from app.content_providers where slug='mp3quran' and deleted_at is null limit 1;
  if v_provider.id is null then raise exception 'MP3Quran provider is missing'; end if;
  insert into app.provider_sync_runs(provider_id,idempotency_key,status,started_at,metadata)
  values(v_provider.id,'mp3quran:'||clock_timestamp()::text,'RUNNING',now(),jsonb_build_object('source','https://www.mp3quran.net/api/v3/radios?language=ar')) returning id into v_run_id;
  begin
    v_response:=extensions.http_get('https://www.mp3quran.net/api/v3/radios?language=ar');
    if v_response.status<200 or v_response.status>=300 then raise exception 'MP3Quran API returned HTTP %',v_response.status; end if;
    v_payload:=v_response.content::jsonb; v_radios:=coalesce(v_payload->'radios',v_payload->'Radios','[]'::jsonb);
    if jsonb_typeof(v_radios)<>'array' then raise exception 'MP3Quran payload did not contain a radio array'; end if;
    create temporary table if not exists pg_temp.mp3quran_seen(external_key text primary key) on commit drop; truncate pg_temp.mp3quran_seen;
    for v_item in select value from jsonb_array_elements(v_radios) loop
      v_fetched:=v_fetched+1; v_external_key:=nullif(trim(coalesce(v_item->>'id',v_item->>'Id')),'');
      v_name:=nullif(trim(coalesce(v_item->>'name',v_item->>'Name')),''); v_url:=nullif(trim(coalesce(v_item->>'url',v_item->>'URL')),'');
      if v_external_key is null or v_name is null or v_url is null or v_url !~* '^https?://' then v_invalid:=v_invalid+1; continue; end if;
      insert into pg_temp.mp3quran_seen values(v_external_key) on conflict do nothing; v_canonical:=app.external_stream_canonical(v_url); v_station_id:=null;
      select psr.station_id into v_station_id from app.provider_station_records psr where psr.provider_id=v_provider.id and psr.external_key=v_external_key limit 1;
      if v_station_id is null then
        select s.id into v_station_id from app.stations s where s.deleted_at is null and s.station_source='EXTERNAL' and app.external_stream_canonical(s.stream_url)=v_canonical order by s.created_at limit 1;
      end if;
      if v_station_id is null then
        v_category_slug:=app.external_station_category_slug(v_name,v_url); select c.id into v_category_id from app.categories c where c.slug=v_category_slug and c.deleted_at is null limit 1;
        if v_category_id is null then select c.id into v_category_id from app.categories c where c.slug='OTHER' and c.deleted_at is null limit 1; end if;
        v_stream_type:=case when v_url ~* '\.m3u8([?#].*)?$' then 'HLS' when v_url ~* '(^|//)(backup\.)?qurango\.net/radio/' then 'SHOUTCAST' else 'UNKNOWN_STREAM' end;
        insert into app.stations(provider_id,category_id,slug,name_ar,name_en,search_name_ar,search_name_en,station_source,stream_type,stream_url,source_url,is_active,production_enabled,health_status,rights_status,commercial_use_status,attribution_required,attribution_text,terms_url,integration_basis,license_type,license_url,redistribution_mode,rights_verified_at,rights_verified_by,availability_status,metadata,last_seen_at)
        values(v_provider.id,v_category_id,'mp3quran-radio-'||regexp_replace(v_external_key,'[^a-zA-Z0-9_-]+','-','g'),v_name,null,v_name,lower(v_name),'EXTERNAL',v_stream_type,v_url,'https://www.mp3quran.net/api/v3/radios?language=ar',true,false,'UNKNOWN','APPROVED','ALLOWED',true,'MP3Quran','https://www.mp3quran.net/privacy-en.html','PUBLIC_API','PUBLIC_DEVELOPER_API_AND_SITE_PERMISSION','https://www.mp3quran.net/privacy-en.html','DIRECT_EXTERNAL',now(),'tarteel-provider-sync','REVIEW_REQUIRED',jsonb_build_object('provider_external_id',v_external_key,'provider_payload',v_item),now()) returning id into v_station_id;
        v_created:=v_created+1;
      else v_unchanged:=v_unchanged+1; end if;
      insert into app.provider_station_records(provider_id,station_id,external_key,discovered_name,discovered_stream_url,normalized_hash,last_seen_at,missing_since,raw_metadata)
      values(v_provider.id,v_station_id,v_external_key,v_name,v_url,encode(extensions.digest(v_canonical,'sha256'),'hex'),now(),null,v_item)
      on conflict(provider_id,external_key) do update set station_id=excluded.station_id,discovered_name=excluded.discovered_name,discovered_stream_url=excluded.discovered_stream_url,normalized_hash=excluded.normalized_hash,last_seen_at=excluded.last_seen_at,missing_since=null,raw_metadata=excluded.raw_metadata,updated_at=now();
      v_updated:=v_updated+1;
    end loop;
    update app.provider_station_records psr set missing_since=coalesce(psr.missing_since,now()),updated_at=now() where psr.provider_id=v_provider.id and not exists(select 1 from pg_temp.mp3quran_seen x where x.external_key=psr.external_key); get diagnostics v_missing=row_count;
    update app.content_providers set last_checked_at=now(),last_success_at=now(),health_status='HEALTHY',updated_at=now() where id=v_provider.id;
    update app.provider_sync_runs set status='COMPLETED',finished_at=now(),fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_unchanged,missing_count=v_missing,invalid_count=v_invalid,metadata=metadata||jsonb_build_object('http_status',v_response.status) where id=v_run_id;
    return jsonb_build_object('run_id',v_run_id,'fetched',v_fetched,'created',v_created,'updated',v_updated,'unchanged',v_unchanged,'missing',v_missing,'invalid',v_invalid);
  exception when others then
    update app.provider_sync_runs set status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message=sqlerrm,fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_unchanged,missing_count=v_missing,invalid_count=v_invalid where id=v_run_id; raise;
  end;
end;
$$;
revoke all on function app.sync_mp3quran_radios() from public,anon,authenticated;
grant execute on function app.sync_mp3quran_radios() to service_role;

create or replace function app.public_station_catalog(p_environment text default 'production',p_source text default null,p_category text default null,p_provider text default null,p_search text default null,p_limit integer default 100,p_offset integer default 0)
returns table(id uuid,slug text,name_ar text,name_en text,description text,logo_url text,category_id uuid,category text,station_source text,stream_type text,playback_url text,timezone text,status text,health_status text,is_featured boolean,provider text,provider_name text,integration_basis text,attribution text,terms_url text,license_url text,availability_status text)
language sql stable security definer set search_path='' as $$
  select s.id,s.slug,s.name_ar,s.name_en,s.description,s.logo_url,s.category_id,c.slug,s.station_source::text,s.stream_type,case when s.station_source='EXTERNAL' then s.stream_url else null end,s.timezone,s.status::text,s.health_status::text,s.is_featured,p.slug,p.name,s.integration_basis,case when s.attribution_required then s.attribution_text else null end,s.terms_url,s.license_url,s.availability_status
  from app.stations s left join app.categories c on c.id=s.category_id left join app.content_providers p on p.id=s.provider_id
  where s.deleted_at is null and s.is_active=true
    and (p_source is null or s.station_source::text=upper(p_source)) and (p_category is null or c.slug=upper(p_category)) and (p_provider is null or p.slug=lower(p_provider))
    and (p_search is null or p_search='' or s.name_ar ilike '%'||p_search||'%' or coalesce(s.name_en,'') ilike '%'||p_search||'%')
    and ((s.station_source='INTERNAL' and (lower(p_environment)='development' or s.production_enabled=true)) or (s.station_source='EXTERNAL' and (((lower(p_environment)='development') and s.availability_status in ('PLAYABLE_IN_DEVELOPMENT','APPROVED_FOR_PUBLIC_RELEASE') and s.health_status in ('HEALTHY','DEGRADED')) or (lower(p_environment)<>'development' and s.availability_status='APPROVED_FOR_PUBLIC_RELEASE' and s.production_enabled=true and s.rights_status='APPROVED' and s.commercial_use_status='ALLOWED'))))
  order by s.sort_order,s.name_ar limit greatest(1,least(coalesce(p_limit,100),200)) offset greatest(coalesce(p_offset,0),0);
$$;
revoke all on function app.public_station_catalog(text,text,text,text,text,integer,integer) from public;
grant execute on function app.public_station_catalog(text,text,text,text,text,integer,integer) to anon,authenticated,service_role;
