"""Exercise the real RPC from independent database connections, without live providers."""
from concurrent.futures import ThreadPoolExecutor
import subprocess
import time

KEY = "f" * 64


def sql(query):
    return subprocess.run(
        ["docker", "exec", "supabase_db_tarteel", "psql", "-XAt", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c", query],
        check=True, capture_output=True, text=True, timeout=30,
    ).stdout.strip()


def consume(_=None):
    # SET ROLE also verifies the production caller can execute the invoker RPC.
    return sql(f"set role service_role; select app.consume_rate_limit('{KEY}',5,60000);").splitlines()[-1]


sql(f"delete from app.rate_limit_buckets where bucket_key='{KEY}';")
try:
    with ThreadPoolExecutor(max_workers=16) as pool:
        results = list(pool.map(consume, range(32)))
    assert results.count("t") == 5, results
    assert results.count("f") == 27, results
    assert consume() == "f", "fresh client connection must retain the exhausted window"
    assert sql("select relpersistence from pg_class where oid='app.rate_limit_buckets'::regclass;") == "p", "limiter must use persistent storage"
    sql(f"update app.rate_limit_buckets set window_started_at=clock_timestamp()-interval '61 seconds' where bucket_key='{KEY}';")
    assert consume() == "t", "expired window must reset"
    assert sql(f"select request_count from app.rate_limit_buckets where bucket_key='{KEY}';") == "1"
    print("Rate limiter: concurrency, limit, new-client persistence and reset PASS")
finally:
    sql(f"delete from app.rate_limit_buckets where bucket_key='{KEY}';")

# A cleanup in another session must not erase a window currently being renewed.
renewed_key, other_key = "d" * 64, "e" * 64
sql(f"insert into app.rate_limit_buckets values('{renewed_key}',clock_timestamp()-interval '3 days',5,clock_timestamp()) on conflict(bucket_key) do update set window_started_at=excluded.window_started_at;")
holder = subprocess.Popen(
    ["docker", "exec", "supabase_db_tarteel", "psql", "-XAt", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
     f"set application_name='rate_cleanup_lock_test'; begin; set role service_role; select app.consume_rate_limit('{renewed_key}',5,60000); select pg_sleep(2); commit;"],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
)
try:
    for _ in range(50):
        if sql("select count(*) from pg_stat_activity where application_name='rate_cleanup_lock_test' and wait_event='PgSleep';") == "1":
            break
        time.sleep(0.05)
    else:
        raise AssertionError("renewal session did not reach its lock barrier")
    sql(f"set role service_role; select app.consume_rate_limit('{other_key}',5,60000);")
    _, errors = holder.communicate(timeout=15)
    assert holder.returncode == 0, errors
    assert sql(f"select count(*) from app.rate_limit_buckets where bucket_key='{renewed_key}' and request_count=1;") == "1", "cleanup erased a concurrently renewed limit"
    print("Rate limiter: concurrent cleanup preserves renewed windows PASS")
finally:
    if holder.poll() is None:
        holder.communicate(timeout=15)
    sql(f"delete from app.rate_limit_buckets where bucket_key in ('{renewed_key}','{other_key}');")
