# Stage 0 mobile UI architecture

Canonical release: Flutter `apps/mobile`, Android only. See
[MOBILE_UI_CANONICAL.md](MOBILE_UI_CANONICAL.md) for the verified APK evidence.

## Navigation

`MobileDestination` is an enum with stable IDs: home, quran, listen, radio,
library. `RootShell` retains visited widgets in stable keyed slots; removing
radio changes the visible destination list, not the identity of other tabs.
Selection is persisted in the existing SettingsStore/SharedPreferences.
List scroll state uses PageStorage and retained tab states.

`MaterialApp.onGenerateRoute` delegates to `MobileRoutes.generate`.
Secondary routes use the root Navigator and return to retained tab state.
Reader routes own their Scaffold, so bottom navigation and Mini Player are
absent. Back uses Android Navigator semantics, including while immersive.
No new navigation/state-management dependency is introduced.

| Route | Screen |
| --- | --- |
| `/quran` | Independent Quran index |
| `/quran/reader` + page argument | Existing full screen Mushaf reader |
| `/quran/bookmarks` | Index opened on bookmarks |
| `/listen` | Listening landing |
| `/reciters` + optional surah | Existing provider catalog |
| `/reciter` + canonical catalog entry | Existing reciter details |
| `/radio` | Existing radio/virtual radio UI with feature gate |
| `/my-library` | Personal library |
| `/downloads` | Existing Quran offline manager with feature gate |
| `/favorites` | Legacy and canonical catalog favorites |
| `/playlists` | Existing playlists |
| `/listening-history` | Persisted history with exact-identity resume |
| `/settings` | Existing user settings |
| `/search` | Central full screen search |
| `/player` | Existing full player |

Notification deep links preserve their prior semantics. In particular the old
`/library` notification opens Islamic content, not personal library.
Learning, Islamic content, recordings, prayer settings and push controls remain
reachable; they are not new bottom destinations.

## Screens and honest state

Home is a compact dashboard: reading position, existing prayer calculation,
optional persisted listening session, one playable radio and compact shortcuts.
No saved reading means an invitation to open the index. No session means no
continue-listening card. Radio disabled means no radio card/destination.
Prayer location comes from PrayerSettings; a one-minute timer refreshes the
existing service, without adding a prayer/reminder engine.

Index segments: Surahs, Juz, Pages, Bookmarks. Lists are lazy and keyed. Surah
and juz selection resolves the real first verse's page via the existing
repository. Missing revelation type/page/juz metadata in the Surah contract is
not invented; additional metadata awaits the existing provider contract.

Mushaf preserves the existing SVG/QCF assets, text, zoom, swipe, ayah hit areas,
playback, bookmarks, editions, thematic overlay, offline packs and sharing.
Controls adapt to small screens and large font settings. Page jump is a bottom
sheet. Immersive mode requests Android system UI changes and restores edge to
edge on exit. Unsupported OS-enforced system-bar behavior needs device QA.

Listen exposes readers, mushafs and surahs. The Mushafs tab now has its own lazy edition browser, labeled by actual
riwayah/edition and reciter/provider, using the same existing catalog and detail route. History resolves the saved provider/reader/edition/ayah
identity; it never silently substitutes another reader.

Search normalizes Arabic and digits, ignores stale asynchronous results, keeps
available results on partial source failure, uses lazy result rows, and offers
All/Quran/Readers/Radio filters. Surahs and reader results open actual routes.
Playlists use the existing local store. Verse search is not advertised because
this release's search contract does not support it.

## Design system

`theme.dart` owns Material 3 ColorScheme, complete TextTheme, spacing, shapes,
48dp interactive targets and motion. Screens consume ColorScheme semantics.

| Token | Value / meaning |
| --- | --- |
| Primary | Deep Indigo `#243B6B` |
| Dark primary identity | Dark Indigo `#162746` |
| Secondary | Acoustic Teal `#2E9E9E` |
| Tertiary | Copper `#C77955` |
| Light background | Pearl `#F8F6F1` |
| Dark background | Night `#0E1726` |
| Space | 4, 8, 12, 16, 24, 32dp |
| Radius | 8, 12, 16, 24, 28dp |

The legacy palette constant names remain compatibility aliases for existing
branding call sites. UI font is bundled Noto Sans Arabic, with OFL license and
checksum in THIRD_PARTY_NOTICES. Quran rendering/font choices remain separate.
Typography covers displaySmall/headlineSmall/titleLarge/titleMedium/bodyLarge/
bodyMedium/bodySmall/labelLarge/labelMedium/labelSmall.

Shared existing components: LoadingPane, EmptyPane, ErrorPane, SectionHeader,
Artwork, TarteelBrandMark and MiniPlayerBar. ContinueReadingCard is shared by
Home and index. EmptyPane scrolls its contents when constrained by a short
viewport. Offline/absent content is shown as unavailable, never demo verses.

## RTL, motion and accessibility

Arabic locale drives Directionality; Mushaf paging explicitly uses RTL.
Use directional padding, localized/Arabic labels and stable keys. Lists use
Lazy/Sliver builders. Quran ayah hit targets are preserved.
Named routes fade over 200ms; theme transitions are slight fades/slides.
MediaQuery.disableAnimations suppresses named/theme transitions. Reader overlay fades and previous/next page button motion also honor disableAnimations. Native swipe gestures remain direct manipulation.

LIVE has a visible text label, not only a colored dot. Play, favorites, page
navigation and player controls have tooltips/semantic labels. Font scaling and
small-screen layout are covered by widget and golden tests.

## Player UI

One existing PlaybackPort and audio_service/just_audio engine. No new player,
download manager, favorites database, repository or backend.
MediaItem null => Mini Player absent. Full Player consumes position/duration/
PlaybackState streams. Live streams have no seek bar. Quran audio supports
existing previous/next/speed/sleep behavior plus repeat, favorite and download
controls connected to the existing services. Download eligibility remains
owned by the existing download service/provider policies. A valid HTTPS live
URL is required for the share action.

## Validation

Flutter unit/widget/golden tests are the canonical UI tests. Roborazzi and
Compose instrumentation belong to the unrelated `main` scaffold and cannot
validate this verified Flutter APK. The Stage 0 workflow builds only a debug
APK, runs Android lint and uploads evidence; it never publishes a release.
Goldens include light/dark Home, index, offline reader, Listen, idle/active Radio, Library,
idle/active Full Player and Settings on 360x740, 412x915 and 1.6 font scale. Offline and
idle goldens do not prove live provider availability or downloaded page visual
fidelity. Android API 26 and modern-device playback/permission checks remain
explicit acceptance gates before Stage 0 can be called stable.

## Completed UI follow-up

Settings now groups Appearance, Language, Sound, Downloads/actual storage,
Notifications, Saved recordings, Privacy/consent, Sources/licenses and About.
Wi-Fi-only and global quality controls are not invented: the existing download
service has no network-policy setting, and edition quality remains selected
in the existing reciter detail UI. About includes GIT_SHA when supplied by CI.
Release notification settings hide developer diagnostics; consent and user
notification preferences retain their previous behavior.

Radio is a keyed lazy list with explicit playback/favorite actions, truthful
health labels, provider categories plus Haramain/Quran/Other/Favorites filters.
The on-air card reads the actual station, MediaItem and nowPlaying response.
Unknown programs/bitrates remain unavailable/absent. Lightweight decorative
activity exists only during playback, pauses with TickerMode and honors reduced
motion. The existing virtual-radio card remains available.

Large-font bottom navigation shows only the selected label while preserving
all destination labels for tooltips and semantics. Canonical and legacy reciter
favorites are recognized consistently in catalog and details.

Native CI adds actual APK install/start/crash-log/screenshot smoke checks on
API 26 and API 35. These checks do not certify live background audio, TalkBack,
permission interactions, or downloaded-page fidelity.
