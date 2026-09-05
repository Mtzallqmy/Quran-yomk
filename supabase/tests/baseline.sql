begin;

select plan(21);

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

select * from finish();
rollback;
