# Quran Reciter Identity Invariant

Status: P0 hardening contract v1.

## Invariant

When a user explicitly selects reciter identity **X**, Tarteel must either play/download/restore identity **X** or fail visibly. It must never silently substitute identity **Y** because a provider, cache, persisted record, or fallback path returned something playable.

The canonical cross-service contract is `contracts/quran-reciter-identity.v1.schema.json` and carries:

- provider;
- provider-owned reciter identifier;
- edition / moshaf identity;
- riwayah metadata when known;
- surah number;
- ayah number when resolving verse audio.

Human-readable names are display metadata and are never identity keys.

## Existing IDs remain compatible

This hardening does not rename public or persisted stable IDs.

- Direct Flutter MP3Quran reciters remain `mp3quran:<reciter_id>:<moshaf_id>` with edition `<reciter_id>-<moshaf_id>`.
- Direct Flutter AlQuran Cloud reciters remain `alquran:<edition>`.
- Supabase Edge public IDs remain in their existing `MP3QURAN-<provider_reciter_id>-<moshaf_id>` form.
- Elysia keeps its current query contract (`provider`, `reciterId`, `edition`) and adapts it to the canonical v1 identity for validation/evidence.

Adapters may normalize field names/casing at boundaries, but they may not invent a different reciter identity.

## Fail-closed rules

The following are rejected rather than substituted:

- unknown persisted provider;
- empty reciter/edition identifiers;
- malformed MP3Quran reciter/moshaf composite IDs;
- AlQuran identity that does not exactly match its edition;
- provider returned by a resolver that differs from the selected provider;
- reciter/edition/riwayah mismatch after resolution;
- returned surah/ayah identity that differs from the request;
- local cached/downloaded media whose identity differs from the remote media it is replacing;
- playlist/recent-playback records with invalid identity fields.

Invalid historical records may be skipped during store loading so they cannot become playable state. Valid historical records keep their existing paths/IDs and continue to load.

## Offline storage

New downloads are placed below a directory derived from a SHA-256 digest of the complete reciter identity rather than from `edition` alone. Existing completed downloads retain their persisted `local_path`; no migration or destructive move is performed. Lookup compares the full storage identity before using a local file.

## Fallback policy

Provider fallback is allowed only when the request has **no explicit reciter selection**. Once a reciter is selected, resolver search is restricted to that provider and exact identity. Provider failure then produces an unavailable/mismatch error; it does not choose a different reciter.

## Required regression evidence

Tests must cover at least:

- cross-provider substitution;
- same-provider different-reciter substitution;
- edition/moshaf mismatch;
- riwayah mismatch;
- wrong returned surah/ayah;
- malformed persisted provider/identity;
- wrong cached local identity;
- download path separation for distinct reciter identities;
- valid legacy persisted records remaining readable.
