# FCM deployment

The Android client configuration is `apps/mobile/android/app/google-services.json`.
It contains no server credential.

Deploy `supabase/functions/notifications` with JWT verification disabled because
the function performs its own JWT, installation-secret, service-role and cron
authentication for separate routes.

Required Supabase Edge secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON`: the complete Firebase service-account JSON
  for project `tarteel-b755d` with FCM send access.
- `NOTIFICATION_CRON_SECRET`: a random bearer value of at least 32 bytes.

Required Supabase Vault entries:

- `notification_dispatch_url`:
  `https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/notifications/dispatch`
- `notification_cron_secret`: the same value as `NOTIFICATION_CRON_SECRET`.

Never put these values in Flutter, `google-services.json`, source control, or logs.
