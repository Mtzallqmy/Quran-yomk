import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback.dart';
import 'repository.dart';
import 'storage.dart';

class AppServices {
  const AppServices({required this.repository, required this.favorites, required this.settings, required this.playback});
  final TarteelRepository repository;
  final FavoritesStore favorites;
  final SettingsStore settings;
  final PlaybackPort playback;
}

final servicesProvider = Provider<AppServices>((ref) => throw StateError('AppServices must be overridden at startup'));
