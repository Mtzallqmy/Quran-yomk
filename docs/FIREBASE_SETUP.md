# Firebase & FCM Setup Guide — Quran Yutla (قرآن يتلى)

## 1. Privacy-First Consent Flow
1. The app never displays an OS permission dialog on startup.
2. An informative consent bottom sheet explains the religious and broadcast purpose of notifications.
3. Upon consent, the client retrieves an FCM token from Firebase SDK.
4. A random UUID `installation_id` is registered with Supabase via `POST /installations/register`.

## 2. Server-Side Dispatch
- FCM HTTP v1 API requests are issued exclusively from the Supabase `notifications` Edge Function.
- No Firebase Service Account credentials or private keys are ever bundled into client apps.
