begin;

select plan(29);

select ok(to_regnamespace('app') is not null, 'app schema exists');
select ok(to_regnamespace('radio') is not null, 'radio schema exists');
select ok(to_regclass('app.surahs') is not null, 'app.surahs exists');
select ok(to_regclass('app.stations') is not null, 'app.stations exists');
select ok(to_regclass('radio.radio_commands') is not null, 'radio.radio_commands exists');
select ok(to_regclass('radio.play_history') is not null, 'radio.play_history exists');

select is((select count(*)::bigint from app.surahs), 114::bigint, 'seed contains all 114 surahs');
select ok((select count(*) > 0 from app.categories), 'category seed is non-empty');
select is((select count(*) from app.categories where is_system), 13::bigint, 'all seeded category identifiers remain protected');
select ok((select count(*) > 0 from app.roles), 'RBAC role seed is non-empty');
select ok((select count(*) > 0 from app.content_providers), 'provider seed is non-empty');
select ok((select count(*) > 0 from app.stations), 'station seed is non-empty');

select ok(to_regprocedure('public.tarteel_public_surahs()') is not null, 'public API RPC exists after migrations');
select ok(not has_function_privilege('anon', 'public.tarteel_public_surahs()', 'EXECUTE'), 'anon cannot bypass Edge API RPC boundary');
select ok(has_function_privilege('service_role', 'public.tarteel_public_surahs()', 'EXECUTE'), 'service_role can execute Edge API RPC');

select ok(not has_function_privilege('authenticated', 'public.tarteel_public_surahs()', 'EXECUTE'), 'authenticated cannot bypass Edge API RPC boundary');
select ok(not exists (
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef
    and (has_function_privilege('anon',p.oid,'EXECUTE')
      or has_function_privilege('authenticated',p.oid,'EXECUTE'))
), 'all public SECURITY DEFINER RPCs reject direct client execution');
select is((select count(*) from app.roles where code in ('SUPER_ADMIN','RADIO_MANAGER','CONTENT_EDITOR','VIEWER')), 4::bigint, 'all required RBAC roles exist');
select ok(exists (
  select 1 from app.stations where slug='tarteel-dev'
    and station_source='INTERNAL' and not production_enabled and default_playlist_id is not null
), 'development automation fixture is complete and not production enabled');
select is((select count(*) from app.surahs where id=number and number between 1 and 114 and ayah_count>0), 114::bigint, 'surah identities and ayah counts are valid');
select is((select count(*) from app.virtual_radio_schedule s join app.virtual_radio_channels c on c.id=s.channel_id where c.slug='tarteel'), 6::bigint, 'editorial schedule is not silently skipped before category seed');

select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app' and p.proname in ('sync_mp3quran_radios','sync_islamic_radio_api_stations','sync_islamic_app_radio_stations','sync_mp3quran_radios_payload','sync_islamic_radio_api_stations_payload','sync_islamic_app_radio_stations_payload') and pg_get_functiondef(p.oid) like '%extensions.http_get%'), 'provider ingestion cannot access arbitrary outbound HTTP');
select ok(not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='app' and (p.proname like 'sync_%_payload' or p.proname='dispatch_provider_sync') and (has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('authenticated',p.oid,'EXECUTE'))), 'ingestion and dispatch are server only');
select throws_ok($q$select app.sync_mp3quran_radios_payload('{}'::jsonb)$q$, 'P0001', 'Invalid provider catalog', 'missing catalog cannot mark stations missing');
select throws_ok($q$select app.sync_islamic_radio_api_stations_payload('{"stations":[]}'::jsonb)$q$, 'P0001', 'Invalid provider catalog size', 'empty radio catalog is rejected');
select throws_ok($q$select app.sync_islamic_app_radio_stations_payload('{"data":{"stations":[]}}'::jsonb)$q$, 'P0001', 'Invalid provider catalog size', 'empty Islamic app catalog is rejected');
select throws_ok($q$select app.sync_islamic_radio_api_stations()$q$, '55000', 'Provider sync requires protected server ingestion', 'legacy network path fails closed');
select is(app.authorize_provider_sync(repeat('0',64)), false, 'invalid dispatch token is rejected');
select ok(not has_function_privilege('anon','app.authorize_provider_sync(text)','EXECUTE') and not has_function_privilege('authenticated','app.authorize_provider_sync(text)','EXECUTE'), 'dispatch authorization cannot be called by clients');
select * from finish();
rollback;
