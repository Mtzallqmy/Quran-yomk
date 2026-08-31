import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'playback.dart';
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
    required this.playback,
  });
  final TarteelRepository repository;
  final FavoritesStore favorites;
  final SettingsStore settings;
  final PlaybackPort playback;
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('AppServices must be overridden at startup'),
);
