# Production Closure Checklist

Updated 2026-09-19.

This checklist records the remaining work required before calling Tarteel a production release. It intentionally separates repository fixes from environment-dependent verification.

## Completed in this closure branch

- Mobile API no longer defaults to the intentionally invalid `api.tarteel.invalid` endpoint; it defaults to the canonical production Edge API.
- Live provider acceptance runs each provider check independently and reports all outcomes before failing the workflow, so one CDN outage no longer hides Mushaf/audio results.
- Deployment topology documentation now distinguishes the implemented service roots from the target topology.

## Still required before production sign-off

### Repository / release

- [ ] Reconcile this branch into `main` and make one commit the canonical release source.
- [ ] Decide and document the canonical API path: Supabase Edge Function versus the optional Elysia service.
- [ ] Remove or explicitly scope disabled transcription; it is currently a non-production placeholder.
- [ ] Generate a production Android signing configuration using GitHub/Play secrets; do not use debug signing for store releases.
- [ ] Add signed AAB/Play deployment workflow after store credentials and metadata are supplied.
- [ ] Add iOS release/TestFlight workflow if iOS remains in product scope.

### Runtime / deployment

- [ ] Reconcile live Supabase migration/function versions with repository migrations.
- [ ] Verify server-only secrets are present only in server environments.
- [ ] Deploy and verify Admin grants, provider dispatcher, and health functions.
- [ ] Perform a real backup/restore drill.
- [ ] Establish SLO/RPO/RTO and alert thresholds.
- [ ] Verify external audio probes validate actual stream/audio health, not only HTTP availability.

### Android device acceptance

- [ ] Test exact alarms on Android 8, current Android, Xiaomi/Redmi, Samsung, and at least one other OEM.
- [ ] Test Doze and battery optimization.
- [ ] Test reboot recovery.
- [ ] Test time/timezone changes.
- [ ] Test notification permission denial/regrant.
- [ ] Test FCM registration and delivery.
- [ ] Test background audio and media controls over a long session.

### Radio

- [ ] Run production-like continuous broadcast/soak testing.
- [ ] Test engine crash/restart and lease recovery.
- [ ] Test Icecast failure and recovery.
- [ ] Test database interruption without silencing active playout.
- [ ] Verify queue/command/ACK/history consistency after faults.
- [ ] Document the single-host/SPOF decision or deploy the required HA topology.

### Quran / Islamic content

- [ ] Move approved canonical Quran bytes to a production-serving immutable artifact so routine runtime availability does not depend on an upstream provider.
- [ ] Verify live Islamic library CDN availability independently from Mushaf/audio acceptance.
- [ ] Verify content rights/redistribution approval for every bundled or downloadable audio asset.

## Release rule

A successful GitHub build or prerelease is not by itself production certification. Production sign-off requires repository CI plus environment, device, security, restore, and operational evidence.
