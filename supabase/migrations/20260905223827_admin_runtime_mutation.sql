-- Administrative virtual-radio writes must pass through the audited server API.
revoke all on app.virtual_radio_channels,app.virtual_radio_schedule,app.virtual_radio_candidates from public,anon,authenticated;
grant select,insert,update,delete on app.virtual_radio_channels,app.virtual_radio_schedule,app.virtual_radio_candidates to service_role;
revoke execute on function app.managed_radio_authorized(uuid,text) from public,anon,authenticated;
grant execute on function app.managed_radio_authorized(uuid,text) to service_role;
alter default privileges for role postgres in schema app,radio revoke execute on functions from public;

-- Keep runtime configuration and its audit record in one transaction.
create or replace function app.update_runtime_config(p_updates jsonb,p_actor uuid,p_request_id uuid)
returns setof app.app_config language plpgsql security invoker set search_path='' as $$
declare affected integer; expected integer;
begin
  if not app.managed_radio_authorized(p_actor,'settings.write') then
    raise exception 'Settings permission required' using errcode='42501';
  end if;
  if jsonb_typeof(p_updates) is distinct from 'object' or p_updates='{}'::jsonb then
    raise exception 'Invalid runtime configuration';
  end if;
  if exists(select 1 from jsonb_object_keys(p_updates) k where k<>all(array[
    'radio_enabled','virtual_radio_enabled','virtual_radio_show_next_program',
    'virtual_radio_allow_degraded_fallback','virtual_radio_max_failed_sources',
    'offline_downloads_enabled','mushaf_tajweed_enabled','elysia_api_enabled',
    'reciters_page_size','home_sections','content_manifest_version','content_manifest',
    'minimum_android_version','latest_android_version'])) then
    raise exception 'Runtime config key is not allowed';
  end if;
  select count(*) into expected from jsonb_object_keys(p_updates);
  return query update app.app_config c set value=j.value,updated_by=p_actor
    from jsonb_each(p_updates) j where c.key=j.key returning c.*;
  get diagnostics affected=row_count;
  if affected<>expected then raise exception 'Runtime config key is not seeded'; end if;
  insert into app.audit_logs(actor_id,action,resource_type,request_id,metadata)
  values(p_actor,'runtime_config.update','app_config',p_request_id,
    jsonb_build_object('keys',(select jsonb_agg(k) from jsonb_object_keys(p_updates) k)));
end;
$$;
revoke all on function app.update_runtime_config(jsonb,uuid,uuid) from public,anon,authenticated;
grant execute on function app.update_runtime_config(jsonb,uuid,uuid) to service_role;
