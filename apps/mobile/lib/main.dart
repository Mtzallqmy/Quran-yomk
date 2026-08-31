import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/api.dart';
import 'src/app.dart';
import 'src/mushaf_store.dart';
import 'src/offline_clip_service.dart';
import 'src/playback.dart';
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
  final offlineClips = createOfflineClipService(preferences);
  await offlineClips.initialize();
  final api = TarteelApiClient();
  final repository = TarteelRepository(api, MetadataCache(preferences));
  final services = AppServices(
    repository: repository,
    favorites: favorites,
    settings: settings,
    mushaf: mushaf,
    offlineClips: offlineClips,
    playback: playback,
  );

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const TarteelApp(),
    ),
  );
}
