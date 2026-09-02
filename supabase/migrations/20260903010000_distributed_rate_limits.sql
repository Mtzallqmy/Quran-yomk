-- Tarteel production distributed rate limiting.
-- This migration is additive and intentionally keeps the limiter in the private app schema.

create table if not exists app.rate_limit_buckets (
  bucket_key text primary key,
  request_count integer not null check (request_count >= 0),
  reset_at timestamptz not null,
  updated_at timestamptz not null default now()
);

alter table app.rate_limit_buckets enable row level security;
revoke all on table app.rate_limit_buckets from public, anon, authenticated;
grant select, insert, update, delete on table app.rate_limit_buckets to service_role;

create or replace function app.consume_rate_limit(
  p_bucket_key text,
  p_limit integer,
  p_window_seconds integer,
  p_now timestamptz default now()
)
returns table(allowed boolean, remaining integer, reset_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_count integer;
  v_reset timestamptz;
begin
  if p_bucket_key is null or length(p_bucket_key) < 16 or length(p_bucket_key) > 128 then
    raise exception 'invalid rate-limit bucket key' using errcode = '22023';
  end if;
  if p_limit < 1 or p_limit > 100000 or p_window_seconds < 1 or p_window_seconds > 86400 then
    raise exception 'invalid rate-limit parameters' using errcode = '22023';
  end if;

  insert into app.rate_limit_buckets as bucket(bucket_key, request_count, reset_at, updated_at)
  values (p_bucket_key, 1, p_now + make_interval(secs => p_window_seconds), p_now)
  on conflict (bucket_key) do update
    set request_count = case when bucket.reset_at <= p_now then 1 else bucket.request_count + 1 end,
        reset_at = case when bucket.reset_at <= p_now then p_now + make_interval(secs => p_window_seconds) else bucket.reset_at end,
        updated_at = p_now
  returning request_count, app.rate_limit_buckets.reset_at into v_count, v_reset;

  return query select v_count <= p_limit, greatest(p_limit - v_count, 0), v_reset;
end;
$$;

revoke all on function app.consume_rate_limit(text, integer, integer, timestamptz) from public, anon, authenticated;
grant execute on function app.consume_rate_limit(text, integer, integer, timestamptz) to service_role;

comment on table app.rate_limit_buckets is 'Distributed fixed-window counters for production API enforcement. Bucket keys are SHA-256 digests, not raw IPs or user identifiers.';
comment on function app.consume_rate_limit(text, integer, integer, timestamptz) is 'Atomically consumes one request from a private rate-limit bucket. service_role only.';
