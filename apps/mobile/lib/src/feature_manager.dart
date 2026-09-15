import 'package:flutter/foundation.dart';

import 'remote_config.dart';

enum TarteelFeature { radio, offlineDownloads, prayer, adhkar }

@immutable
class SemanticVersion implements Comparable<SemanticVersion> {
  const SemanticVersion(this.major, this.minor, this.patch);

  factory SemanticVersion.parse(String value) {
    final normalized = value.trim().split('+').first.split('-').first;
    final parts = normalized.split('.');
    if (parts.isEmpty || parts.length > 3) {
      throw const FormatException('INVALID_SEMANTIC_VERSION');
    }
    final numbers = <int>[];
    for (final part in parts) {
      final number = int.tryParse(part);
      if (number == null || number < 0) {
        throw const FormatException('INVALID_SEMANTIC_VERSION');
      }
      numbers.add(number);
    }
    while (numbers.length < 3) {
      numbers.add(0);
    }
    return SemanticVersion(numbers[0], numbers[1], numbers[2]);
  }

  static SemanticVersion safe(String value) {
    try {
      return SemanticVersion.parse(value);
    } catch (_) {
      return const SemanticVersion(0, 0, 0);
    }
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(SemanticVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }
}

enum UpdateRequirement { none, available, recommended, required }

class FeatureManager extends ChangeNotifier {
  FeatureManager({
    required TarteelRemoteConfig config,
    required String installedVersion,
  }) : _config = config,
       _installedVersion = SemanticVersion.safe(installedVersion) {
    _config.addListener(_changed);
  }

  final TarteelRemoteConfig _config;
  final SemanticVersion _installedVersion;

  bool enabled(TarteelFeature feature) => switch (feature) {
    TarteelFeature.radio => _config.radioEnabled,
    TarteelFeature.offlineDownloads => _config.offlineDownloadsEnabled,
    TarteelFeature.prayer => _config.prayerFeaturesEnabled,
    TarteelFeature.adhkar => _config.adhkarEnabled,
  };

  bool get maintenanceMode => _config.maintenanceMode;
  String get maintenanceMessage => _config.maintenanceMessage;
  String get announcementBanner => _config.announcementBanner;

  UpdateRequirement get updateRequirement {
    final minimum = SemanticVersion.safe(_config.minimumAndroidVersion);
    final recommended = SemanticVersion.safe(_config.recommendedAndroidVersion);
    final latest = SemanticVersion.safe(_config.latestAndroidVersion);
    if (_installedVersion.compareTo(minimum) < 0) {
      return UpdateRequirement.required;
    }
    if (_installedVersion.compareTo(recommended) < 0) {
      return UpdateRequirement.recommended;
    }
    if (_installedVersion.compareTo(latest) < 0) {
      return UpdateRequirement.available;
    }
    return UpdateRequirement.none;
  }

  bool routeAllowed(String route) => switch (route) {
    '/radio' => enabled(TarteelFeature.radio),
    '/prayer-times' || '/custom-reminders' => enabled(TarteelFeature.prayer),
    '/adhkar' => enabled(TarteelFeature.adhkar),
    _ => true,
  };

  void _changed() => notifyListeners();

  @override
  void dispose() {
    _config.removeListener(_changed);
    super.dispose();
  }
}
