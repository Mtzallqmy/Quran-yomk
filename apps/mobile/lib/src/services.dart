import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mushaf_store.dart';
import 'mushaf_pages.dart';
import 'offline_clip_service.dart';
import 'playback.dart';
import 'quran_audio.dart';
import 'quran_download_service.dart';
import 'quran_playback_store.dart';
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
    required this.offlineClips,
    required this.playback,
    required this.quranAudio,
    required this.quranDownloads,
    required this.quranPlayback,
  });

  final TarteelRepository repository;
  final FavoritesStore favorites;
  final SettingsStore settings;
  final MushafStore mushaf;
  final MushafPageRepository mushafPages;
  final OfflineClipService offlineClips;
  final PlaybackPort playback;
  final QuranAudioRepository quranAudio;
  final QuranDownloadService quranDownloads;
  final QuranPlaybackStore quranPlayback;
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices must be overridden at startup'),
);
