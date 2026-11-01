-- In managed mode the Flutter player must receive only the managed station's fixed stream URL.
-- The selected external station remains available separately as relay_source for administration/observability.
create or replace function public.tarteel_public_virtual_radio_managed(
  p_slug text default 'tarteel',p_environment text default 'development',
  p_exclude_station_ids uuid[] default '{}'::uuid[],p_now timestamptz default now()
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare
  v_base jsonb; v_cfg app.managed_radio_configs%rowtype; v_channel_id uuid; v_stream text; v_managed boolean:=false;
begin
  v_base:=app.resolve_virtual_radio(p_slug,p_environment,p_exclude_station_ids,p_now);
  select c.id into v_channel_id from app.virtual_radio_channels c where c.slug=p_slug limit 1;
  if v_channel_id is not null then select * into v_cfg from app.managed_radio_configs where channel_id=v_channel_id; end if;
  v_stream:=nullif(v_cfg.fixed_stream_url,'');
  v_managed:=coalesce(v_cfg.enabled,false) and v_stream is not null and v_stream~*'^https://';
  if v_managed then
    if jsonb_typeof(v_base->'station')='object' then
      v_base:=jsonb_set(v_base,'{relay_source}',v_base->'station',true);
      v_base:=jsonb_set(v_base,'{station,playback_url}',to_jsonb(v_stream),true);
    end if;
    v_base:=jsonb_set(v_base,'{available}','true'::jsonb,true);
    v_base:=jsonb_set(v_base,'{mode}','"MANAGED"'::jsonb,true);
    v_base:=jsonb_set(v_base,'{playback}',jsonb_build_object('url',v_stream,'kind','MANAGED_RADIO','is_live',true,'seekable',false,'provider',v_cfg.provider),true);
  else
    v_base:=jsonb_set(v_base,'{mode}','"DIRECT_FALLBACK"'::jsonb,true);
    if coalesce(v_base->>'available','false')='true' then
      v_base:=jsonb_set(v_base,'{playback}',jsonb_build_object('url',v_base#>>'{station,playback_url}','kind','EXTERNAL_DIRECT','is_live',true,'seekable',false),true);
    end if;
  end if;
  v_base:=jsonb_set(v_base,'{managed_radio}',jsonb_build_object(
    'provider',coalesce(v_cfg.provider,'RADIO_CO'),'enabled',coalesce(v_cfg.enabled,false),
    'configured',(v_cfg.station_external_id is not null and v_stream is not null),
    'station_external_id',v_cfg.station_external_id,'fixed_stream_url',v_stream,
    'backup_playlist_external_id',v_cfg.backup_playlist_external_id,'provider_status',v_cfg.provider_status,
    'now_playing',coalesce(v_cfg.provider_now_playing,'{}'::jsonb),'last_provider_check_at',v_cfg.last_provider_check_at,
    'last_sync_at',v_cfg.last_sync_at,'last_sync_status',coalesce(v_cfg.last_sync_status,'NEVER'),'last_sync_error_code',v_cfg.last_sync_error_code
  ),true);
  return v_base;
end;
$$;
revoke all on function public.tarteel_public_virtual_radio_managed(text,text,uuid[],timestamptz) from public;
grant execute on function public.tarteel_public_virtual_radio_managed(text,text,uuid[],timestamptz) to anon,authenticated,service_role;
