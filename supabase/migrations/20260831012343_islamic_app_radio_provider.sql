-- Islamic.app radio provider integration.
insert into app.content_provider_types(code,description)
values('ISLAMIC_APP','islamic.app public Islamic radio API')
on conflict(code) do update set description=excluded.description;

insert into app.content_providers(
  name,slug,provider_type,website_url,api_base_url,is_active,production_enabled,
  priority,rights_status,commercial_use_status,attribution_required,attribution_text,
  terms_url,source_url,verified_at,internal_notes,integration_basis,license_type,
  license_url,redistribution_mode,verified_by,metadata
) values(
  'islamic.app Radio','islamic-app','ISLAMIC_APP','https://islamic.app/listen/radio',
  'https://api.islamic.app/v1/radio',true,false,70,
  'REVIEW_REQUIRED','UNKNOWN',true,
  'Station metadata provided by islamic.app; underlying stream/audio rights remain with each broadcaster.',
  'https://islamic.app/developers','https://api.islamic.app/v1/radio/stations',
  now(),
  'Public, versioned, CORS-enabled radio catalog. Do not infer audio ownership or redistribution rights.',
  'PUBLIC_API',null,null,'DIRECT_EXTERNAL','phase11-islamic-app',
  jsonb_build_object(
    'catalog_endpoint','https://api.islamic.app/v1/radio/stations',
    'health_endpoint','https://api.islamic.app/health',
    'docs','https://islamic.app/developers',
    'rate_limit_per_ip_per_minute',60
  )
)
on conflict(slug) do update set
  name=excluded.name,provider_type=excluded.provider_type,website_url=excluded.website_url,
  api_base_url=excluded.api_base_url,is_active=true,source_url=excluded.source_url,
  terms_url=excluded.terms_url,integration_basis=excluded.integration_basis,
  attribution_required=true,attribution_text=excluded.attribution_text,
  internal_notes=excluded.internal_notes,metadata=app.content_providers.metadata||excluded.metadata,
  updated_at=now();

create or replace function app.external_station_identity(p_value text)
returns text language sql immutable set search_path='' as $$
  select regexp_replace(lower(trim(coalesce(p_value,''))),'[[:space:][:punct:]]+','','g');
$$;

create or replace function app.sync_islamic_app_radio_stations()
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
  select * into v_provider from app.content_providers
  where slug='islamic-app' and deleted_at is null limit 1;
  if v_provider.id is null then raise exception 'islamic.app provider missing'; end if;

  insert into app.provider_sync_runs(provider_id,idempotency_key,status,started_at,metadata)
  values(v_provider.id,'islamic-app:'||clock_timestamp()::text,'RUNNING',now(),
    jsonb_build_object('source',v_provider.source_url))
  returning id into v_run_id;

  begin
    v_health_response := extensions.http_get('https://api.islamic.app/health'::varchar);
    v_api_healthy := v_health_response.status between 200 and 299;
    v_response := extensions.http_get(v_provider.source_url::varchar);
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
    update app.provider_sync_runs set status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message=sqlerrm,fetched_count=v_received,inserted_count=v_created,updated_count=v_updated,unchanged_count=v_reused,missing_count=v_missing,invalid_count=v_invalid where id=v_run_id;
    raise;
  end;
end;
$$;

revoke all on function app.sync_islamic_app_radio_stations() from public,anon,authenticated;
grant execute on function app.sync_islamic_app_radio_stations() to service_role;
