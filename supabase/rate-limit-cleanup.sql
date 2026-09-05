-- Skip buckets being renewed by another instance; never delete a freshly renewed window.
create or replace function app.consume_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_ms integer,
  p_now timestamptz default clock_timestamp()
) returns boolean
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_count integer;
  v_window interval;
begin
  if p_bucket_key !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid rate limit key' using errcode = '22023';
  end if;
  if p_limit < 1 or p_limit > 100000 then
    raise exception 'invalid rate limit' using errcode = '22023';
  end if;
  if p_window_ms < 1000 or p_window_ms > 86400000 then
    raise exception 'invalid rate limit window' using errcode = '22023';
  end if;

  v_window := make_interval(secs => p_window_ms::double precision / 1000.0);

  insert into app.rate_limit_buckets(bucket_key, window_started_at, request_count, updated_at)
  values(p_bucket_key, p_now, 1, p_now)
  on conflict(bucket_key) do update set
    window_started_at = case
      when app.rate_limit_buckets.window_started_at <= p_now - v_window then p_now
      else app.rate_limit_buckets.window_started_at
    end,
    request_count = case
      when app.rate_limit_buckets.window_started_at <= p_now - v_window then 1
      else app.rate_limit_buckets.request_count + 1
    end,
    updated_at = p_now
  returning request_count into v_count;

  -- Opportunistic bounded cleanup prevents stale one-off IP keys accumulating forever.
  delete from app.rate_limit_buckets
  where window_started_at < p_now - interval '2 days'
    and bucket_key in (
    select bucket_key from app.rate_limit_buckets
    where window_started_at < p_now - interval '2 days'
    order by window_started_at asc
    limit 100
    for update skip locked
  );

  return v_count <= p_limit;
end $$;

revoke all on function app.consume_rate_limit(text, integer, integer, timestamptz)
  from public, anon, authenticated;
grant execute on function app.consume_rate_limit(text, integer, integer, timestamptz)
  to service_role;
