begin;

do $$ begin
  if (select count(*) from app.surahs) <> 114 then raise exception 'surah catalog must contain 114 rows'; end if;
  if not exists (select 1 from app.stations where station_source='INTERNAL' and slug='tarteel-dev') then raise exception 'development INTERNAL station missing'; end if;
  if exists (select 1 from app.stations where station_source='EXTERNAL' and production_enabled and (rights_status <> 'APPROVED' or commercial_use_status <> 'ALLOWED')) then raise exception 'external production rights bypass'; end if;
  if exists (select 1 from app.app_config where key in ('privacy_url','terms_url','support_url','website_url','contact_email') and value <> 'null'::jsonb) then raise exception 'unknown legal/contact metadata must remain null until supplied'; end if;
  if not exists (select 1 from app.roles where code='SUPER_ADMIN') or not exists (select 1 from app.roles where code='RADIO_MANAGER') or not exists (select 1 from app.roles where code='CONTENT_EDITOR') or not exists (select 1 from app.roles where code='VIEWER') then raise exception 'RBAC roles incomplete'; end if;
  if exists (select 1 from app.role_permissions rp join app.roles r on r.id=rp.role_id join app.permissions p on p.id=rp.permission_id where r.code='CONTENT_EDITOR' and p.code in ('radio.command','radio.interrupt')) then raise exception 'CONTENT_EDITOR must not control radio'; end if;
  if not exists (select 1 from app.role_permissions rp join app.roles r on r.id=rp.role_id join app.permissions p on p.id=rp.permission_id where r.code='RADIO_MANAGER' and p.code='radio.command') then raise exception 'RADIO_MANAGER radio.command permission missing'; end if;
end $$;

select 'phase7_api_database_contract' as suite,
       (select count(*) from app.surahs) as surahs,
       (select count(*) from app.stations where station_source='INTERNAL') as internal_stations,
       (select count(*) from app.stations where station_source='EXTERNAL') as external_stations,
       (select count(*) from app.stations where station_source='EXTERNAL' and is_active and production_enabled and rights_status='APPROVED' and commercial_use_status='ALLOWED') as public_external_stations;
rollback;
