# Tarteel next experience — verified baseline

Inspected 2026-11-01. Work branch: `feat/tarteel-next-experience`.

## Release lineage

The attached screenshot identifies `0.9.2-beta.3 (2095)`, Git
`462b9635d42d723b2131c6d0836ed0974ba91650`. This matches
`release-candidates/preview-2095.json`'s `source_commit`. It is a GitHub
synthetic merge commit, not the current `main` tree.

Development starts from `6a26cb39452e5957cf533e2a90e9cf55a590f719`, the head
of `feat/tarteel-mushaf-surah-unification-2092`, which includes the later
2096 reliability fixes and release evidence. The active application is
`apps/mobile/lib/src`, Flutter, package `app.tarteel.tarteel`, minSdk 26.
The original signing certificate fingerprint is preserved in existing
release verification scripts; no replacement signing identity is introduced.

`main` at `73b6efac0018786ef1709105e9c81f58c9aa91c2` has old Kotlin and
Flutter scaffolds. Findings about hardcoded Mushaf samples in those scaffolds
must not be attributed to the pictured release. Reviving those parallel apps
would regress the real release. This branch retains the complete modern
Flutter implementation, its canonical v2 content, existing native audio,
local reminders, downloads and five-destination navigation.

## Verified database ownership

Read-only inspection of the live schemas agrees with the service READMEs:

| Service | Project | Parent branch | Scope |
|---|---|---|---|
| Optional backup | calm-sky-72162812 | br-wispy-paper-bahpwe0x | tarteel_cloud devices, library_backups, prayer_preferences, radio_supplements, request_budgets |
| Public content | proud-mountain-00920668 | br-curly-salad-bajy1evn | tarteel_catalog, tarteel_mushaf, surah_content |

Neon supplements existing Supabase/Firebase integrations. No production SQL,
credential change or provider migration is necessary for the legal UI fix.
Before database mutations, create a development branch and use explicit
project, branch and database identifiers. Never embed privileged URLs in clients.

## Confirmed current defects and acceptance

- About's `_LegalTile` was unconditionally disabled even with a configured URL.
  Privacy and terms now use bundled source-controlled documents; no network or
  remote config is required. Public web routes use the same source.
- Backup deletion removes preferences and favorites but retains the revoked
  device record. The policy explicitly describes this instead of promising
  immediate erasure of all records or infrastructure backups.
- Existing third-party notices described canonical v1 as current despite
  the active embedded KFGQPC v2 dataset; distinguish historical and current data.

The full requested redesign and cross-browser/device release acceptance are
not implied by this baseline or by passing unit tests. Record actual outcomes
and blockers in the branch's verification report before claiming completion.
