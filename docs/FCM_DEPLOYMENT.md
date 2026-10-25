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

## Consent and data lifecycle

- The app shows the versioned privacy notice before Firebase initialization or
  the Android/iOS notification permission prompt.
- Device registration is rejected unless `consent_granted=true`, the notice is
  `notifications-v1`, and a valid consent timestamp is supplied.
- Revocation disables local delivery immediately. The backend then removes the
  user link, replaces the FCM token, and clears locale, timezone, app version,
  and consent evidence.
- Upgrading from an older unversioned notice requires consent again; historical
  device rows are revoked by the migration rather than treated as proof.

Android requests only `POST_NOTIFICATIONS` at runtime. Contacts, messages,
files, photos, microphone, and location are not requested for notifications.
On iOS, a production build still requires the project-specific
`GoogleService-Info.plist`, APNs capability, and signing profile outside source
control.
