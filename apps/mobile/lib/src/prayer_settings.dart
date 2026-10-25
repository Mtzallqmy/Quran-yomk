import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

enum PrayerCalculationMethod {
  muslimWorldLeague,
  egyptian,
  ummAlQura,
  karachi,
  northAmerica,
}

enum PrayerAsrMethod { shafi, hanafi }

enum PrayerReminderMode {
  disabled,
  silent,
  notificationOnly,
  adhan,
  shortAlert,
}

extension PrayerReminderModeLabel on PrayerReminderMode {
  String get nameAr => switch (this) {
    PrayerReminderMode.disabled => 'متوقف',
    PrayerReminderMode.silent => 'إشعار صامت',
    PrayerReminderMode.notificationOnly => 'إشعار فقط',
    PrayerReminderMode.adhan => 'إشعار وأذان',
    PrayerReminderMode.shortAlert => 'تنبيه صوتي قصير',
  };
}

extension PrayerKindLabel on PrayerKind {
  String get nameAr => switch (this) {
    PrayerKind.fajr => 'الفجر',
    PrayerKind.sunrise => 'الشروق',
    PrayerKind.dhuhr => 'الظهر',
    PrayerKind.asr => 'العصر',
    PrayerKind.maghrib => 'المغرب',
    PrayerKind.isha => 'العشاء',
  };

  bool get isRequiredPrayer => this != PrayerKind.sunrise;
}

@immutable
class PrayerSettings {
  const PrayerSettings({
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.timezone,
    required this.calculationMethod,
    required this.asrMethod,
    required this.offsets,
    required this.remindersEnabled,
    this.reminderModes = const <PrayerKind, PrayerReminderMode>{},
    this.manualTimes = const <PrayerKind, int>{},
    this.beforeMinutes = const <PrayerKind, int>{},
    this.afterMinutes = const <PrayerKind, int>{},
    this.audioPaths = const <PrayerKind, String>{},
    this.volumes = const <PrayerKind, double>{},
  });

  factory PrayerSettings.taiz() => PrayerSettings(
    locationName: 'تعز',
    latitude: 13.5795,
    longitude: 44.0209,
    timezone: 'Asia/Aden',
    calculationMethod: PrayerCalculationMethod.muslimWorldLeague,
    asrMethod: PrayerAsrMethod.shafi,
    offsets: const <PrayerKind, int>{},
    remindersEnabled: false,
    reminderModes: const <PrayerKind, PrayerReminderMode>{},
  );

  factory PrayerSettings.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final locationName = json['location_name'];
    final timezone = json['timezone'];
    if (locationName is! String ||
        locationName.trim().isEmpty ||
        timezone is! String ||
        timezone.trim().isEmpty ||
        latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('INVALID_PRAYER_SETTINGS');
    }
    final rawOffsets = json['offsets'];
    final offsets = <PrayerKind, int>{};
    if (rawOffsets is Map<String, dynamic>) {
      for (final prayer in PrayerKind.values) {
        final value = rawOffsets[prayer.name];
        if (value is num && value.isFinite) {
          offsets[prayer] = value.toInt().clamp(-60, 60).toInt();
        }
      }
    }
    final rawModes = json['reminder_modes'];
    final modes = <PrayerKind, PrayerReminderMode>{};
    if (rawModes is Map<String, dynamic>) {
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        final rawMode = rawModes[prayer.name];
        modes[prayer] = PrayerReminderMode.values.firstWhere(
          (value) => value.name == rawMode,
          orElse: () => PrayerReminderMode.disabled,
        );
      }
    }
    final legacyEnabled = json['reminders_enabled'] == true;
    if (modes.isEmpty && legacyEnabled) {
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      )) {
        modes[prayer] = PrayerReminderMode.notificationOnly;
      }
    }
    Map<PrayerKind, int> minuteMap(String key, int maximum) {
      final raw = json[key];
      return Map<PrayerKind, int>.unmodifiable({
        if (raw is Map)
          for (final prayer in PrayerKind.values)
            if (raw[prayer.name] is num && (raw[prayer.name] as num).isFinite)
              prayer: (raw[prayer.name] as num)
                  .toInt()
                  .clamp(0, maximum)
                  .toInt(),
      });
    }

    return PrayerSettings(
      beforeMinutes: minuteMap('before_minutes', 120),
      afterMinutes: minuteMap('after_minutes', 120),
      audioPaths: Map<PrayerKind, String>.unmodifiable({
        if (json['audio_paths'] is Map)
          for (final prayer in PrayerKind.values)
            if ((json['audio_paths'] as Map)[prayer.name] is String &&
                ((json['audio_paths'] as Map)[prayer.name] as String)
                    .trim()
                    .isNotEmpty)
              prayer: (json['audio_paths'] as Map)[prayer.name] as String,
      }),
      volumes: Map<PrayerKind, double>.unmodifiable({
        if (json['volumes'] is Map)
          for (final prayer in PrayerKind.values)
            if ((json['volumes'] as Map)[prayer.name] is num &&
                ((json['volumes'] as Map)[prayer.name] as num).isFinite)
              prayer: ((json['volumes'] as Map)[prayer.name] as num)
                  .toDouble()
                  .clamp(0, 1)
                  .toDouble(),
      }),
      locationName: locationName.trim(),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      timezone: timezone,
      calculationMethod: PrayerCalculationMethod.values.firstWhere(
        (value) => value.name == json['calculation_method'],
        orElse: () => PrayerCalculationMethod.muslimWorldLeague,
      ),
      asrMethod: PrayerAsrMethod.values.firstWhere(
        (value) => value.name == json['asr_method'],
        orElse: () => PrayerAsrMethod.shafi,
      ),
      offsets: Map<PrayerKind, int>.unmodifiable(offsets),
      remindersEnabled: modes.values.any(
        (value) => value != PrayerReminderMode.disabled,
      ),
      reminderModes: Map<PrayerKind, PrayerReminderMode>.unmodifiable(modes),
      manualTimes: Map<PrayerKind, int>.unmodifiable({
        for (final prayer in PrayerKind.values)
          if (json['manual_times'] is Map &&
              (json['manual_times'] as Map)[prayer.name] is int &&
              ((json['manual_times'] as Map)[prayer.name] as int) >= 0 &&
              ((json['manual_times'] as Map)[prayer.name] as int) < 1440)
            prayer: (json['manual_times'] as Map)[prayer.name] as int,
      }),
    );
  }

  final String locationName;
  final double latitude;
  final double longitude;
  final String timezone;
  final PrayerCalculationMethod calculationMethod;
  final PrayerAsrMethod asrMethod;
  final Map<PrayerKind, int> offsets;
  final bool remindersEnabled;
  final Map<PrayerKind, PrayerReminderMode> reminderModes;

  /// Minutes after midnight in the configured timezone; absent = calculated.
  final Map<PrayerKind, int> manualTimes;

  final Map<PrayerKind, int> beforeMinutes;
  final Map<PrayerKind, int> afterMinutes;
  final Map<PrayerKind, String> audioPaths;
  final Map<PrayerKind, double> volumes;

  int beforeMinutesFor(PrayerKind prayer) => beforeMinutes[prayer] ?? 0;
  int afterMinutesFor(PrayerKind prayer) => afterMinutes[prayer] ?? 0;
  String? audioPathFor(PrayerKind prayer, {String? fallback}) =>
      audioPaths[prayer] ?? fallback;
  double volumeFor(PrayerKind prayer) => volumes[prayer] ?? 1;

  /// Guidance only: the local mosque's published timetable remains authoritative.
  String? get calculationWarning {
    if (latitude.abs() >= 48)
      return 'في خطوط العرض المرتفعة قد تحتاج أوقات الفجر والعشاء إلى مراجعة تقويم مسجدك المحلي، خصوصًا صيفًا.';
    if (calculationMethod == PrayerCalculationMethod.ummAlQura &&
        (latitude < 16 || latitude > 33 || longitude < 34 || longitude > 56)) {
      return 'طريقة أم القرى مخصصة أساسًا للسعودية. راجع ملاءمتها لموقعك أو اختر طريقة محلية مناسبة.';
    }
    if (calculationMethod == PrayerCalculationMethod.northAmerica &&
        longitude > -30) {
      return 'طريقة أمريكا الشمالية قد تختلف عن التقويم المعتمد في منطقتك. قارن المواقيت بتقويم مسجدك.';
    }
    return null;
  }

  int offsetFor(PrayerKind prayer) => offsets[prayer] ?? 0;

  PrayerReminderMode reminderModeFor(PrayerKind prayer) {
    if (!prayer.isRequiredPrayer) return PrayerReminderMode.disabled;
    if (reminderModes.isNotEmpty) {
      return reminderModes[prayer] ?? PrayerReminderMode.disabled;
    }
    return remindersEnabled
        ? PrayerReminderMode.notificationOnly
        : PrayerReminderMode.disabled;
  }

  PrayerSettings copyWith({
    String? locationName,
    double? latitude,
    double? longitude,
    String? timezone,
    PrayerCalculationMethod? calculationMethod,
    PrayerAsrMethod? asrMethod,
    Map<PrayerKind, int>? offsets,
    bool? remindersEnabled,
    Map<PrayerKind, PrayerReminderMode>? reminderModes,
    Map<PrayerKind, int>? manualTimes,
    Map<PrayerKind, int>? beforeMinutes,
    Map<PrayerKind, int>? afterMinutes,
    Map<PrayerKind, String>? audioPaths,
    Map<PrayerKind, double>? volumes,
  }) => PrayerSettings(
    beforeMinutes: Map.unmodifiable(beforeMinutes ?? this.beforeMinutes),
    afterMinutes: Map.unmodifiable(afterMinutes ?? this.afterMinutes),
    audioPaths: Map.unmodifiable(audioPaths ?? this.audioPaths),
    volumes: Map.unmodifiable(volumes ?? this.volumes),
    locationName: locationName ?? this.locationName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    timezone: timezone ?? this.timezone,
    calculationMethod: calculationMethod ?? this.calculationMethod,
    asrMethod: asrMethod ?? this.asrMethod,
    offsets: Map<PrayerKind, int>.unmodifiable(offsets ?? this.offsets),
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    reminderModes: Map<PrayerKind, PrayerReminderMode>.unmodifiable(
      reminderModes ?? this.reminderModes,
    ),
    manualTimes: Map<PrayerKind, int>.unmodifiable(
      manualTimes ?? this.manualTimes,
    ),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'before_minutes': {
      for (final entry in beforeMinutes.entries) entry.key.name: entry.value,
    },
    'after_minutes': {
      for (final entry in afterMinutes.entries) entry.key.name: entry.value,
    },
    'audio_paths': {
      for (final entry in audioPaths.entries) entry.key.name: entry.value,
    },
    'volumes': {
      for (final entry in volumes.entries) entry.key.name: entry.value,
    },
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'calculation_method': calculationMethod.name,
    'asr_method': asrMethod.name,
    'manual_times': {
      for (final entry in manualTimes.entries) entry.key.name: entry.value,
    },
    'offsets': <String, int>{
      for (final prayer in PrayerKind.values) prayer.name: offsetFor(prayer),
    },
    'reminders_enabled': remindersEnabled,
    'reminder_modes': <String, String>{
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      ))
        prayer.name: reminderModeFor(prayer).name,
    },
  };
}

class PrayerSettingsStore extends ChangeNotifier {
  PrayerSettingsStore(this._preferences);
  void reload() {
    load();
    notifyListeners();
  }

  static const _storageKey = 'settings:prayer:v1';
  final SharedPreferences _preferences;
  PrayerSettings value = PrayerSettings.taiz();

  void load() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        value = PrayerSettings.fromJson(decoded);
      }
    } catch (_) {
      value = PrayerSettings.taiz();
    }
  }

  Future<void> setRemindersEnabled(bool enabled) {
    final modes = <PrayerKind, PrayerReminderMode>{
      for (final prayer in PrayerKind.values.where(
        (value) => value.isRequiredPrayer,
      ))
        prayer: enabled
            ? PrayerReminderMode.notificationOnly
            : PrayerReminderMode.disabled,
    };
    return _save(
      value.copyWith(remindersEnabled: enabled, reminderModes: modes),
    );
  }

  Future<void> setReminderMode(
    PrayerKind prayer,
    PrayerReminderMode mode,
  ) async {
    if (!prayer.isRequiredPrayer) return;
    final modes = Map<PrayerKind, PrayerReminderMode>.from(value.reminderModes);
    modes[prayer] = mode;
    await _save(
      value.copyWith(
        remindersEnabled: modes.values.any(
          (value) => value != PrayerReminderMode.disabled,
        ),
        reminderModes: modes,
      ),
    );
  }

  Future<void> setOffset(PrayerKind prayer, int minutes) async {
    final offsets = Map<PrayerKind, int>.from(value.offsets);
    offsets[prayer] = minutes.clamp(-60, 60).toInt();
    await _save(value.copyWith(offsets: offsets));
  }

  Future<void> updateLocation(PrayerSettings settings) => _save(settings);

  Future<void> setReminderMinutes(
    PrayerKind prayer, {
    int? before,
    int? after,
  }) async {
    final beforeMap = Map<PrayerKind, int>.from(value.beforeMinutes);
    final afterMap = Map<PrayerKind, int>.from(value.afterMinutes);
    if (before != null) beforeMap[prayer] = before.clamp(0, 120).toInt();
    if (after != null) afterMap[prayer] = after.clamp(0, 120).toInt();
    await _save(
      value.copyWith(beforeMinutes: beforeMap, afterMinutes: afterMap),
    );
  }

  Future<void> setPrayerAudio(PrayerKind prayer, String? path) async {
    final paths = Map<PrayerKind, String>.from(value.audioPaths);
    if (path == null || path.trim().isEmpty) {
      paths.remove(prayer);
    } else {
      paths[prayer] = path;
    }
    await _save(value.copyWith(audioPaths: paths));
  }

  Future<void> setPrayerVolume(PrayerKind prayer, double volume) async {
    if (!volume.isFinite) throw ArgumentError.value(volume, 'volume');
    await _save(
      value.copyWith(
        volumes: {...value.volumes, prayer: volume.clamp(0, 1).toDouble()},
      ),
    );
  }

  Future<void> setManualTime(PrayerKind prayer, int? minutes) async {
    if (minutes != null && (minutes < 0 || minutes >= 1440)) {
      throw ArgumentError.value(minutes, 'minutes');
    }
    final times = Map<PrayerKind, int>.from(value.manualTimes);
    if (minutes == null) {
      times.remove(prayer);
    } else {
      times[prayer] = minutes;
    }
    await _save(value.copyWith(manualTimes: times));
  }

  Future<void> _save(PrayerSettings next) async {
    value = next;
    await _preferences.setString(_storageKey, jsonEncode(next.toJson()));
    notifyListeners();
  }
}
