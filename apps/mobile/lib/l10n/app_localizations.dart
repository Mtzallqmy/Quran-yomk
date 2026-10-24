import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Tarteel'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @radio.
  ///
  /// In en, this message translates to:
  /// **'Radio'**
  String get radio;

  /// No description provided for @reciters.
  ///
  /// In en, this message translates to:
  /// **'Reciters'**
  String get reciters;

  /// No description provided for @mushaf.
  ///
  /// In en, this message translates to:
  /// **'Mushaf'**
  String get mushaf;

  /// No description provided for @library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get live;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No content available'**
  String get noData;

  /// No description provided for @offlineMessage.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the service. Cached content may be shown.'**
  String get offlineMessage;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutTarteel.
  ///
  /// In en, this message translates to:
  /// **'About Tarteel'**
  String get aboutTarteel;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @terms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get terms;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get notAvailable;

  /// No description provided for @featuredTarteel.
  ///
  /// In en, this message translates to:
  /// **'Tarteel picks'**
  String get featuredTarteel;

  /// No description provided for @quranRadios.
  ///
  /// In en, this message translates to:
  /// **'Quran radios'**
  String get quranRadios;

  /// No description provided for @noRadiosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No radio stations are available right now.'**
  String get noRadiosAvailable;

  /// No description provided for @noRecitersIndexed.
  ///
  /// In en, this message translates to:
  /// **'No indexed recitations are available right now.'**
  String get noRecitersIndexed;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get favorite;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @unablePlayStation.
  ///
  /// In en, this message translates to:
  /// **'Unable to play {station}.'**
  String unablePlayStation(String station);

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get followSystem;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get playback;

  /// No description provided for @defaultRecitationSpeed.
  ///
  /// In en, this message translates to:
  /// **'Default recitation speed'**
  String get defaultRecitationSpeed;

  /// No description provided for @defaultRecitationSpeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Applies to on-demand recitations only, not live radio.'**
  String get defaultRecitationSpeedHelp;

  /// No description provided for @cancelSleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Cancel sleep timer'**
  String get cancelSleepTimer;

  /// No description provided for @savedClips.
  ///
  /// In en, this message translates to:
  /// **'Saved clips'**
  String get savedClips;

  /// No description provided for @savedClipsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Listen to locally saved clips offline'**
  String get savedClipsSubtitle;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About the app'**
  String get aboutSection;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App information, content sources, and copyright'**
  String get aboutSubtitle;

  /// No description provided for @contentSourcesCopyright.
  ///
  /// In en, this message translates to:
  /// **'Content sources and copyright'**
  String get contentSourcesCopyright;

  /// No description provided for @contentSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'External sources, attribution, and their applicable terms'**
  String get contentSourcesSubtitle;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @appRights.
  ///
  /// In en, this message translates to:
  /// **'App rights'**
  String get appRights;

  /// No description provided for @appRightsLine1.
  ///
  /// In en, this message translates to:
  /// **'Tarteel — ترتيل'**
  String get appRightsLine1;

  /// No description provided for @appRightsLine2.
  ///
  /// In en, this message translates to:
  /// **'Development and ownership: Moataz Al-Alqami'**
  String get appRightsLine2;

  /// No description provided for @appRightsLine3.
  ///
  /// In en, this message translates to:
  /// **'Taiz, Yemen'**
  String get appRightsLine3;

  /// No description provided for @appRightsLine4.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Moataz Al-Alqami. All application rights reserved.'**
  String get appRightsLine4;

  /// No description provided for @thirdPartyRights.
  ///
  /// In en, this message translates to:
  /// **'Third-party content sources and rights'**
  String get thirdPartyRights;

  /// No description provided for @thirdPartyOwnershipNotice.
  ///
  /// In en, this message translates to:
  /// **'Tarteel does not claim ownership of third-party radio stations, recitations, trademarks, or audio content. When playing an external station, your device may connect directly to the provider\'s infrastructure.'**
  String get thirdPartyOwnershipNotice;

  /// No description provided for @savedClipsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Offline clip saving is not available on this platform.'**
  String get savedClipsUnsupported;

  /// No description provided for @noSavedClips.
  ///
  /// In en, this message translates to:
  /// **'No saved clips yet'**
  String get noSavedClips;

  /// No description provided for @savingClip.
  ///
  /// In en, this message translates to:
  /// **'Saving clip…'**
  String get savingClip;

  /// No description provided for @stopSaving.
  ///
  /// In en, this message translates to:
  /// **'Stop saving'**
  String get stopSaving;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteClipQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete this clip?'**
  String get deleteClipQuestion;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @savedPartially.
  ///
  /// In en, this message translates to:
  /// **'partially saved'**
  String get savedPartially;

  /// No description provided for @fileMissing.
  ///
  /// In en, this message translates to:
  /// **'The saved clip file no longer exists.'**
  String get fileMissing;

  /// No description provided for @unablePlaySavedClip.
  ///
  /// In en, this message translates to:
  /// **'Unable to play the saved clip.'**
  String get unablePlaySavedClip;

  /// No description provided for @sleepTimer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimer;

  /// No description provided for @minutes10.
  ///
  /// In en, this message translates to:
  /// **'10 minutes'**
  String get minutes10;

  /// No description provided for @minutes20.
  ///
  /// In en, this message translates to:
  /// **'20 minutes'**
  String get minutes20;

  /// No description provided for @minutes30.
  ///
  /// In en, this message translates to:
  /// **'30 minutes'**
  String get minutes30;

  /// No description provided for @minutes45.
  ///
  /// In en, this message translates to:
  /// **'45 minutes'**
  String get minutes45;

  /// No description provided for @minutes60.
  ///
  /// In en, this message translates to:
  /// **'60 minutes'**
  String get minutes60;

  /// No description provided for @endOfCurrentRecitation.
  ///
  /// In en, this message translates to:
  /// **'End of current recitation'**
  String get endOfCurrentRecitation;

  /// No description provided for @timerCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer cancelled'**
  String get timerCancelled;

  /// No description provided for @stopsAfter.
  ///
  /// In en, this message translates to:
  /// **'Stops in {time}'**
  String stopsAfter(String time);

  /// No description provided for @player.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get player;

  /// No description provided for @noCurrentPlayback.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get noCurrentPlayback;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @stopLive.
  ///
  /// In en, this message translates to:
  /// **'Stop live stream'**
  String get stopLive;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @repeatSurah.
  ///
  /// In en, this message translates to:
  /// **'Repeat surah'**
  String get repeatSurah;

  /// No description provided for @liveTranscription.
  ///
  /// In en, this message translates to:
  /// **'Live transcription'**
  String get liveTranscription;

  /// No description provided for @transcriptionUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live transcription is unavailable in this build'**
  String get transcriptionUnavailable;

  /// No description provided for @browseBySection.
  ///
  /// In en, this message translates to:
  /// **'Browse by section'**
  String get browseBySection;

  /// No description provided for @quranSurahsCount.
  ///
  /// In en, this message translates to:
  /// **'Quran surahs — {count}'**
  String quranSurahsCount(int count);

  /// No description provided for @ayahCount.
  ///
  /// In en, this message translates to:
  /// **'{count} ayahs'**
  String ayahCount(int count);

  /// No description provided for @mushafTitle.
  ///
  /// In en, this message translates to:
  /// **'The Noble Quran'**
  String get mushafTitle;

  /// No description provided for @browseBySurah.
  ///
  /// In en, this message translates to:
  /// **'By surah'**
  String get browseBySurah;

  /// No description provided for @browseByJuz.
  ///
  /// In en, this message translates to:
  /// **'By juz'**
  String get browseByJuz;

  /// No description provided for @browseByPage.
  ///
  /// In en, this message translates to:
  /// **'By page'**
  String get browseByPage;

  /// No description provided for @surah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get surah;

  /// No description provided for @juz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get juz;

  /// No description provided for @page.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get page;

  /// No description provided for @pageOf604.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of 604'**
  String pageOf604(int page);

  /// No description provided for @selectSurah.
  ///
  /// In en, this message translates to:
  /// **'Select surah'**
  String get selectSurah;

  /// No description provided for @selectJuz.
  ///
  /// In en, this message translates to:
  /// **'Select juz'**
  String get selectJuz;

  /// No description provided for @selectPage.
  ///
  /// In en, this message translates to:
  /// **'Select page'**
  String get selectPage;

  /// No description provided for @lastReadingPosition.
  ///
  /// In en, this message translates to:
  /// **'Last reading position'**
  String get lastReadingPosition;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @bookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmark;

  /// No description provided for @removeBookmark.
  ///
  /// In en, this message translates to:
  /// **'Remove bookmark'**
  String get removeBookmark;

  /// No description provided for @bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get bookmarked;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get fontSize;

  /// No description provided for @tajweedColors.
  ///
  /// In en, this message translates to:
  /// **'Tajweed colors'**
  String get tajweedColors;

  /// No description provided for @thematicSections.
  ///
  /// In en, this message translates to:
  /// **'Thematic sections'**
  String get thematicSections;

  /// No description provided for @thematicRukuNote.
  ///
  /// In en, this message translates to:
  /// **'The section layer uses verified Ruku boundaries from the Quran source and never changes the Quran text.'**
  String get thematicRukuNote;

  /// No description provided for @chooseReciter.
  ///
  /// In en, this message translates to:
  /// **'Choose reciter'**
  String get chooseReciter;

  /// No description provided for @playSurah.
  ///
  /// In en, this message translates to:
  /// **'Play surah'**
  String get playSurah;

  /// No description provided for @noAudioForSurah.
  ///
  /// In en, this message translates to:
  /// **'No recitation is available for this surah with the selected reciter.'**
  String get noAudioForSurah;

  /// No description provided for @quranLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading Quran text…'**
  String get quranLoading;

  /// No description provided for @quranLoadError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load Quran text.'**
  String get quranLoadError;

  /// No description provided for @quranSource.
  ///
  /// In en, this message translates to:
  /// **'Quran text source'**
  String get quranSource;

  /// No description provided for @quranSourceFallback.
  ///
  /// In en, this message translates to:
  /// **'Quran Foundation when configured; Al Quran Cloud is used as the verified development fallback.'**
  String get quranSourceFallback;

  /// No description provided for @rukuLabel.
  ///
  /// In en, this message translates to:
  /// **'Ruku {number}'**
  String rukuLabel(int number);

  /// No description provided for @ayahNumber.
  ///
  /// In en, this message translates to:
  /// **'Ayah {number}'**
  String ayahNumber(int number);

  /// No description provided for @previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get previousPage;

  /// No description provided for @nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get nextPage;

  /// No description provided for @previousSurah.
  ///
  /// In en, this message translates to:
  /// **'Previous surah'**
  String get previousSurah;

  /// No description provided for @nextSurah.
  ///
  /// In en, this message translates to:
  /// **'Next surah'**
  String get nextSurah;

  /// No description provided for @mushafSettings.
  ///
  /// In en, this message translates to:
  /// **'Reading settings'**
  String get mushafSettings;

  /// No description provided for @showTajweed.
  ///
  /// In en, this message translates to:
  /// **'Show Tajweed colors'**
  String get showTajweed;

  /// No description provided for @showThemes.
  ///
  /// In en, this message translates to:
  /// **'Show thematic sections'**
  String get showThemes;

  /// No description provided for @readerModeSurah.
  ///
  /// In en, this message translates to:
  /// **'Surah'**
  String get readerModeSurah;

  /// No description provided for @readerModeJuz.
  ///
  /// In en, this message translates to:
  /// **'Juz'**
  String get readerModeJuz;

  /// No description provided for @readerModePage.
  ///
  /// In en, this message translates to:
  /// **'Page'**
  String get readerModePage;

  /// No description provided for @reciterToday.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciterToday;

  /// No description provided for @sourceCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current source'**
  String get sourceCurrent;

  /// No description provided for @directExternalStream.
  ///
  /// In en, this message translates to:
  /// **'External stream'**
  String get directExternalStream;

  /// No description provided for @currentProgram.
  ///
  /// In en, this message translates to:
  /// **'Current program'**
  String get currentProgram;

  /// No description provided for @nextProgram.
  ///
  /// In en, this message translates to:
  /// **'Next program'**
  String get nextProgram;

  /// No description provided for @tarteelRadio.
  ///
  /// In en, this message translates to:
  /// **'Tarteel Radio'**
  String get tarteelRadio;

  /// No description provided for @tarteelCuratedLive.
  ///
  /// In en, this message translates to:
  /// **'Tarteel — curated live stream'**
  String get tarteelCuratedLive;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get showAll;

  /// No description provided for @searchStationsHint.
  ///
  /// In en, this message translates to:
  /// **'Search stations'**
  String get searchStationsHint;

  /// No description provided for @noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noSearchResults;

  /// No description provided for @unablePlay.
  ///
  /// In en, this message translates to:
  /// **'Unable to play audio.'**
  String get unablePlay;

  /// No description provided for @contentSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Source information is unavailable right now.'**
  String get contentSourceUnavailable;

  /// No description provided for @loadingSources.
  ///
  /// In en, this message translates to:
  /// **'Loading content sources…'**
  String get loadingSources;

  /// No description provided for @externalSourceDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Some audio is delivered directly from third-party providers. Rights and trademarks remain with their respective owners.'**
  String get externalSourceDisclaimer;

  /// No description provided for @recordingNotPermitted.
  ///
  /// In en, this message translates to:
  /// **'Saving clips is not permitted for this station.'**
  String get recordingNotPermitted;

  /// No description provided for @saveOfflineClip.
  ///
  /// In en, this message translates to:
  /// **'Save clip for offline listening'**
  String get saveOfflineClip;

  /// No description provided for @save5Minutes.
  ///
  /// In en, this message translates to:
  /// **'Save 5 minutes'**
  String get save5Minutes;

  /// No description provided for @save10Minutes.
  ///
  /// In en, this message translates to:
  /// **'Save 10 minutes'**
  String get save10Minutes;

  /// No description provided for @save30Minutes.
  ///
  /// In en, this message translates to:
  /// **'Save 30 minutes'**
  String get save30Minutes;

  /// No description provided for @saveUntilStopped.
  ///
  /// In en, this message translates to:
  /// **'Save until stopped'**
  String get saveUntilStopped;

  /// No description provided for @clipSavingStarted.
  ///
  /// In en, this message translates to:
  /// **'Clip saving started'**
  String get clipSavingStarted;

  /// No description provided for @clipSavingStopped.
  ///
  /// In en, this message translates to:
  /// **'Clip saved'**
  String get clipSavingStopped;

  /// No description provided for @clipSavingFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to save this clip.'**
  String get clipSavingFailed;

  /// No description provided for @networkRequiredForPlayback.
  ///
  /// In en, this message translates to:
  /// **'Internet connection is required for live playback.'**
  String get networkRequiredForPlayback;

  /// No description provided for @searchReciters.
  ///
  /// In en, this message translates to:
  /// **'Search reciters'**
  String get searchReciters;

  /// No description provided for @noReciters.
  ///
  /// In en, this message translates to:
  /// **'No reciters found'**
  String get noReciters;

  /// No description provided for @reciterDetails.
  ///
  /// In en, this message translates to:
  /// **'Reciter'**
  String get reciterDetails;

  /// No description provided for @availableSurahs.
  ///
  /// In en, this message translates to:
  /// **'Available surahs'**
  String get availableSurahs;

  /// No description provided for @noTracks.
  ///
  /// In en, this message translates to:
  /// **'No playable surahs are available for this reciter.'**
  String get noTracks;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search stations, reciters, surahs, or sections'**
  String get searchHint;

  /// No description provided for @searchSections.
  ///
  /// In en, this message translates to:
  /// **'Sections'**
  String get searchSections;

  /// No description provided for @searchStations.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get searchStations;

  /// No description provided for @searchSurahs.
  ///
  /// In en, this message translates to:
  /// **'Surahs'**
  String get searchSurahs;

  /// No description provided for @searchReciterResults.
  ///
  /// In en, this message translates to:
  /// **'Reciters'**
  String get searchReciterResults;

  /// No description provided for @radioGeneralQuran.
  ///
  /// In en, this message translates to:
  /// **'General Quran'**
  String get radioGeneralQuran;

  /// No description provided for @radioReciters.
  ///
  /// In en, this message translates to:
  /// **'Reciters'**
  String get radioReciters;

  /// No description provided for @radioTafseer.
  ///
  /// In en, this message translates to:
  /// **'Tafsir'**
  String get radioTafseer;

  /// No description provided for @radioHadith.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get radioHadith;

  /// No description provided for @radioSeerah.
  ///
  /// In en, this message translates to:
  /// **'Seerah'**
  String get radioSeerah;

  /// No description provided for @radioSahabah.
  ///
  /// In en, this message translates to:
  /// **'Companions'**
  String get radioSahabah;

  /// No description provided for @radioAdhkar.
  ///
  /// In en, this message translates to:
  /// **'Adhkar'**
  String get radioAdhkar;

  /// No description provided for @radioRuqyah.
  ///
  /// In en, this message translates to:
  /// **'Ruqyah'**
  String get radioRuqyah;

  /// No description provided for @radioFatwa.
  ///
  /// In en, this message translates to:
  /// **'Fatwas'**
  String get radioFatwa;

  /// No description provided for @radioTranslation.
  ///
  /// In en, this message translates to:
  /// **'Quran translations'**
  String get radioTranslation;

  /// No description provided for @radioSurahs.
  ///
  /// In en, this message translates to:
  /// **'Selected surahs'**
  String get radioSurahs;

  /// No description provided for @radioLiveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV audio'**
  String get radioLiveTv;

  /// No description provided for @radioOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get radioOther;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
