# Environment Variables Reference — Quran Yutla (قرآن يتلى)

| Variable Name | Environment / Service | Purpose | Sensitivity | Example |
| :--- | :--- | :--- | :--- | :--- |
| `SUPABASE_URL` | All services | Supabase project API gateway | Public | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | Mobile / Web / Edge | Client public anonymous JWT | Public (RLS protected) | `eyJhbGci...` |
| `SUPABASE_SERVICE_ROLE_KEY` | Edge Functions / Backend | Elevated server-side management | **CRITICAL SECRET** | `eyJhbGci...` |
| `DATABASE_URL` | Migrations / Direct DB | PostgreSQL connection string | **CRITICAL SECRET** | `postgresql://postgres:...` |
| `ICECAST_SOURCE_PASSWORD` | Radio Engine | Liquidsoap streaming password | Secret | `xxxxxx` |
| `ICECAST_ADMIN_PASSWORD` | Infrastructure | Icecast server administration | Secret | `xxxxxx` |
| `FCM_SERVER_KEY` | Edge Functions | Firebase Cloud Messaging dispatch | Secret | `AAAA...` |
| `ELYSIA_PORT` | Optional BFF API | Local server port for Bun API | Config | `3001` |
