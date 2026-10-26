-- Optional user-requested preferences only; no positions, schedules or audio.
CREATE TABLE IF NOT EXISTS tarteel_cloud.prayer_preferences (
 device_id uuid PRIMARY KEY REFERENCES tarteel_cloud.devices(id) ON DELETE CASCADE,
 revision bigint NOT NULL CHECK(revision>0),
 payload jsonb NOT NULL CHECK(
  jsonb_typeof(payload)='object' AND octet_length(payload::text)<=8192
  AND payload ?& ARRAY['schema','calculation_method','asr_method','offsets','reminder_modes','before_minutes','after_minutes','volumes','audio_assets']
  AND payload - ARRAY['schema','calculation_method','asr_method','offsets','reminder_modes','before_minutes','after_minutes','volumes','audio_assets']='{}'::jsonb
  AND payload->'schema'='1'::jsonb
 ),
 updated_at timestamptz NOT NULL DEFAULT now()
);
REVOKE ALL ON tarteel_cloud.prayer_preferences FROM PUBLIC;
ALTER TABLE tarteel_cloud.prayer_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE tarteel_cloud.prayer_preferences FORCE ROW LEVEL SECURITY;
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM pg_policies WHERE schemaname='tarteel_cloud' AND tablename='prayer_preferences' AND policyname='own_prayer_preferences') THEN
  CREATE POLICY own_prayer_preferences ON tarteel_cloud.prayer_preferences FOR ALL TO tarteel_cloud_client
   USING(device_id::text=current_setting('tarteel.device_id',true))
   WITH CHECK(device_id::text=current_setting('tarteel.device_id',true));
 END IF;
END $$;
GRANT SELECT,INSERT,UPDATE,DELETE ON tarteel_cloud.prayer_preferences TO tarteel_cloud_client;
