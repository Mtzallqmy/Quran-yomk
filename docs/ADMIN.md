# Tarteel Admin Panel

## Architecture

`Browser → /api/v1/admin/* → Backend authorization/RBAC → PostgreSQL/Supabase/Storage/Radio Commands`.

Privileged mutations never write directly from browser code to database tables. Radio controls create command records; they do not call Liquidsoap, Icecast or Radio Engine processes directly.

## Authentication

The login form calls `/api/v1/admin/auth/login`. The server authenticates with Supabase Auth, resolves administrator roles/permissions and sets HTTP-only session cookies. `/api/v1/admin/auth/me` protects/initializes the UI. Navigation is permission-aware, while backend authorization remains authoritative. Logout invalidates the server-side Supabase session cookies.

No service-role or secret Storage credential is shipped to browser code.

## Screens

- Dashboard: current item, engine state, heartbeat, recent commands, schedules, media/processing counts.
- Radio Control: Play Next, Play Now + FINISH_CURRENT, Play Now + INTERRUPT, Skip, Stop After Current, Resume Auto. INTERRUPT requires explicit confirmation and `radio.interrupt`.
- Media: real signed-upload flow, byte-derived upload progress, processing states and archive action.
- Playlists: create, add READY media and reorder through API/RPC semantics.
- Schedules: ONE_TIME / DAILY / WEEKLY; timezone/content/priority/interrupt semantics remain backend-owned.
- Reciters/Tracks: reciter management and 1–114 surah track links.
- External Stations: explicit REVIEW_REQUIRED/UNKNOWN defaults, health requests and no internal automation path.
- Categories: system-category protection stays server-side.
- Settings: only backend allow-listed keys are editable; unknown legal/contact values remain null/TBD.
- Audit: request/resource/action/actor traceability.
- Product Identity: approved metadata and PROVISIONAL visual boundary.

## Secure upload flow

1. `POST /api/v1/admin/media` creates UPLOADING media.
2. `POST /api/v1/admin/media/:id/upload-intent` returns a signed Storage upload target.
3. Browser uploads bytes directly to that signed URL; progress is measured from actual transferred bytes.
4. `POST /api/v1/admin/upload-intents/:id/complete` lets the server verify/finalize upload lifecycle.
5. Audio Worker processes the queued job and media moves through PROCESSING to READY or FAILED.

## RTL/accessibility

The root document is Arabic/RTL. Layout uses logical CSS properties and explicit LTR isolation for UUID/URL/hash fields. Keyboard focus is visible, forms are labelled, errors are surfaced with alert/status semantics, destructive actions are confirmed and reduced-motion preferences are honored.

## Development limitation

A full real login/RBAC browser E2E requires actual development Supabase Auth users mapped to administrator roles. The panel does not create a parallel password system. If no such users exist, that specific real E2E remains an environment-data blocker rather than being simulated as PASS.
