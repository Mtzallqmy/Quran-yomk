// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Tarteel';

  @override
  String get home => 'Home';

  @override
  String get radio => 'Radio';

  @override
  String get reciters => 'Reciters';

  @override
  String get mushaf => 'Mushaf';

  @override
  String get library => 'Library';

  @override
  String get favorites => 'Favorites';

  @override
  String get settings => 'Settings';

  @override
  String get search => 'Search';

  @override
  String get live => 'LIVE';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading…';

  @override
  String get noData => 'No content available';

  @override
  String get offlineMessage =>
      'Unable to reach the service. Cached content may be shown.';

  @override
  String get about => 'About';

  @override
  String get aboutTarteel => 'About Tarteel';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get terms => 'Terms';

  @override
  String get support => 'Support';

  @override
  String get notAvailable => 'Not available yet';

  @override
  String get featuredTarteel => 'Tarteel picks';

  @override
  String get quranRadios => 'Quran radios';

  @override
  String get noRadiosAvailable => 'No radio stations are available right now.';

  @override
  String get noRecitersIndexed =>
      'No indexed recitations are available right now.';

  @override
  String get categories => 'Categories';

  @override
  String get favorite => 'Favorite';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String unablePlayStation(String station) {
    return 'Unable to play $station.';
  }

  @override
  String get appearance => 'Appearance';

  @override
  String get followSystem => 'System default';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get arabic => 'Arabic';

  @override
  String get english => 'English';

  @override
  String get playback => 'Playback';

  @override
  String get defaultRecitationSpeed => 'Default recitation speed';

  @override
  String get defaultRecitationSpeedHelp =>
      'Applies to on-demand recitations only, not live radio.';

  @override
  String get cancelSleepTimer => 'Cancel sleep timer';

  @override
  String get savedClips => 'Saved clips';

  @override
  String get savedClipsSubtitle => 'Listen to locally saved clips offline';

  @override
  String get aboutSection => 'About the app';

  @override
  String get aboutSubtitle => 'App information, content sources, and copyright';

  @override
  String get contentSourcesCopyright => 'Content sources and copyright';

  @override
  String get contentSourcesSubtitle =>
      'External sources, attribution, and their applicable terms';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get appRights => 'App rights';

  @override
  String get appRightsLine1 => 'Tarteel — ترتيل';

  @override
  String get appRightsLine2 => 'Development and ownership: Moataz Al-Alqami';

  @override
  String get appRightsLine3 => 'Taiz, Yemen';

  @override
  String get appRightsLine4 =>
      '© 2026 Moataz Al-Alqami. All application rights reserved.';

  @override
  String get thirdPartyRights => 'Third-party content sources and rights';

  @override
  String get thirdPartyOwnershipNotice =>
      'Tarteel does not claim ownership of third-party radio stations, recitations, trademarks, or audio content. When playing an external station, your device may connect directly to the provider\'s infrastructure.';

  @override
  String get savedClipsUnsupported =>
      'Offline clip saving is not available on this platform.';

  @override
  String get noSavedClips => 'No saved clips yet';

  @override
  String get savingClip => 'Saving clip…';

  @override
  String get stopSaving => 'Stop saving';

  @override
  String get delete => 'Delete';

  @override
  String get deleteClipQuestion => 'Delete this clip?';

  @override
  String get cancel => 'Cancel';

  @override
  String get savedPartially => 'partially saved';

  @override
  String get fileMissing => 'The saved clip file no longer exists.';

  @override
  String get unablePlaySavedClip => 'Unable to play the saved clip.';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get minutes10 => '10 minutes';

  @override
  String get minutes20 => '20 minutes';

  @override
  String get minutes30 => '30 minutes';

  @override
  String get minutes45 => '45 minutes';

  @override
  String get minutes60 => '60 minutes';

  @override
  String get endOfCurrentRecitation => 'End of current recitation';

  @override
  String get timerCancelled => 'Sleep timer cancelled';

  @override
  String stopsAfter(String time) {
    return 'Stops in $time';
  }

  @override
  String get player => 'Player';

  @override
  String get noCurrentPlayback => 'Nothing is playing';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get stopLive => 'Stop live stream';

  @override
  String get volume => 'Volume';

  @override
  String get repeatSurah => 'Repeat surah';

  @override
  String get liveTranscription => 'Live transcription';

  @override
  String get transcriptionUnavailable =>
      'Live transcription is unavailable in this build';

  @override
  String get browseBySection => 'Browse by section';

  @override
  String quranSurahsCount(int count) {
    return 'Quran surahs — $count';
  }

  @override
  String ayahCount(int count) {
    return '$count ayahs';
  }

  @override
  String get mushafTitle => 'The Noble Quran';

  @override
  String get browseBySurah => 'By surah';

  @override
  String get browseByJuz => 'By juz';

  @override
  String get browseByPage => 'By page';

  @override
  String get surah => 'Surah';

  @override
  String get juz => 'Juz';

  @override
  String get page => 'Page';

  @override
  String pageOf604(int page) {
    return 'Page $page of 604';
  }

  @override
  String get selectSurah => 'Select surah';

  @override
  String get selectJuz => 'Select juz';

  @override
  String get selectPage => 'Select page';

  @override
  String get lastReadingPosition => 'Last reading position';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get bookmark => 'Bookmark';

  @override
  String get removeBookmark => 'Remove bookmark';

  @override
  String get bookmarked => 'Bookmarked';

  @override
  String get fontSize => 'Text size';

  @override
  String get tajweedColors => 'Tajweed colors';

  @override
  String get thematicSections => 'Thematic sections';

  @override
  String get thematicRukuNote =>
      'The section layer uses verified Ruku boundaries from the Quran source and never changes the Quran text.';

  @override
  String get chooseReciter => 'Choose reciter';

  @override
  String get playSurah => 'Play surah';

  @override
  String get noAudioForSurah =>
      'No recitation is available for this surah with the selected reciter.';

  @override
  String get quranLoading => 'Loading Quran text…';

  @override
  String get quranLoadError => 'Unable to load Quran text.';

  @override
  String get quranSource => 'Quran text source';

  @override
  String get quranSourceFallback =>
      'Quran Foundation when configured; Al Quran Cloud is used as the verified development fallback.';

  @override
  String rukuLabel(int number) {
    return 'Ruku $number';
  }

  @override
  String ayahNumber(int number) {
    return 'Ayah $number';
  }

  @override
  String get previousPage => 'Previous page';

  @override
  String get nextPage => 'Next page';

  @override
  String get previousSurah => 'Previous surah';

  @override
  String get nextSurah => 'Next surah';

  @override
  String get mushafSettings => 'Reading settings';

  @override
  String get showTajweed => 'Show Tajweed colors';

  @override
  String get showThemes => 'Show thematic sections';

  @override
  String get readerModeSurah => 'Surah';

  @override
  String get readerModeJuz => 'Juz';

  @override
  String get readerModePage => 'Page';

  @override
  String get reciterToday => 'Reciter';

  @override
  String get sourceCurrent => 'Current source';

  @override
  String get directExternalStream => 'External stream';

  @override
  String get currentProgram => 'Current program';

  @override
  String get nextProgram => 'Next program';

  @override
  String get tarteelRadio => 'Tarteel Radio';

  @override
  String get tarteelCuratedLive => 'Tarteel — curated live stream';

  @override
  String get all => 'All';

  @override
  String get showAll => 'Show all';

  @override
  String get searchStationsHint => 'Search stations';

  @override
  String get noSearchResults => 'No results';

  @override
  String get unablePlay => 'Unable to play audio.';

  @override
  String get contentSourceUnavailable =>
      'Source information is unavailable right now.';

  @override
  String get loadingSources => 'Loading content sources…';

  @override
  String get externalSourceDisclaimer =>
      'Some audio is delivered directly from third-party providers. Rights and trademarks remain with their respective owners.';

  @override
  String get recordingNotPermitted =>
      'Saving clips is not permitted for this station.';

  @override
  String get saveOfflineClip => 'Save clip for offline listening';

  @override
  String get save5Minutes => 'Save 5 minutes';

  @override
  String get save10Minutes => 'Save 10 minutes';

  @override
  String get save30Minutes => 'Save 30 minutes';

  @override
  String get saveUntilStopped => 'Save until stopped';

  @override
  String get clipSavingStarted => 'Clip saving started';

  @override
  String get clipSavingStopped => 'Clip saved';

  @override
  String get clipSavingFailed => 'Unable to save this clip.';

  @override
  String get networkRequiredForPlayback =>
      'Internet connection is required for live playback.';

  @override
  String get searchReciters => 'Search reciters';

  @override
  String get noReciters => 'No reciters found';

  @override
  String get reciterDetails => 'Reciter';

  @override
  String get availableSurahs => 'Available surahs';

  @override
  String get noTracks => 'No playable surahs are available for this reciter.';

  @override
  String get searchHint => 'Search stations, reciters, surahs, or sections';

  @override
  String get searchSections => 'Sections';

  @override
  String get searchStations => 'Stations';

  @override
  String get searchSurahs => 'Surahs';

  @override
  String get searchReciterResults => 'Reciters';

  @override
  String get radioGeneralQuran => 'General Quran';

  @override
  String get radioReciters => 'Reciters';

  @override
  String get radioTafseer => 'Tafsir';

  @override
  String get radioHadith => 'Hadith';

  @override
  String get radioSeerah => 'Seerah';

  @override
  String get radioSahabah => 'Companions';

  @override
  String get radioAdhkar => 'Adhkar';

  @override
  String get radioRuqyah => 'Ruqyah';

  @override
  String get radioFatwa => 'Fatwas';

  @override
  String get radioTranslation => 'Quran translations';

  @override
  String get radioSurahs => 'Selected surahs';

  @override
  String get radioLiveTv => 'Live TV audio';

  @override
  String get radioOther => 'Other';
}
