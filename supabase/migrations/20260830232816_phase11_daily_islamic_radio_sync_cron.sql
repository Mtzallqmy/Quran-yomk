-- Synchronize the normalized catalog once daily in the trusted Supabase runtime.
-- Listener devices never call the upstream catalog directly.
create extension if not exists pg_cron;

do $$
begin
  if exists(select 1 from cron.job where jobname='tarteel-islamic-radio-api-daily-sync') then
    perform cron.unschedule('tarteel-islamic-radio-api-daily-sync');
  end if;
  perform cron.schedule(
    'tarteel-islamic-radio-api-daily-sync',
    '17 2 * * *',
    'select app.sync_islamic_radio_api_stations();'
  );
end $$;
