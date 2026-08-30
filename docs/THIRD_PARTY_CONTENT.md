# Tarteel Third-Party Quran/Islamic Content

Tarteel does not claim ownership of third-party recitations, broadcasts, provider trademarks, or third-party audio content. External stations are played directly from provider infrastructure and are kept outside the Tarteel scheduler, queue manager, radio commands, Radio Engine, Liquidsoap, and internal Icecast path.

Public reachability alone is not treated as a copyright waiver. `PUBLIC_API`, `PUBLIC_STREAM`, and `PERMISSION_DOCUMENTED` describe the factual integration basis; they do not mean `PUBLIC_DOMAIN`.

| Provider | Content Type | Integration Method | Source | Terms/License Reference | Attribution Requirement | Commercial Use Status | Redistribution Status | Last Verified | Production Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Islamic Radio API | Station catalog metadata indexing third-party Quran/Islamic radio | Real upstream JSON → privileged Supabase sync → canonical Tarteel station/provider records → public Tarteel Edge API → direct external playback | https://github.com/uthumany/islamic-radio-api / `client/public/api/stations.json` | Upstream README states CC0-1.0 for the API/catalog. This is recorded as catalog metadata licensing only, not as an assertion about each underlying broadcast. | Provider/source provenance retained; no Tarteel ownership or endorsement claim | `UNKNOWN` per underlying broadcast unless separately documented | `DIRECT_EXTERNAL` | 2026-08-31 | Development health-gated; public release remains subject to the station/provider rights gate |
| Qurango | Quran reciters, tafseer, hadith, seerah, adhkar, ruqyah, fatwa, translations, selected surahs | Direct external stream; documented provider/site permission | https://qurango.net / https://backup.qurango.net | https://www.mp3quran.net/privacy-en.html | `Qurango` | `ALLOWED` under the documented provider permission recorded by the project; not Public Domain | `DIRECT_EXTERNAL` | 2026-08-30 | Health-gated |
| MP3Quran | Dynamic Quran radio catalog | Official public developer API → deterministic backend sync → normalized Tarteel station IDs → public API → Flutter | https://www.mp3quran.net/api/v3/radios?language=ar | https://www.mp3quran.net/privacy-en.html | `MP3Quran` | `ALLOWED` under the documented provider permission recorded by the project; not Public Domain | `DIRECT_EXTERNAL` | 2026-08-30 | Health-gated |
| MP3Quran / Holol Live | Quran and Sunnah live HLS audio/video feeds | Stream URLs published by the MP3Quran developer API; direct external playback | https://win.holol.com/live/quran/playlist.m3u8 and https://win.holol.com/live/sunnah/playlist.m3u8 | https://www.mp3quran.net/privacy-en.html | `MP3Quran / Holol Live` | `UNKNOWN` pending a narrower release-rights determination for the underlying live broadcaster/CDN | `DIRECT_EXTERNAL` | 2026-08-30 | Development testing pending public-release rights gate |
| Saudi Quran Radio / Radiojar | Saudi Quran radio live stream | Publicly reachable broadcaster stream through Radiojar | https://stream.radiojar.com/0tpy1h0kxtzuv | https://support.radiojar.com/support/solutions/articles/5000014578-how-can-my-audience-listen-to-my-station- | `Saudi Quran Radio / Radiojar` | `UNKNOWN`; public stream accessibility is not treated as copyright permission | `DIRECT_EXTERNAL` | 2026-08-30 | Development testing pending rights release gate |

## Development vs public release

`PLAYABLE_IN_DEVELOPMENT` means the stream may be exposed to development builds after technical validation. It does **not** mean the legal status was changed to `LICENSE_VERIFIED`.

`APPROVED_FOR_PUBLIC_RELEASE` is assigned only after the technical health gate passes and the project rights policy allows public release. Production visibility additionally remains auditable through provider/station rights fields and `production_enabled`.

## Phase 11 virtual radio

`إذاعة ترتيل` is a logical scheduled channel. Supabase resolves a current external source and Flutter connects directly to it. Tarteel does not proxy or continuously rebroadcast the third-party audio in Phase 11. The logical Tarteel branding therefore does not imply ownership of the current physical station or its audio.

## Privacy / network disclosure

Playing an external station, including the physical source selected for Virtual Tarteel Radio, causes the listener device to connect directly to infrastructure operated by that provider or its streaming/CDN vendor. Tarteel does not control third-party infrastructure and does not claim that external playback avoids third-party network contact.
