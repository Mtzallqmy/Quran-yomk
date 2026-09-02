# Tarteel Quran Integrity System

Status: P0 hardening — canonical v1 approved; runtime cutover candidate under validation.

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

## Runtime cutover

The public Quran passage route must not trust a mutable provider response on each request. The Phase 4 runtime candidate therefore uses `quran_integrity_runtime.js` as the only text-loading gate for `/quran/surah/*`, `/quran/juz/*`, and `/quran/page/*`.

The runtime behavior is intentionally strict:

1. an Edge isolate requests the exact full Uthmani and Tajweed editions recorded by canonical v1;
2. redirects, non-HTTPS sources, non-JSON responses, oversized responses, byte-length changes, and SHA-256 changes are rejected;
3. only a response whose raw bytes match the approved v1 source revision is parsed;
4. the verified snapshots are cached for the lifetime of the Edge isolate, so passage requests are served from the verified snapshot rather than refetching mutable Quran text per request;
5. integrity failures are latched for that isolate and **fail closed**; the runtime never substitutes another Quran source or edition;
6. temporary availability failures may retry on a later request, but they cannot bypass the revision gate;
7. passage slicing preserves the existing public DTO and adds canonical dataset/version/checksum metadata.

This is a conservative transition path that avoids introducing a second stored Quran-text copy inside the Edge Function package. A future optimization may bundle the already-approved canonical dataset directly with the function, but only after the deployment/bundle path is proven and the same checksum/integrity gates remain in force.

A production cutover is not considered complete merely because this code exists. The PR must pass canonical dataset tests, runtime revision-gate tests, DTO compatibility tests, and a deployed smoke test against a non-production Supabase runtime before being promoted.

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
