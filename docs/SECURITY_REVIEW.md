# Security Review & Privacy Posture — Quran Yutla (قرآن يتلى)

## 1. Secrets Management & Zero-Leakage Policy
- **Client-Facing Apps (Android / Web)**: Strictly bundle only the **public Supabase publishable anonymous key**.
- **Backend Secrets**: `SUPABASE_SERVICE_ROLE_KEY`, `ICECAST_SOURCE_PASSWORD`, `ICECAST_ADMIN_PASSWORD`, and `FCM_SERVER_KEY` are strictly server-side environment variables and are never bundled into client packages, APK assets, or Git history.
- **Git Repo Scans**: Verified clean from hardcoded production credentials.

## 2. Row-Level Security (RLS) & Authorization
- Every table across `app` and `radio` schemas has `ENABLE ROW LEVEL SECURITY;` actively enforced.
- Direct anonymous writes or updates to Quran text, reciters, or radio engine states are strictly blocked with `FOR ALL USING (false)`.
- Administrative mutations enforce `app.has_permission(...)` evaluated securely inside PostgreSQL using `SECURITY DEFINER` and a fixed search path (`SET search_path = app, public`).

## 3. Privacy & Zero-Surveillance Architecture
- **Location Privacy**: Prayer times and Islamic calendar calculations are executed completely offline on-device. No user GPS coordinates or precise IP locations are recorded or transmitted.
- **Pseudonymous Device Identifiers**: The push notification registration system uses a client-generated UUID `installation_id` paired with a SHA-256 hashed secret. No personal identity (name, email, phone number, IMEI) is gathered.
- **Opt-in & Immediate Revocation**: Notifications require explicit user consent (`consent_version`). When disabled, the server replaces the FCM token with `'REVOKED'`, disabling all outbound alerts.

## 4. Audio & Quran Integrity Defense (Fail-Closed)
- Canonical Quran text is cryptographically anchored via SHA-256 checksums (`manifest.json`). Any drift or attempted mutation halts build and serving pipelines immediately.
- Audio normalization mandates EBU R128 (-16.0 LUFS) with SHA-256 asset verification before deployment to public CDN distribution.
