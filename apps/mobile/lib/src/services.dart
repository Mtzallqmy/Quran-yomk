import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'adhan_audio.dart';
import 'islamic_content.dart';
import 'local_notifications.dart';
import 'mushaf_pages.dart';
import 'mushaf_store.dart';
import 'offline_clip_service.dart';
import 'playback.dart';
import 'quran_audio.dart';
import 'quran_download_service.dart';
import 'quran_playback_store.dart';
import 'quran_playlist_store.dart';
import 'prayer_reminders.dart';
import 'prayer_settings.dart';
import 'prayer_times.dart';
import 'remote_config.dart';
import 'repository.dart';
import 'storage.dart';

/// Compatibility helper for Riverpod releases where AsyncValue.valueOrNull
/// is not part of the public API. Keeps call sites concise without reading a
/// previous value from loading/error states.
extension AsyncValueCompat<T> on AsyncValue<T> {
  T? get valueOrNull => asData?.value;
}

class AppServices {
  const AppServices({
    required this.repository,
    required this.favorites,
    required this.settings,
    required this.mushaf,
    required this.mushafPages,
    required this.islamicContent,
    required this.offlineClips,
    required this.playback,
    required this.quranAudio,
    required this.quranDownloads,
    required this.quranPlayback,
    required this.quranPlaylists,
    required this.remoteConfig,
    required this.localNotifications,
    required this.prayerSettings,
    required this.prayerTimes,
    required this.prayerReminders,
    required this.adhanAudio,
  });

  final TarteelRepository repository;
  final FavoritesStore favorites;
  final SettingsStore settings;
  final MushafStore mushaf;
  final MushafPageRepository mushafPages;
  final IslamicContentRepository islamicContent;
  final OfflineClipService offlineClips;
  final PlaybackPort playback;
  final QuranAudioRepository quranAudio;
  final QuranDownloadService quranDownloads;
  final QuranPlaybackStore quranPlayback;
  final QuranPlaylistStore quranPlaylists;
  final TarteelRemoteConfig remoteConfig;
  final LocalNotificationService localNotifications;
  final PrayerSettingsStore prayerSettings;
  final PrayerTimesService prayerTimes;
  final PrayerReminderController prayerReminders;
  final AdhanAudioService adhanAudio;
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices must be overridden at startup'),
);
