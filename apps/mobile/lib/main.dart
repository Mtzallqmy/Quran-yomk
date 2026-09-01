import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api.dart';
import 'src/app.dart';
import 'src/islamic_content.dart';
import 'src/mushaf_store.dart';
import 'src/mushaf_pages.dart';
import 'src/offline_clip_service.dart';
import 'src/playback.dart';
import 'src/quran_audio.dart';
import 'src/quran_download_service.dart';
import 'src/quran_playback_store.dart';
import 'src/repository.dart';
import 'src/services.dart';
import 'src/storage.dart';

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
  await mushafPages.initialize();
  final islamicContent = IslamicContentRepository();
  await islamicContent.initialize();
  unawaited(islamicContent.synchronizeInBackground());
  final offlineClips = createOfflineClipService(preferences);
  await offlineClips.initialize();
  final quranDownloads = createQuranDownloadService(preferences);
  await quranDownloads.initialize();
  final quranAudio = QuranAudioRepository(
    providers: <QuranAudioProvider>[
      AlQuranCloudAudioProvider(),
      Mp3QuranAudioProvider(),
    ],
    localLookup: quranDownloads,
  );
  final quranPlayback = QuranPlaybackStore(preferences)..load();
  quranPlayback.bind(playback);
  final api = TarteelApiClient();
  final repository = TarteelRepository(api, MetadataCache(preferences));
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
  );

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TarteelApp(),
    ),
  );
}
