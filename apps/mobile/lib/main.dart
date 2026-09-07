import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api.dart';
import 'src/admin_api.dart';
import 'src/adhan_audio.dart';
import 'src/app.dart';
import 'src/islamic_content.dart';
import 'src/local_notifications.dart';
import 'src/learning.dart';
import 'src/mushaf_pages.dart';
import 'src/mushaf_store.dart';
import 'src/offline_clip_service.dart';
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
  final localNotifications = LocalNotificationService();
  final learning = LearningStore(preferences)..load();
  final adhkarReminders = AdhkarReminderController(
    notifications: localNotifications,
    store: learning,
  );
  final prayerSettings = PrayerSettingsStore(preferences)..load();
  final prayerTimes = PrayerTimesService();
  final adhanAudio = AdhanAudioService(playback: playback);
  final prayerReminders = PrayerReminderController(
    notifications: localNotifications,
    prayerTimes: prayerTimes,
    settings: prayerSettings,
    adhanAudio: adhanAudio,
  );
  final pushNotifications = PushNotificationService(
    preferences: preferences,
    localNotifications: localNotifications,
  );
  final adminSession = MobileAdminSession(
    onAuthenticationChanged: pushNotifications.attachAuthenticatedUser,
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
    localNotifications: localNotifications,
    prayerSettings: prayerSettings,
    prayerTimes: prayerTimes,
    prayerReminders: prayerReminders,
    adhanAudio: adhanAudio,
    pushNotifications: pushNotifications,
    adminSession: adminSession,
    learning: learning,
    adhkarReminders: adhkarReminders,
  );

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
    'remote_config': remoteConfig.refresh,
    'prayer_reminders': prayerReminders.start,
    'admin_session': adminSession.restore,
    'adhkar_reminders': adhkarReminders.start,
  });
}
