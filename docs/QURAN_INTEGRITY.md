# Tarteel Quran Integrity System

Status: P0 hardening foundation.

## Purpose

Production Quran text must not change because a mutable upstream API changed. Tarteel therefore treats Quran text as an explicitly versioned, immutable, checksummed dataset. No AI, fuzzy matching, transliteration heuristic, or automatic text correction is allowed in this pipeline.

## Canonical source for v1

Version `v1` is an exact snapshot of the two editions already consumed by the existing public API:

- Uthmani: AlQuran Cloud edition `quran-uthmani`.
- Tajweed: AlQuran Cloud edition `quran-tajweed`.

The capture records SHA-256 hashes of the raw HTTP responses as the upstream source revision identifiers. The normalized dataset has its own SHA-256. The approval means: **the snapshot exactly passed Tarteel's deterministic integrity gates and freezes the existing production upstream behavior**. It does not claim an independent scholarly certification of the source.

## Fail-closed invariants

Validation fails when any of the following occurs:

- the dataset does not contain exactly the 114 expected surahs;
- a surah number is missing, duplicated, or out of order;
- a surah's ayah count differs from `supabase/seed/03_surahs.sql`;
- an ayah is missing or out of order;
- a global ayah identity is missing, duplicated, or out of order;
- a `verse_key` is duplicated or does not match `surah:ayah`;
- Uthmani and Tajweed identities do not match;
- either Quran text field is empty;
- page identities are outside 1..604, non-monotonic, or any page is absent;
- juz identities are outside 1..30 or any juz is absent;
- the approved dataset checksum changes;
- the source edition contract changes;
- the manifest is not explicitly `APPROVED`;
- an already-approved version is modified in place relative to the PR base.

The last rule makes upgrades append-only: after `v1` is merged, updates must create `v2` (or later), with a new source revision, checksum, review, tests, and explicit cutover plan. Silent refresh is forbidden.

## Capture procedure

Capture is deliberately not a recurring job. The initial v1 capture is triggered only by the explicit hardening commit marker `[quran-capture-request-v1]` on `hardening/phase3-quran-integrity`. The workflow:

1. fetches only HTTPS JSON from the two named editions;
2. rejects redirects, HTTP failures, unexpected content types, and oversized payloads;
3. preserves Quran text strings verbatim;
4. validates identities/order/counts/page/juz consistency;
5. computes response and dataset SHA-256 hashes;
6. runs negative mutation tests;
7. commits the resulting v1 files with `[quran-capture-result]`, which does not trigger another capture.

Normal CI is check-only and never refreshes Quran text.

## Production cutover rule

Adding the canonical dataset does **not** by itself authorize a public API cutover. Before replacing live upstream text reads, the cutover PR must prove DTO parity for `/quran/surah`, `/quran/juz`, and `/quran/page`, preserve public contracts, and fail closed if the approved dataset cannot be loaded. External fallback may be used only for non-sensitive metadata; it must not silently replace approved Quran text.

## Rights and provenance

Tarteel stores the Arabic text only under a verbatim/no-mutation policy and retains source attribution. AlQuran Cloud identifies multiple Quran text curators, including Tanzil; source identifiers remain attached to the manifest. Tarteel does not infer redistribution rights for audio or unrelated assets from Quran text terms.

See `THIRD_PARTY_NOTICES.md` for the recorded external-source policy.

## Upgrade checklist

A future dataset upgrade requires all of the following:

- new version directory;
- explicit source/edition/revision evidence;
- new SHA-256;
- unchanged verbatim/no-AI policy;
- structural and identity tests;
- source/provenance review;
- API compatibility tests;
- Quran-content review appropriate to the release risk;
- documented production cutover and rollback/forward-fix strategy.
