# Surah and reader reliability — 2096 candidate

## Changes
- The reader now exposes the official catalog's sura, page, aya and supported word projects. This includes Surah's published tajweed explanations, reasons for revelation, grammatical analysis and sura objectives. Sections request their own scope and reload when their location changes.
- Catalog and body failures have actionable retry controls; empty source responses have explicit empty states. Words preserve each project's own numbering, with forward/back pagination through word 200.
- Switching a sura/juz text view to artwork resolves the first verse's page. Existing page readers accept a changed initial page. Superseded passage requests cannot overwrite the reading position.
- Ayah playback selection excludes reciters without verse audio; cancelling selection does not reuse an incompatible reciter. Thematic lookup indexes verse identities once while retaining overlapping topic order.

## Boundaries
The discovered public Surah catalog does not supply a full downloadable canonical Mushaf/artwork package. Its educational content is requested directly; the existing verified KFGQPC text, SVG artwork and licensed Quranpedia topic tags remain distinct sources. This update does not relabel those assets as Surah or invent tajweed character offsets. New tajweed artwork is still unavailable without a verified source. The user's existing cached artwork is retained.

## Verification status
Canonical integrity validation and Node integrity tests pass locally. Flutter regression tests and Android acceptance are enforced by the existing PR workflow. Release publication requires its actual passing artifact, the previous preview certificate and signed upgrade acceptance. This file is a candidate record, not a claim of published APK or completed phone testing.

## Additional recovery and live evidence
Temporary audio-provider failures no longer cache an empty/partial reciter catalog for the session; the chooser can retry. Live source probes passed for the 20-project registry, tajweed explanation, aya grammar, page benefits and word ranges. `maqased-sowar/1` returned provider404 and is rendered as unavailable content, not substituted. See `surah-live-2096.json` for hashes and shapes only.
