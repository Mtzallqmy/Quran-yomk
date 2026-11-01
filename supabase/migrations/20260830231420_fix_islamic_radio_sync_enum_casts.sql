-- Final Phase 11 Islamic Radio API synchronizer.
-- Fetches the authoritative upstream JSON inside the trusted database runtime,
-- validates rows tolerantly, deduplicates by provider identity and canonical
-- stream URL, and preserves stable Tarteel station IDs.

create or replace function app.sync_islamic_radio_api_stations()
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
    v_response := extensions.http_get(v_provider.source_url::varchar);
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
      status='FAILED',finished_at=now(),error_code='SYNC_FAILED',error_message=sqlerrm,
      fetched_count=v_fetched,inserted_count=v_created,updated_count=v_updated,
      unchanged_count=v_linked,missing_count=v_missing,invalid_count=v_invalid
    where id=v_run_id;
    raise;
  end;
end;
$$;

revoke all on function app.sync_islamic_radio_api_stations() from public,anon,authenticated;
grant execute on function app.sync_islamic_radio_api_stations() to service_role;
