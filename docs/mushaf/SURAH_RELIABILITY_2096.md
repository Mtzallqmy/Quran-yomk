# Surah and reader reliability — published preview 2096

## Changes
- The reader now exposes the official catalog's sura, page, aya and supported word projects. This includes Surah's published tajweed explanations, reasons for revelation, grammatical analysis and sura objectives. Sections request their own scope and reload when their location changes.
- Catalog and body failures have actionable retry controls; empty source responses have explicit empty states. Words preserve each project's own numbering, with forward/back pagination through word 200.
- Switching a sura/juz text view to artwork resolves the first verse's page. Existing page readers accept a changed initial page. Superseded passage requests cannot overwrite the reading position.
- Ayah playback selection excludes reciters without verse audio; cancelling selection does not reuse an incompatible reciter. Thematic lookup indexes verse identities once while retaining overlapping topic order.

## Boundaries
The discovered public Surah catalog does not supply a full downloadable canonical Mushaf/artwork package. Its educational content is requested directly; the existing verified KFGQPC text, SVG artwork and licensed Quranpedia topic tags remain distinct sources. This update does not relabel those assets as Surah or invent tajweed character offsets. New tajweed artwork is still unavailable without a verified source. The user's existing cached artwork is retained.

## Verification status
Canonical validation passed for all 6236 verses, together with 20 Node integrity tests. The focused Flutter regressions passed; final PR quality and Android API 26/36 jobs passed in [run 40257927664](https://github.com/Mtzallqmy/Quran-yomk/actions/runs/40257927664).

The signed ARM64 APK passed actual install-r acceptance from preview 2095, retaining reading position, bookmarks, prayer settings, the rollback snapshot and the saved recording. See `upgrade-2096.json` and [publication run 40329278767](https://github.com/Mtzallqmy/Quran-yomk/actions/runs/40329278767). Physical user-device acceptance remains pending.

[Preview 0.9.3-beta.1 / 2096](https://github.com/Mtzallqmy/Quran-yomk/releases/tag/v0.9.3-beta.1-preview.2096) was published on 2026-10-26. APK SHA-256: `fb8f751aa008d10ffa50b746967724153dac04bad13c9b9f9ec3d729b6abe93e`. Compiled source: `2034e71058273e78bf341ecdc4bbd81aba23a93a`; candidate branch commit: `5718eed84cf6701cda8c40d235b75bfa0be957fb`.

## Additional recovery and live evidence
Temporary audio-provider failures no longer cache an empty/partial reciter catalog for the session; the chooser can retry. Live source probes passed for the 20-project registry, tajweed explanation, aya grammar, page benefits and word ranges. `maqased-sowar/1` returned provider404 and is rendered as unavailable content, not substituted. See `surah-live-2096.json` for hashes and shapes only.
