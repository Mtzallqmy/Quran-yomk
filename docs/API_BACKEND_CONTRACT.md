# Canonical Backend Contract

## Decision

The canonical public/mobile API for Tarteel is the Supabase Edge Function at `supabase/functions/tarteel-api`.

`services/tarteel-api-elysia` is an optional deployment adapter only. It must proxy `/v1/*` requests to the canonical Edge Function and must not contain independent provider resolution, catalog normalization, Quran text selection, reciter identity resolution, or other public-domain business logic.

The Next.js Admin backend under `apps/admin/app/api/v1` is a privileged administration surface. It is not a second public/mobile API and may keep Admin-only mutation flows, session handling, audit logging, upload intents, scheduling and radio control.

## Ownership

| Surface | Owner | Allowed responsibility |
| --- | --- | --- |
| Public/mobile reads | `supabase/functions/tarteel-api` | Public station/catalog/Quran/reciter/runtime read contract |
| Optional public adapter | `services/tarteel-api-elysia` | Fixed-upstream proxy, transport hardening, health |
| Admin mutations | `apps/admin/app/api/v1` | Authenticated privileged mutations and Admin reads |
| Database contract | `supabase/migrations` | RPC/schema invariants and authorization boundaries |

## Non-negotiable rules

1. A public/mobile endpoint is implemented first in `supabase/functions/tarteel-api`.
2. Elysia must not call third-party content providers directly.
3. Elysia must not create a response DTO that differs from the canonical upstream DTO.
4. Admin-only routes are never exposed through the public adapter.
5. Public provider normalization and identity rules live once, behind the canonical Edge Function.
6. Mobile production configuration should point either directly to the canonical Edge Function or to an Elysia adapter that proxies it unchanged.

## Compatibility

The Elysia adapter exposes `/v1/<path>` and maps it to `<canonical-edge-base>/<path>`, preserving query parameters, status, JSON body, cache headers, and request correlation headers. The adapter fails closed if its canonical upstream API key is not configured.
