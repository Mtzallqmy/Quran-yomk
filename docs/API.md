# Tarteel Backend API — Phase 7

Base path: `/api/v1`. The Backend API is the trusted boundary between Flutter/Admin and Supabase/Storage/radio automation. Privileged clients never receive the Supabase secret key and never call Liquidsoap, Icecast, Radio Engine processes, or FFmpeg directly.

## Public contract

Public responses intentionally expose listener-safe fields only. INTERNAL stream URLs are constructed by the backend from `TARTEEL_PUBLIC_STREAM_BASE_URL` plus the configured internal mount. EXTERNAL stations are public only when the station is active, production-enabled, `rights_status=APPROVED`, and `commercial_use_status=ALLOWED`. Development may expose the INTERNAL development station while keeping external rights deny-by-default.

Endpoints:

- `GET /stations`
- `GET /stations/{slug}`
- `GET /stations/{slug}/now-playing`
- `GET /categories`
- `GET /reciters`
- `GET /reciters/{id}`
- `GET /reciters/{id}/surahs`
- `GET /surahs`
- `GET /featured`
- `GET /app-config`
- `GET /search?q=...`

`now-playing` reads `radio.now_playing`, whose accepted source is Liquidsoap playout acknowledgement. It never infers playback from queue insertion.

Pagination uses `page` + `limit` and returns `data`, `page`, `limit`, `total`, and `next_page` where applicable. Public catalogs use HTTP cache controls: surahs/categories long-lived, stations/reciters medium-lived, and now-playing short/no-store.

Errors use one shape:

```json
{"error":{"code":"VALIDATION_ERROR","message":"...","request_id":"..."}}
```

Every request receives `x-request-id`; the value is also attached to normalized errors and relevant audit rows.

## Authentication and RBAC

Admin login uses Supabase Auth server-side. The browser receives only HttpOnly session cookies. On every protected request the backend resolves the authenticated UUID to `app.administrators`, `app.administrator_roles`, `app.roles`, `app.role_permissions`, and `app.permissions`. Browser-provided roles are ignored.

Existing permissions remain authoritative. Important mappings include `radio.command`, `radio.interrupt`, `media.write`, `playlists.write`, `schedules.write`, `external_stations.write`, `rights.approve`, `reciters.write`, `categories.write`, `settings.write`, and `audit.read`.

## Admin endpoints

- `POST /admin/auth/login`, `POST /admin/auth/logout`, `GET /admin/auth/me`
- `GET /admin/dashboard`
- `GET|POST /admin/media`, `PATCH /admin/media/{id}`, `POST /admin/media/{id}/upload-intent`, `POST /admin/media/{id}/retry`
- `POST /admin/upload-intents/{id}/complete`
- `GET|POST /admin/playlists`, `PATCH|DELETE /admin/playlists/{id}`, `POST /admin/playlists/{id}/items`, `POST /admin/playlists/{id}/reorder`
- `GET|POST /admin/schedules`, `PATCH|DELETE /admin/schedules/{id}`
- `GET|POST /admin/commands`, `GET /admin/commands/{id}`
- `GET|POST /admin/external-stations`, `PATCH /admin/external-stations/{id}`, `POST /admin/external-stations/{id}/health-test`
- `GET|POST /admin/reciters`, `PATCH /admin/reciters/{id}`, `POST /admin/reciters/{id}/tracks`
- `GET|POST /admin/categories`, `PATCH|DELETE /admin/categories/{id}`
- `GET|PATCH /admin/settings`
- `GET /admin/audit`

Sensitive write handlers enforce same-origin browser requests, runtime input validation, server RBAC, request IDs, structured errors, and audit logging. Radio commands are inserted into `radio.radio_commands` with idempotency keys; the API never invokes Liquidsoap directly.

## Upload lifecycle

`POST /admin/media/{id}/upload-intent` calls the accepted `app.create_media_upload_intent` RPC, obtains an immutable object key, creates a Supabase Storage signed-upload token, then marks the intent signed through the accepted RPC. Completion uses `app.complete_media_upload`; the Audio Worker owns subsequent processing and READY transition.

## Search

Arabic search uses normalized lookup text without changing stored display strings: Alef variants normalize to `ا`, `ى` to `ي`, and Arabic diacritics/tatweel are ignored. English search is case-insensitive.

## Configuration

Only rows with `app_config.is_public=true` are returned publicly. Unknown support/contact/privacy/terms/website values remain null. Private operational keys such as worker leases, Storage lifecycle settings, and backend credentials are not exposed.
