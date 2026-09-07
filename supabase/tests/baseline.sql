begin;

select plan(59);

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
select lives_ok($q$select app.sync_mp3quran_radios_payload('{"radios":[{"id":"ci-mp3","name":"CI station","url":"https://qurango.net/radio/ci-mp3"}]}'::jsonb)$q$, 'valid MP3Quran fixture is ingested');
select lives_ok($q$select app.sync_islamic_radio_api_stations_payload('{"stations":[{"id":"ci-radio","name":"CI radio","streamUrl":"https://qurango.net/radio/ci-radio","streamFormat":"mp3","status":"active"}]}'::jsonb)$q$, 'valid Islamic Radio fixture is ingested');
select lives_ok($q$select app.sync_islamic_app_radio_stations_payload('{"data":{"stations":[{"slug":"ci-app","name":"CI app","streamUrl":"https://qurango.net/radio/ci-app","online":true}]}}'::jsonb)$q$, 'valid Islamic app fixture is ingested');
select ok(not has_function_privilege('authenticated','app.managed_radio_authorized(uuid,text)','EXECUTE'), 'admin authorization lookup is server only');
select ok(not has_function_privilege('anon','app.update_runtime_config(jsonb,uuid,uuid)','EXECUTE') and not has_function_privilege('authenticated','app.update_runtime_config(jsonb,uuid,uuid)','EXECUTE'), 'runtime writes reject direct clients');
select throws_ok($q$select app.update_runtime_config('{"radio_enabled":false}','00000000-0000-4000-8000-000000000037','00000000-0000-4000-8000-000000000037')$q$,'42501','Settings permission required','runtime RPC requires administrator permission');
insert into auth.users(id,aud,role,email) values('00000000-0000-4000-8000-000000000037','authenticated','authenticated','ci-admin@example.invalid');
insert into app.administrators(id,display_name) values('00000000-0000-4000-8000-000000000037','CI admin');
insert into app.administrator_roles(administrator_id,role_id) select '00000000-0000-4000-8000-000000000037',id from app.roles where code='SUPER_ADMIN';
select lives_ok($q$select app.update_runtime_config('{"radio_enabled":false,"content_manifest_version":"ci-test"}','00000000-0000-4000-8000-000000000037','00000000-0000-4000-8000-000000000037')$q$,'valid runtime values update atomically');
select throws_ok($q$select app.update_runtime_config('{"radio_enabled":true,"reciters_page_size":"bad"}','00000000-0000-4000-8000-000000000037','00000000-0000-4000-8000-000000000037')$q$,'23514',null,'invalid field rolls back the whole batch');
select is((select value from app.app_config where key='radio_enabled'),'false'::jsonb,'earlier setting remains unchanged after failed batch');
select is((select count(*) from app.audit_logs where action='runtime_config.update' and request_id='00000000-0000-4000-8000-000000000037'),1::bigint,'only committed runtime mutation has a completion audit');
select ok(not exists(select 1 from unnest(array['app.virtual_radio_channels','app.virtual_radio_schedule','app.virtual_radio_candidates']) t where has_table_privilege('authenticated',t,'INSERT,UPDATE,DELETE') or has_table_privilege('anon',t,'INSERT,UPDATE,DELETE')), 'direct clients cannot bypass mutation auditing');
select ok(to_regclass('app.user_devices') is not null,'device registry exists');
select ok(to_regclass('app.notification_preferences') is not null,'push preferences exist');
select is((select count(*) from information_schema.columns where table_schema='app' and table_name='notification_preferences' and column_name in ('memorization_review','personal_reminders')),2::bigint,'all independent push preference categories exist');
select ok(to_regclass('app.admin_notifications') is not null,'notification outbox exists');
select ok(to_regclass('app.notification_deliveries') is not null,'delivery ledger exists');
select ok(to_regclass('app.in_app_announcements') is not null,'in-app announcements exist');
select ok(not exists(select 1 from unnest(array['app.user_devices','app.notification_preferences','app.admin_notifications','app.notification_deliveries','app.in_app_announcements']) t where has_table_privilege('authenticated',t,'SELECT,INSERT,UPDATE,DELETE') or has_table_privilege('anon',t,'SELECT,INSERT,UPDATE,DELETE')),'notification tables are never exposed directly');
select ok(not has_function_privilege('anon','app.claim_due_notifications(integer)','EXECUTE') and not has_function_privilege('authenticated','app.prepare_notification_deliveries(uuid)','EXECUTE'),'notification worker RPCs are server only');
select ok(to_regprocedure('app.admin_session_context(uuid)') is not null,'admin session RBAC RPC exists');
select ok(not has_function_privilege('anon','app.admin_session_context(uuid)','EXECUTE') and not has_function_privilege('authenticated','app.admin_session_context(uuid)','EXECUTE'),'admin session RBAC RPC is server only');
select ok(to_regprocedure('app.claim_notification(uuid)') is not null,'single notification dispatch claim exists');
select ok(to_regprocedure('app.authorize_notification_dispatch(text)') is not null,'cron dispatch authorization exists');
select ok(not has_function_privilege('anon','app.claim_notification(uuid)','EXECUTE') and not has_function_privilege('authenticated','app.authorize_notification_dispatch(text)','EXECUTE'),'dispatch RPCs are server only');
select ok(exists(select 1 from vault.secrets where name='notification_dispatch_url'),'notification dispatch URL is provisioned');
select ok(exists(select 1 from vault.secrets where name='notification_cron_secret'),'notification cron credential is provisioned');
select ok(exists(select 1 from cron.job where jobname='tarteel-notification-dispatch' and active),'notification dispatcher runs without an Admin browser');
select is((select count(*) from app.role_permissions rp join app.roles r on r.id=rp.role_id join app.permissions p on p.id=rp.permission_id where r.code='SUPER_ADMIN' and p.code in ('notifications.read','notifications.send','notifications.schedule','notifications.cancel','devices.read','runtime_config.read','runtime_config.write')),7::bigint,'SUPER_ADMIN receives all notification permissions');
insert into app.user_devices(id,installation_id,installation_secret_hash,fcm_token,platform,app_version) values
 ('00000000-0000-4000-8000-000000000038','00000000-0000-4000-8000-000000000039',repeat('a',64),repeat('t',32),'android','1.0.0'),
 ('00000000-0000-4000-8000-000000000040','00000000-0000-4000-8000-000000000041',repeat('b',64),repeat('u',32),'android','1.0.0');
update app.user_devices set revoked_at=now() where id='00000000-0000-4000-8000-000000000040';
insert into app.admin_notifications(id,title,body,type,target_type,scheduled_at,status,idempotency_key,created_by) values('00000000-0000-4000-8000-000000000042','CI','CI','admin_announcements','all',now(),'sending','ci-notification-idempotency','00000000-0000-4000-8000-000000000037');
select is(app.prepare_notification_deliveries('00000000-0000-4000-8000-000000000042'),1,'only the active device is selected');
select is(app.prepare_notification_deliveries('00000000-0000-4000-8000-000000000042'),0,'delivery fanout is idempotent on retry');
select * from finish();
rollback;
