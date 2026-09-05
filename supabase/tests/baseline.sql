begin;

select plan(14);

select ok(to_regnamespace('app') is not null, 'app schema exists');
select ok(to_regnamespace('radio') is not null, 'radio schema exists');
select ok(to_regclass('app.surahs') is not null, 'app.surahs exists');
select ok(to_regclass('app.stations') is not null, 'app.stations exists');
select ok(to_regclass('radio.radio_commands') is not null, 'radio.radio_commands exists');
select ok(to_regclass('radio.play_history') is not null, 'radio.play_history exists');

select is((select count(*)::bigint from app.surahs), 114::bigint, 'seed contains all 114 surahs');
select ok((select count(*) > 0 from app.categories), 'category seed is non-empty');
select ok((select count(*) > 0 from app.roles), 'RBAC role seed is non-empty');
select ok((select count(*) > 0 from app.content_providers), 'provider seed is non-empty');
select ok((select count(*) > 0 from app.stations), 'station seed is non-empty');

select ok(to_regprocedure('public.tarteel_public_surahs()') is not null, 'public API RPC exists after migrations');
select ok(not has_function_privilege('anon', 'public.tarteel_public_surahs()', 'EXECUTE'), 'anon cannot bypass Edge API RPC boundary');
select ok(has_function_privilege('service_role', 'public.tarteel_public_surahs()', 'EXECUTE'), 'service_role can execute Edge API RPC');

select * from finish();
rollback;
