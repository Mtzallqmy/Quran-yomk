import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/adaptive_adhkar_reminders.dart';
import 'src/api.dart';
import 'src/adhan_audio.dart';
import 'src/announcements.dart';
import 'src/app.dart';
import 'src/background_reminders.dart';
import 'src/feature_manager.dart';
import 'src/islamic_content.dart';
import 'src/local_notifications.dart';
import 'src/learning.dart';
import 'src/mushaf_pages.dart';
import 'src/mushaf_store.dart';
import 'src/notification_consent_service.dart';
import 'src/offline_clip_service.dart';
import 'src/personal_reminders.dart';
import 'src/playback.dart';
import 'src/quran_audio.dart';
import 'src/quran_download_service.dart';
import 'src/quran_playback_store.dart';
import 'src/quran_playlist_store.dart';
import 'src/prayer_reminders.dart';
import 'src/prayer_settings.dart';
import 'src/prayer_times.dart';
import 'src/push_notifications.dart';
import 'src/remote_config.dart';
import 'src/repository.dart';
import 'src/services.dart';
import 'src/storage.dart';
import 'src/startup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  late TarteelAudioHandler playback;
  await AudioService.init(
    builder: () {
      playback = TarteelAudioHandler();
      return playback;
    },
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'app.tarteel.tarteel.audio',
      androidNotificationChannelName: 'Tarteel audio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  await playback.initialize();

  final preferences = await SharedPreferences.getInstance();
  final favorites = FavoritesStore(preferences)..load();
  final settings = SettingsStore(preferences)..load();
  final mushaf = MushafStore(preferences)..load();
  final mushafPages = MushafPageRepository();
  final islamicContent = IslamicContentRepository();
  final offlineClips = createOfflineClipService(preferences);
  final quranDownloads = createQuranDownloadService(preferences);
  final quranAudio = QuranAudioRepository(
    providers: <QuranAudioProvider>[
      AlQuranCloudAudioProvider(),
      Mp3QuranAudioProvider(),
    ],
    localLookup: quranDownloads,
  );
  final quranPlayback = QuranPlaybackStore(preferences)..load();
  quranPlayback.bind(playback);
  final quranPlaylists = QuranPlaylistStore(preferences)..load();
  final api = TarteelApiClient();
  final repository = TarteelRepository(api, MetadataCache(preferences));
  final remoteConfig = TarteelRemoteConfig(repository, preferences)..load();
  final announcements = AnnouncementService(preferences);
  final packageInfo = await PackageInfo.fromPlatform();
  final features = FeatureManager(
    config: remoteConfig,
    installedVersion: packageInfo.version,
  );

  final localNotifications = LocalNotificationService();
  final prayerSettings = PrayerSettingsStore(preferences)..load();
  final prayerTimes = PrayerTimesService();
  final learning = LearningStore(preferences)..load();
  final adhkarReminders = AdaptiveAdhkarReminderController(
    notifications: localNotifications,
    store: learning,
    prayerSettings: prayerSettings,
  );
  final personalReminderStore = PersonalReminderStore(preferences)..load();
  final personalReminders = PersonalReminderController(
    notifications: localNotifications,
    store: personalReminderStore,
    prayerSettings: prayerSettings,
  );
  final adhanAudio = AdhanAudioService(playback: playback);
  final prayerReminders = PrayerReminderController(
    notifications: localNotifications,
    prayerTimes: prayerTimes,
    settings: prayerSettings,
    adhanAudio: adhanAudio,
  );

  Future<void> enableLocalDefaults() async {
    if (preferences.getBool('local:defaults_activated:v1') == true) return;
    await prayerSettings.setRemindersEnabled(true);
    for (final category in const <String>['morning', 'evening', 'sleep']) {
      await learning.setReminderMode(category, AdhkarReminderMode.tone);
    }
    for (final key in const <String>['salawat', 'daily_wird', 'daily_quran']) {
      await personalReminderStore.setEnabled(key, true);
    }
    await prayerReminders.reconcile();
    await adhkarReminders.start();
    await personalReminders.reconcile();
    await preferences.setBool('local:defaults_activated:v1', true);
  }

  final pushNotifications = TarteelPushNotificationService(
    preferences: preferences,
    localNotifications: localNotifications,
    onLocalConsentGranted: enableLocalDefaults,
  );

  final services = AppServices(
    repository: repository,
    favorites: favorites,
    settings: settings,
    mushaf: mushaf,
    mushafPages: mushafPages,
    islamicContent: islamicContent,
    offlineClips: offlineClips,
    playback: playback,
    quranAudio: quranAudio,
    quranDownloads: quranDownloads,
    quranPlayback: quranPlayback,
    quranPlaylists: quranPlaylists,
    remoteConfig: remoteConfig,
    announcements: announcements,
    features: features,
    localNotifications: localNotifications,
    prayerSettings: prayerSettings,
    prayerTimes: prayerTimes,
    prayerReminders: prayerReminders,
    adhanAudio: adhanAudio,
    pushNotifications: pushNotifications,
    learning: learning,
    adhkarReminders: adhkarReminders,
    personalReminderStore: personalReminderStore,
    personalReminders: personalReminders,
  );

  await initializeReminderBackgroundWork();

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TarteelApp(),
    ),
  );

  initializeAfterFirstFrame(<String, Future<void> Function()>{
    'offline_clips': offlineClips.initialize,
    'quran_downloads': quranDownloads.initialize,
    'islamic_content': islamicContent.synchronizeInBackground,
    'runtime_config_and_reminders': () async {
      await remoteConfig.refresh();
      if (features.enabled(TarteelFeature.prayer)) {
        await prayerReminders.start();
      } else {
        await prayerReminders.suspend();
      }
      if (features.enabled(TarteelFeature.adhkar)) {
        await adhkarReminders.start();
      } else {
        await adhkarReminders.suspend();
      }
      await personalReminders.start();
    },
    'push_notifications': pushNotifications.initialize,
    'announcements': announcements.refresh,
  });
}
