# Tarteel Radio Engine Foundation

Phase 5 service only: it claims one INTERNAL station, validates a development playlist, starts a continuous Liquidsoap source to `/tarteel.mp3`, publishes basic checkpoints, and restarts the source with bounded exponential backoff. Scheduler, commands, live takeover and production queue logic are intentionally absent.

```bash
npm ci
npm run build
npm test
npm run check:dependencies
npm start
```

Use environment variables from `.env.example` through a secret manager or local non-committed `.env`. `TARTEEL_RADIO_ENGINE_DATABASE_MODE=disabled` is only for isolated local stream tests; managed environments must use the Supabase lease store. The generated Liquidsoap script is mode `0600` inside a per-instance `0700` workspace and is removed on shutdown; credentials are never arguments or logs.
