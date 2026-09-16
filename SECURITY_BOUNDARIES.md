# Security Boundaries & Zero-Surveillance Architecture

## 1. Zero Secrets in Client Applications
- Flutter mobile apps and web frontends only receive the **Supabase Anon Public Key**.
- The `service_role` key and database administrative credentials are NEVER bundled into client applications or repository code.

## 2. Row Level Security (RLS) Policy
- Direct anonymous writes to any database table are strictly forbidden.
- Public read access is granted only to active, published content (e.g. `is_active = true`, `is_published = true`).
- Administrative operations require verified role membership mapped in `app.administrators` evaluated via `app.has_permission(required_perm)`.

## 3. Privacy-First Notification Consent Architecture
1. **Explicit In-App Consent**: No registration with Google FCM or notification servers occurs until the user explicitly enables notifications in the settings UI.
2. **Installation Pseudonymization**:
   - `installation_id`: A randomly generated UUID on the device.
   - `hashed_secret`: A SHA-256 hash of a local device secret.
   - Zero collection of phone numbers, user emails, or unique device hardware IMEIs.
3. **Immediate Revocation**: When the user disables notifications, the installation record is immediately flagged as inactive (`is_active = false`), the FCM token is overwritten with `'REVOKED'`, and all association metadata is scrubbed.
4. **Local Prayer Times**: Prayer times and adhkar reminders are calculated strictly on-device using local solar algorithms without sharing user GPS coordinates with any remote server.
