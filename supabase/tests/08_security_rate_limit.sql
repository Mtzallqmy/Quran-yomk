begin;

select plan(8);

select ok(to_regclass('app.rate_limit_buckets') is not null,'rate-limit bucket table exists');
select ok(to_regprocedure('app.consume_rate_limit(text,integer,integer,timestamptz)') is not null,'rate-limit RPC exists');
select ok(not has_schema_privilege('anon','app','USAGE'),'anon cannot use private app schema');
select ok(not has_schema_privilege('authenticated','app','USAGE'),'authenticated cannot use private app schema');
select ok(not has_function_privilege('anon','app.consume_rate_limit(text,integer,integer,timestamptz)','EXECUTE'),'anon cannot execute distributed rate limiter');
select ok(not has_function_privilege('authenticated','app.consume_rate_limit(text,integer,integer,timestamptz)','EXECUTE'),'authenticated cannot execute distributed rate limiter');
select ok(has_function_privilege('service_role','app.consume_rate_limit(text,integer,integer,timestamptz)','EXECUTE'),'service role can execute distributed rate limiter');
select ok((select allowed from app.consume_rate_limit(repeat('a',64),2,60,now())),'first rate-limit consumption is allowed');

select * from finish();
rollback;
