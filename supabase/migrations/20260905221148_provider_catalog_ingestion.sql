-- Provider HTTP runs in the bounded server transport; SQL only ingests validated catalogs.


create or replace function app.sync_mp3quran_radios_payload(p_payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_provider app.content_providers%rowtype; v_run_id uuid; v_response extensions.http_response; v_payload jsonb; v_radios jsonb; v_item jsonb;
  v_external_key text; v_name text; v_url text; v_canonical text; v_station_id uuid; v_category_id uuid; v_category_slug text; v_stream_type text;
  v_created int:=0; v_updated int:=0; v_unchanged int:=0; v_invalid int:=0; v_fetched int:=0; v_missing int:=0;
begin

  if jsonb_typeof(coalesce(p_payload->'radios',p_payload->'Radios')) is distinct from 'array' then raise exception 'Invalid provider catalog'; end if;
  if jsonb_array_length(coalesce(p_payload->'radios',p_payload->'Radios')) = 0 or octet_length(p_payload::text) > 5242880 then raise exception 'Invalid provider catalog size'; end if;
  select * into v_provider from app.content_providers where slug='mp3quran' and deleted_at is null limit 1;
  if v_provider.id is null then raise exception 'MP3Quran provider is missing'; end if;
  insert into app.provider_sync_runs(provider_id,idempotency_key,status,started_at,metadata)
  values(v_provider.id,'mp3quran:'||clock_timestamp()::text,'RUNNING',now(),jsonb_build_object('source','https://www.mp3quran.net/api/v3/radios?language=ar')) returning id into v_run_id;
  begin
    v_response.status := 200; v_response.content := p_payload::text;
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
    if v_invalid = v_fetched then raise exception 'Provider catalog has no valid stations'; end if;
    update app.provider_station_records psr set missing_since=coalesce(psr.missing_since,now()),updated_at=now() where psr.provider_id=v_provider.id and not exists(select 1 from pg_temp.mp3quran_seen x where x.external_key=psr.external_key); get diagnostics v_missing=row_count;
    update app.content_providers set last_checked_at=now(),last_success_at=now(),health_status='HEALTHY',updated_at=now() where id=v_provider.id;
    update app.provider_sync_runs set status='COMPLETED',finished_at=now(),fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_unchanged,missing_count=v_missing,invalid_count=v_invalid,metadata=metadata||jsonb_build_object('http_status',v_response.status) where id=v_run_id;
    return jsonb_build_object('run_id',v_run_id,'fetched',v_fetched,'created',v_created,'updated',v_updated,'unchanged',v_unchanged,'missing',v_missing,'invalid',v_invalid);
  exception when others then
    update app.provider_sync_runs set status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message='Provider ingestion failed',fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_unchanged,missing_count=v_missing,invalid_count=v_invalid where id=v_run_id; raise;
  end;
end;
$$;

revoke all on function app.sync_mp3quran_radios_payload(jsonb) from public,anon,authenticated;
grant execute on function app.sync_mp3quran_radios_payload(jsonb) to service_role;

create or replace function app.sync_mp3quran_radios() returns jsonb language plpgsql security invoker set search_path='' as $$ begin raise exception 'Provider sync requires protected server ingestion' using errcode='55000'; end; $$;
revoke all on function app.sync_mp3quran_radios() from public,anon,authenticated;
grant execute on function app.sync_mp3quran_radios() to service_role;

create or replace function app.sync_islamic_radio_api_stations_payload(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_provider app.content_providers%rowtype;
  v_run_id uuid;
  v_response extensions.http_response;
  v_payload jsonb;
  v_items jsonb;
  v_item jsonb;
  v_external_key text;
  v_name_ar text;
  v_name_en text;
  v_description text;
  v_url text;
  v_canonical text;
  v_station_id uuid;
  v_category_id uuid;
  v_category_slug text;
  v_stream_type text;
  v_format text;
  v_genres text;
  v_source_active boolean;
  v_created int := 0;
  v_linked int := 0;
  v_updated int := 0;
  v_invalid int := 0;
  v_fetched int := 0;
  v_missing int := 0;
begin

  if jsonb_typeof(p_payload->'stations') is distinct from 'array' then raise exception 'Invalid provider catalog'; end if;
  if jsonb_array_length(p_payload->'stations') = 0 or octet_length(p_payload::text) > 5242880 then raise exception 'Invalid provider catalog size'; end if;
  select * into v_provider
  from app.content_providers
  where slug='islamic-radio-api' and deleted_at is null
  limit 1;
  if v_provider.id is null then
    raise exception 'Islamic Radio API provider is missing';
  end if;

  insert into app.provider_sync_runs(provider_id,idempotency_key,status,started_at,metadata)
  values(v_provider.id,'islamic-radio-api:'||clock_timestamp()::text,'RUNNING',now(),jsonb_build_object('source',v_provider.source_url))
  returning id into v_run_id;

  begin
    v_response.status := 200; v_response.content := p_payload::text;
    if v_response.status < 200 or v_response.status >= 300 then
      raise exception 'Islamic Radio API returned HTTP %', v_response.status;
    end if;
    v_payload := v_response.content::jsonb;
    v_items := coalesce(v_payload->'stations','[]'::jsonb);
    if jsonb_typeof(v_items) <> 'array' then
      raise exception 'Islamic Radio API payload did not contain stations array';
    end if;

    create temporary table if not exists pg_temp.islamic_radio_seen(
      external_key text primary key
    ) on commit drop;
    truncate pg_temp.islamic_radio_seen;

    for v_item in select value from jsonb_array_elements(v_items)
    loop
      v_fetched := v_fetched + 1;
      v_external_key := nullif(trim(v_item->>'id'),'');
      v_name_en := nullif(trim(v_item->>'name'),'');
      v_name_ar := nullif(trim(v_item->>'nameAr'),'');
      v_description := nullif(trim(v_item->>'description'),'');
      v_url := nullif(trim(v_item->>'streamUrl'),'');
      v_format := lower(coalesce(nullif(trim(v_item->>'streamFormat'),''),'unknown'));
      v_genres := lower(coalesce(v_item->'genre','[]'::jsonb)::text || ' ' || coalesce(v_name_ar,'') || ' ' || coalesce(v_name_en,''));
      v_source_active := lower(coalesce(v_item->>'status',''))='active';

      if v_external_key is null or coalesce(v_name_ar,v_name_en) is null
         or v_url is null or v_url !~* '^https?://' then
        v_invalid := v_invalid + 1;
        continue;
      end if;

      insert into pg_temp.islamic_radio_seen(external_key)
      values(v_external_key) on conflict do nothing;
      v_canonical := app.external_stream_canonical(v_url);
      v_station_id := null;

      select psr.station_id into v_station_id
      from app.provider_station_records psr
      where psr.provider_id=v_provider.id and psr.external_key=v_external_key
      limit 1;

      if v_station_id is null then
        select s.id into v_station_id
        from app.stations s
        where s.deleted_at is null
          and s.station_source='EXTERNAL'
          and app.external_stream_canonical(s.stream_url)=v_canonical
        order by s.created_at asc
        limit 1;
      end if;

      v_category_slug := case
        when v_genres ~ '(tafseer|tafsir|تفسير)' then 'TAFSEER'
        when v_genres ~ '(hadith|حديث|bukhari|muslim)' then 'HADITH'
        when v_genres ~ '(seerah|sira|سيرة)' then 'SEERAH'
        when v_genres ~ '(adhkar|athkar|أذكار)' then 'ADHKAR'
        when v_genres ~ '(ruqyah|roqiah|رقية)' then 'RUQYAH'
        when v_genres ~ '(fatwa|فتاوى)' then 'FATWA'
        when v_genres ~ '(translation|ترجم)' then 'QURAN_TRANSLATION'
        when v_genres ~ '(recitation|reciter|قارئ|الشيخ|quran radio —)' then 'RECITER'
        else app.external_station_category_slug(coalesce(v_name_ar,v_name_en),v_url)
      end;
      select c.id into v_category_id from app.categories c where c.slug=v_category_slug and c.deleted_at is null limit 1;
      if v_category_id is null then
        select c.id into v_category_id from app.categories c where c.slug='OTHER' and c.deleted_at is null limit 1;
      end if;

      v_stream_type := case
        when v_url ~* '\.m3u8([?#].*)?$' or v_format in ('hls','m3u8') then 'HLS'
        when v_format in ('mp3','mpeg','audio/mpeg') then 'MP3_STREAM'
        when v_format in ('aac','aacp','audio/aac') then 'AAC_STREAM'
        when v_format='icecast' then 'ICECAST'
        when v_format='shoutcast' then 'SHOUTCAST'
        when v_url ~* '(^|//)(backup\.)?qurango\.net/radio/' then 'SHOUTCAST'
        else 'UNKNOWN_STREAM'
      end;

      if v_station_id is null then
        insert into app.stations(
          provider_id,category_id,slug,name_ar,name_en,search_name_ar,search_name_en,
          station_source,stream_type,stream_url,source_url,description,logo_url,
          is_active,production_enabled,status,health_status,rights_status,
          commercial_use_status,attribution_required,attribution_text,terms_url,
          integration_basis,license_type,license_url,redistribution_mode,
          availability_status,external_key,last_seen_at,metadata
        ) values(
          v_provider.id,v_category_id,
          'islamic-radio-'||regexp_replace(lower(v_external_key),'[^a-z0-9]+','-','g'),
          coalesce(v_name_ar,v_name_en),v_name_en,coalesce(v_name_ar,v_name_en),lower(coalesce(v_name_en,v_name_ar)),
          'EXTERNAL'::app.station_source,v_stream_type,v_url,v_provider.source_url,v_description,nullif(v_item->>'img',''),
          true,false,
          case when v_source_active then 'DEGRADED'::app.station_status else 'OFFLINE'::app.station_status end,
          case when v_source_active then 'DEGRADED'::app.stream_health_status else 'UNKNOWN'::app.stream_health_status end,
          'REVIEW_REQUIRED'::app.rights_status,'UNKNOWN'::app.commercial_use_status,true,
          'Islamic Radio API catalog; broadcast/audio rights remain with the original broadcaster/provider.',
          v_provider.terms_url,'PUBLIC_API',v_provider.license_type,v_provider.license_url,'DIRECT_EXTERNAL',
          case when v_source_active then 'PLAYABLE_IN_DEVELOPMENT' else 'REVIEW_REQUIRED' end,
          v_external_key,now(),
          jsonb_build_object(
            'provider_external_id',v_external_key,
            'provider_status',v_item->>'status',
            'provider_last_checked',v_item->>'lastChecked',
            'country',v_item->>'country','language',v_item->>'language',
            'genre',coalesce(v_item->'genre','[]'::jsonb),
            'website',v_item->>'website','bitrate',v_item->>'bitrate',
            'frequency',v_item->>'frequency','provider_payload',v_item
          )
        ) returning id into v_station_id;
        v_created := v_created + 1;
      else
        update app.stations s set
          category_id=coalesce(s.category_id,v_category_id),
          logo_url=coalesce(s.logo_url,nullif(v_item->>'img','')),
          description=coalesce(s.description,v_description),
          stream_type=case when s.stream_type='UNKNOWN_STREAM' then v_stream_type else s.stream_type end,
          health_status=case when v_source_active and s.health_status='UNKNOWN' then 'DEGRADED'::app.stream_health_status else s.health_status end,
          status=case when v_source_active and s.status='OFFLINE' and s.station_source='EXTERNAL' then 'DEGRADED'::app.station_status else s.status end,
          availability_status=case when v_source_active and s.station_source='EXTERNAL' and s.availability_status='REVIEW_REQUIRED' then 'PLAYABLE_IN_DEVELOPMENT' else s.availability_status end,
          last_seen_at=now(),
          metadata=s.metadata || jsonb_build_object(
            'islamic_radio_api_external_id',v_external_key,
            'islamic_radio_api_status',v_item->>'status',
            'islamic_radio_api_last_checked',v_item->>'lastChecked'
          ),
          updated_at=now()
        where s.id=v_station_id;
        v_linked := v_linked + 1;
      end if;

      insert into app.provider_station_records(
        provider_id,station_id,external_key,discovered_name,discovered_stream_url,
        normalized_hash,last_seen_at,missing_since,raw_metadata
      ) values(
        v_provider.id,v_station_id,v_external_key,coalesce(v_name_ar,v_name_en),v_url,
        encode(extensions.digest(v_canonical,'sha256'),'hex'),now(),null,v_item
      )
      on conflict (provider_id,external_key) do update set
        station_id=excluded.station_id,
        discovered_name=excluded.discovered_name,
        discovered_stream_url=excluded.discovered_stream_url,
        normalized_hash=excluded.normalized_hash,
        last_seen_at=excluded.last_seen_at,
        missing_since=null,
        raw_metadata=excluded.raw_metadata,
        updated_at=now();
      v_updated := v_updated + 1;
    end loop;
    if v_invalid = v_fetched then raise exception 'Provider catalog has no valid stations'; end if;

    update app.provider_station_records psr
    set missing_since=coalesce(psr.missing_since,now()),updated_at=now()
    where psr.provider_id=v_provider.id
      and not exists(select 1 from pg_temp.islamic_radio_seen x where x.external_key=psr.external_key);
    get diagnostics v_missing = row_count;

    update app.content_providers set
      last_checked_at=now(),last_success_at=now(),health_status='HEALTHY',updated_at=now(),
      metadata=metadata || jsonb_build_object(
        'catalog_version',v_payload->>'version',
        'catalog_timestamp',v_payload->>'timestamp',
        'catalog_total',v_payload->'total'
      )
    where id=v_provider.id;

    update app.provider_sync_runs set
      status='COMPLETED',finished_at=now(),fetched_count=v_fetched,
      inserted_count=v_created,updated_count=v_updated,unchanged_count=v_linked,
      missing_count=v_missing,invalid_count=v_invalid,
      metadata=metadata || jsonb_build_object('http_status',v_response.status,'catalog_version',v_payload->>'version')
    where id=v_run_id;

    return jsonb_build_object(
      'run_id',v_run_id,'fetched',v_fetched,'created',v_created,
      'linked_existing',v_linked,'provider_records_upserted',v_updated,
      'missing',v_missing,'invalid',v_invalid,'catalog_version',v_payload->>'version'
    );
  exception when others then
    update app.provider_sync_runs set
      status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message='Provider ingestion failed',
      fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,
      unchanged_count=v_linked,missing_count=v_missing,invalid_count=v_invalid
    where id=v_run_id;
    raise;
  end;
end;
$$;

revoke all on function app.sync_islamic_radio_api_stations_payload(jsonb) from public,anon,authenticated;
grant execute on function app.sync_islamic_radio_api_stations_payload(jsonb) to service_role;

create or replace function app.sync_islamic_radio_api_stations() returns jsonb language plpgsql security invoker set search_path='' as $$ begin raise exception 'Provider sync requires protected server ingestion' using errcode='55000'; end; $$;
revoke all on function app.sync_islamic_radio_api_stations() from public,anon,authenticated;
grant execute on function app.sync_islamic_radio_api_stations() to service_role;

create or replace function app.sync_islamic_app_radio_stations_payload(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=''
as $$
declare
  v_provider app.content_providers%rowtype;
  v_run_id uuid;
  v_response extensions.http_response;
  v_health_response extensions.http_response;
  v_payload jsonb;
  v_items jsonb;
  v_item jsonb;
  v_external_key text;
  v_name text;
  v_url text;
  v_direct_url text;
  v_proxy_url text;
  v_canonical text;
  v_identity text;
  v_station_id uuid;
  v_category_id uuid;
  v_category_slug text;
  v_stream_type text;
  v_tags text;
  v_online boolean;
  v_created int:=0;
  v_reused int:=0;
  v_updated int:=0;
  v_invalid int:=0;
  v_received int:=0;
  v_missing int:=0;
  v_http_only int:=0;
  v_duplicate_by_url int:=0;
  v_duplicate_by_identity int:=0;
  v_api_healthy boolean:=false;
begin

  if jsonb_typeof(p_payload#>'{data,stations}') is distinct from 'array' then raise exception 'Invalid provider catalog'; end if;
  if jsonb_array_length(p_payload#>'{data,stations}') = 0 or octet_length(p_payload::text) > 5242880 then raise exception 'Invalid provider catalog size'; end if;
  select * into v_provider from app.content_providers
  where slug='islamic-app' and deleted_at is null limit 1;
  if v_provider.id is null then raise exception 'islamic.app provider missing'; end if;

  insert into app.provider_sync_runs(provider_id,idempotency_key,status,started_at,metadata)
  values(v_provider.id,'islamic-app:'||clock_timestamp()::text,'RUNNING',now(),
    jsonb_build_object('source',v_provider.source_url))
  returning id into v_run_id;

  begin
    v_health_response.status := case when p_payload->>'_tarteel_api_healthy'='true' then 200 else 503 end;
    v_api_healthy := v_health_response.status between 200 and 299;
    v_response.status := 200; v_response.content := p_payload::text;
    if v_response.status < 200 or v_response.status >= 300 then
      raise exception 'islamic.app returned HTTP %',v_response.status;
    end if;
    v_payload := v_response.content::jsonb;
    v_items := coalesce(v_payload#>'{data,stations}','[]'::jsonb);
    if jsonb_typeof(v_items)<>'array' then raise exception 'islamic.app payload missing data.stations'; end if;

    create temporary table if not exists pg_temp.islamic_app_seen(external_key text primary key) on commit drop;
    truncate pg_temp.islamic_app_seen;

    for v_item in select value from jsonb_array_elements(v_items)
    loop
      v_received:=v_received+1;
      v_external_key:=nullif(trim(v_item->>'slug'),'');
      v_name:=nullif(trim(v_item->>'name'),'');
      v_direct_url:=nullif(trim(v_item->>'streamUrl'),'');
      v_proxy_url:=nullif(trim(v_item->>'streamProxyUrl'),'');
      v_url:=coalesce(v_direct_url,v_proxy_url);
      v_online:=coalesce((v_item->>'online')::boolean,false);
      v_tags:=lower(coalesce(v_item->'tags','[]'::jsonb)::text||' '||coalesce(v_name,''));
      if v_external_key is null or v_name is null or v_url is null or v_url !~* '^https?://' then
        v_invalid:=v_invalid+1; continue;
      end if;
      if v_url ~* '^http://' then v_http_only:=v_http_only+1; end if;
      insert into pg_temp.islamic_app_seen(external_key) values(v_external_key) on conflict do nothing;
      v_canonical:=app.external_stream_canonical(v_url);
      v_identity:=app.external_station_identity(v_name);
      v_station_id:=null;

      select psr.station_id into v_station_id
      from app.provider_station_records psr
      where psr.provider_id=v_provider.id and psr.external_key=v_external_key limit 1;

      if v_station_id is null and v_direct_url is not null then
        select s.id into v_station_id
        from app.stations s
        where s.deleted_at is null and s.station_source='EXTERNAL'
          and app.external_stream_canonical(s.stream_url)=app.external_stream_canonical(v_direct_url)
        order by s.created_at asc limit 1;
        if v_station_id is not null then v_duplicate_by_url:=v_duplicate_by_url+1; end if;
      end if;

      v_category_slug:=case
        when v_tags ~ '(ruqya|roqia|رقية)' then 'RUQYAH'
        when v_tags ~ '(fatwa|فتاوى)' then 'FATWA'
        when v_tags ~ '(hadith|sunnah|حديث|رياض الصالحين)' then 'HADITH'
        when v_tags ~ '(sahabah|صحابة)' then 'SAHABAH'
        when v_tags ~ '(sirah|seerah|sira|سيرة)' then 'SEERAH'
        when v_tags ~ '(tafsir|tafseer|تفسير|شعراوي)' then 'TAFSEER'
        when v_tags ~ '(adhkar|athkar|dhikr|أذكار)' then 'ADHKAR'
        when v_tags ~ '(translation|ترجم)' then 'QURAN_TRANSLATION'
        when v_tags ~ '(quran|recitation|قرآن|تلاو)' then 'QURAN_GENERAL'
        else 'OTHER'
      end;
      select id into v_category_id from app.categories
      where slug=v_category_slug and deleted_at is null limit 1;
      if v_category_id is null then
        select id into v_category_id from app.categories where slug='OTHER' and deleted_at is null limit 1;
      end if;

      if v_station_id is null then
        select s.id into v_station_id
        from app.stations s
        left join app.categories c on c.id=s.category_id
        where s.deleted_at is null and s.station_source='EXTERNAL'
          and app.external_station_identity(coalesce(s.name_en,s.name_ar))=v_identity
          and coalesce(c.slug,'OTHER')=v_category_slug
        order by s.created_at asc limit 1;
        if v_station_id is not null then v_duplicate_by_identity:=v_duplicate_by_identity+1; end if;
      end if;

      v_stream_type:=case
        when v_url ~* '\.m3u8([?#].*)?$' or lower(coalesce(v_item->>'format','')) in ('hls','m3u8') then 'HLS'
        when lower(coalesce(v_item->>'format',''))='mp3' then 'MP3_STREAM'
        when lower(coalesce(v_item->>'format','')) in ('aac','aacp') then 'AAC_STREAM'
        when lower(coalesce(v_item->>'metadataType','')) like 'shoutcast%' then 'SHOUTCAST'
        when lower(coalesce(v_item->>'metadataType','')) like 'icecast%' then 'ICECAST'
        else 'UNKNOWN_STREAM'
      end;

      if v_station_id is null then
        insert into app.stations(
          provider_id,category_id,slug,name_ar,name_en,search_name_ar,search_name_en,
          station_source,stream_type,stream_url,source_url,description,logo_url,is_active,
          production_enabled,status,health_status,last_health_check,last_success_at,
          rights_status,commercial_use_status,attribution_required,attribution_text,
          terms_url,integration_basis,license_type,license_url,redistribution_mode,
          availability_status,external_key,last_seen_at,metadata
        ) values(
          v_provider.id,v_category_id,'islamic-app-'||regexp_replace(lower(v_external_key),'[^a-z0-9]+','-','g'),
          v_name,v_name,v_name,lower(v_name),'EXTERNAL'::app.station_source,v_stream_type,v_url,
          'https://api.islamic.app/v1/radio/stations/'||v_external_key,
          null,nullif(v_item->>'coverUrl',''),true,false,
          case when v_online then 'ONLINE'::app.station_status else 'OFFLINE'::app.station_status end,
          case when v_online then 'HEALTHY'::app.stream_health_status else 'UNREACHABLE'::app.stream_health_status end,
          case when v_item->>'healthCheckedAt' is not null then to_timestamp((v_item->>'healthCheckedAt')::bigint/1000.0) else now() end,
          case when v_online then now() else null end,
          'REVIEW_REQUIRED'::app.rights_status,'UNKNOWN'::app.commercial_use_status,true,
          'Indexed from islamic.app; station/audio rights remain with the original broadcaster.',
          'https://islamic.app/developers','PUBLIC_API',null,null,'DIRECT_EXTERNAL',
          case when v_online and v_url ~* '^https://' then 'PLAYABLE_IN_DEVELOPMENT' else 'REVIEW_REQUIRED' end,
          v_external_key,now(),
          jsonb_build_object(
            'islamic_app_slug',v_external_key,'country',v_item->>'country','city',v_item->>'city',
            'language',v_item->>'language','tags',coalesce(v_item->'tags','[]'::jsonb),
            'format',v_item->>'format','bitrate_kbps',v_item->'bitrateKbps',
            'metadata_type',v_item->>'metadataType','listener_count',v_item->'listenerCount',
            'current_track',v_item->'currentTrack','provider_online',v_online,
            'provider_health_checked_at',v_item->'healthCheckedAt',
            'provider_direct_stream_url',v_direct_url,'provider_proxy_stream_url',v_proxy_url
          )
        ) returning id into v_station_id;
        v_created:=v_created+1;
      else
        update app.stations s set
          category_id=case when s.category_id is null then v_category_id else s.category_id end,
          stream_type=case when s.stream_type='UNKNOWN_STREAM' and v_stream_type<>'UNKNOWN_STREAM' then v_stream_type else s.stream_type end,
          health_status=case when v_online then 'HEALTHY'::app.stream_health_status else s.health_status end,
          last_health_check=case when v_item->>'healthCheckedAt' is not null then to_timestamp((v_item->>'healthCheckedAt')::bigint/1000.0) else s.last_health_check end,
          last_success_at=case when v_online then now() else s.last_success_at end,
          availability_status=case when v_online and s.availability_status='REVIEW_REQUIRED' and s.stream_url ~* '^https://' then 'PLAYABLE_IN_DEVELOPMENT' else s.availability_status end,
          last_seen_at=now(),
          metadata=s.metadata||jsonb_build_object(
            'islamic_app_slug',v_external_key,'islamic_app_online',v_online,
            'islamic_app_health_checked_at',v_item->'healthCheckedAt',
            'islamic_app_tags',coalesce(v_item->'tags','[]'::jsonb),
            'islamic_app_proxy_stream_url',v_proxy_url
          ),updated_at=now()
        where s.id=v_station_id;
        v_reused:=v_reused+1;
      end if;

      insert into app.provider_station_records(
        provider_id,station_id,external_key,discovered_name,discovered_stream_url,
        normalized_hash,last_seen_at,missing_since,raw_metadata
      ) values(
        v_provider.id,v_station_id,v_external_key,v_name,v_url,
        encode(extensions.digest(v_canonical,'sha256'),'hex'),now(),null,v_item
      )
      on conflict(provider_id,external_key) do update set
        station_id=excluded.station_id,discovered_name=excluded.discovered_name,
        discovered_stream_url=excluded.discovered_stream_url,normalized_hash=excluded.normalized_hash,
        last_seen_at=now(),missing_since=null,raw_metadata=excluded.raw_metadata,updated_at=now();
      v_updated:=v_updated+1;
    end loop;
    if v_invalid = v_received then raise exception 'Provider catalog has no valid stations'; end if;

    update app.provider_station_records psr
    set missing_since=coalesce(psr.missing_since,now()),updated_at=now()
    where psr.provider_id=v_provider.id
      and not exists(select 1 from pg_temp.islamic_app_seen x where x.external_key=psr.external_key);
    get diagnostics v_missing=row_count;

    update app.content_providers set
      last_checked_at=now(),
      last_success_at=case when v_api_healthy then now() else last_success_at end,
      health_status=case when v_api_healthy then 'HEALTHY'::app.stream_health_status else 'DEGRADED'::app.stream_health_status end,
      metadata=metadata||jsonb_build_object('last_catalog_total',v_received,'last_api_health_ok',v_api_healthy,'last_sync_at',now(),'response_status',v_response.status),updated_at=now()
    where id=v_provider.id;

    update app.provider_sync_runs set
      status='COMPLETED',finished_at=now(),fetched_count=v_received,inserted_count=v_created,
      updated_count=v_updated,unchanged_count=v_reused,missing_count=v_missing,invalid_count=v_invalid,
      metadata=metadata||jsonb_build_object('http_status',v_response.status,'api_health_ok',v_api_healthy,'duplicate_by_url',v_duplicate_by_url,'duplicate_by_identity',v_duplicate_by_identity,'http_only',v_http_only)
    where id=v_run_id;

    return jsonb_build_object('run_id',v_run_id,'received',v_received,'created',v_created,'reused',v_reused,'duplicate_by_url',v_duplicate_by_url,'duplicate_by_identity',v_duplicate_by_identity,'invalid',v_invalid,'missing',v_missing,'http_only',v_http_only,'api_health_ok',v_api_healthy);
  exception when others then
    update app.provider_sync_runs set status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message='Provider ingestion failed',fetched_count=v_received,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_reused,missing_count=v_missing,invalid_count=v_invalid where id=v_run_id;
    raise;
  end;
end;
$$;

revoke all on function app.sync_islamic_app_radio_stations_payload(jsonb) from public,anon,authenticated;
grant execute on function app.sync_islamic_app_radio_stations_payload(jsonb) to service_role;

create or replace function app.sync_islamic_app_radio_stations() returns jsonb language plpgsql security invoker set search_path='' as $$ begin raise exception 'Provider sync requires protected server ingestion' using errcode='55000'; end; $$;
revoke all on function app.sync_islamic_app_radio_stations() from public,anon,authenticated;
grant execute on function app.sync_islamic_app_radio_stations() to service_role;
do $$ begin
  if not exists(select 1 from vault.secrets where name='tarteel_provider_sync_key') then
    perform vault.create_secret(encode(extensions.gen_random_bytes(32),'hex'),'tarteel_provider_sync_key');
  end if;
end $$;
create or replace function app.authorize_provider_sync(p_token text) returns boolean
language sql stable security definer set search_path='' as $$
  select coalesce(length(p_token)=64 and exists(select 1 from vault.decrypted_secrets where name='tarteel_provider_sync_key' and extensions.digest(decrypted_secret,'sha256')=extensions.digest(p_token,'sha256')),false);
$$;
revoke all on function app.authorize_provider_sync(text) from public,anon,authenticated;
grant execute on function app.authorize_provider_sync(text) to service_role;

-- Cron dispatches only to this project's authenticated Edge endpoint.
-- Vault values are deployment configuration, never committed credentials.
create extension if not exists pg_net with schema extensions;
revoke all on schema net from public,anon,authenticated;
revoke all on all tables in schema net from public,anon,authenticated;
revoke all on all functions in schema net from public,anon,authenticated;
create or replace function app.dispatch_provider_sync() returns bigint
language plpgsql security definer set search_path='' as $$
declare endpoint text; credential text;
begin
  select decrypted_secret into endpoint from vault.decrypted_secrets where name='tarteel_provider_sync_url' limit 1;
  select decrypted_secret into credential from vault.decrypted_secrets where name='tarteel_provider_sync_key' limit 1;
  if endpoint is null or endpoint !~ '^https://[a-z0-9]+\.supabase\.co/functions/v1/provider-sync$' or coalesce(length(credential),0)<20 then
    raise exception 'Provider sync deployment configuration is missing' using errcode='55000';
  end if;
  return net.http_post(url:=endpoint, headers:=jsonb_build_object('Authorization','Bearer '||credential,'Content-Type','application/json'),body:='{}'::jsonb,timeout_milliseconds:=120000);
end;
$$;
revoke all on function app.dispatch_provider_sync() from public,anon,authenticated;
grant execute on function app.dispatch_provider_sync() to service_role;
do $$ begin
  if exists(select 1 from cron.job where jobname='tarteel-islamic-radio-api-daily-sync') then
    perform cron.unschedule('tarteel-islamic-radio-api-daily-sync');
  end if;
  perform cron.schedule('tarteel-islamic-radio-api-daily-sync','17 2 * * *','select app.dispatch_provider_sync();');
end $$;
