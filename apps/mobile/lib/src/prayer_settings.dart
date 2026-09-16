import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

enum PrayerCalculationMethod {
  muslimWorldLeague,
  egyptian,
  karachi,
  ummAlQura,
  dubai,
  qatar,
  kuwait,
  moonSightingCommittee,
  singapore,
  northAmerica,
  turkey,
}

enum PrayerAsrMethod { shafi, hanafi }

enum PrayerReminderMode { disabled, silent, notificationOnly, adhan }

extension PrayerReminderModeLabel on PrayerReminderMode {
  String get nameAr => switch (this) {
    PrayerReminderMode.disabled => 'متوقف',
    PrayerReminderMode.silent => 'إشعار صامت',
    PrayerReminderMode.notificationOnly => 'إشعار فقط',
    PrayerReminderMode.adhan => 'إشعار وأذان',
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
    this.adhanAudioSlug,
    this.adhanAudioSha256,
    this.adhanAudioPath,
    this.iqamahEnabled = false,
    this.iqamahOffsetMinutes = 10,
    this.iqamahAudioSlug,
    this.iqamahAudioSha256,
    this.iqamahAudioPath,
  });

  factory PrayerSettings.taiz() => const PrayerSettings(
    locationName: 'تعز',
    latitude: 13.5795,
    longitude: 44.0209,
    timezone: 'Asia/Aden',
    calculationMethod: PrayerCalculationMethod.muslimWorldLeague,
    asrMethod: PrayerAsrMethod.shafi,
    offsets: <PrayerKind, int>{},
    remindersEnabled: false,
    reminderModes: <PrayerKind, PrayerReminderMode>{},
  );

  factory PrayerSettings.makkah() => const PrayerSettings(
    locationName: 'مكة المكرمة',
    latitude: 21.4225,
    longitude: 39.8262,
    timezone: 'Asia/Riyadh',
    calculationMethod: PrayerCalculationMethod.ummAlQura,
    asrMethod: PrayerAsrMethod.shafi,
    offsets: <PrayerKind, int>{},
    remindersEnabled: false,
    reminderModes: <PrayerKind, PrayerReminderMode>{},
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
        if (value is num) {
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
    final rawMethod = json['calculation_method'];
    final recommended = timezone == 'Asia/Riyadh'
        ? PrayerCalculationMethod.ummAlQura
        : PrayerCalculationMethod.muslimWorldLeague;
    final iqamahOffset = (json['iqamah_offset_minutes'] as num?)?.toInt() ?? 10;
    return PrayerSettings(
      locationName: locationName.trim(),
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      timezone: timezone,
      calculationMethod: PrayerCalculationMethod.values.firstWhere(
        (value) => value.name == rawMethod,
        orElse: () => recommended,
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
      adhanAudioSlug: _nullableString(json['adhan_audio_slug']),
      adhanAudioSha256: _nullableDigest(json['adhan_audio_sha256']),
      adhanAudioPath: _nullableString(json['adhan_audio_path']),
      iqamahEnabled: json['iqamah_enabled'] == true,
      iqamahOffsetMinutes: iqamahOffset.clamp(1, 120).toInt(),
      iqamahAudioSlug: _nullableString(json['iqamah_audio_slug']),
      iqamahAudioSha256: _nullableDigest(json['iqamah_audio_sha256']),
      iqamahAudioPath: _nullableString(json['iqamah_audio_path']),
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

  /// Verified offline file selected from the licensed Islamic library.
  final String? adhanAudioSlug;
  final String? adhanAudioSha256;
  final String? adhanAudioPath;

  /// Optional iqamah playback after each enabled prayer alarm on Android.
  final bool iqamahEnabled;
  final int iqamahOffsetMinutes;
  final String? iqamahAudioSlug;
  final String? iqamahAudioSha256;
  final String? iqamahAudioPath;

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
    String? adhanAudioSlug,
    String? adhanAudioSha256,
    String? adhanAudioPath,
    bool clearAdhanAudio = false,
    bool? iqamahEnabled,
    int? iqamahOffsetMinutes,
    String? iqamahAudioSlug,
    String? iqamahAudioSha256,
    String? iqamahAudioPath,
    bool clearIqamahAudio = false,
  }) => PrayerSettings(
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
    adhanAudioSlug: clearAdhanAudio
        ? null
        : adhanAudioSlug ?? this.adhanAudioSlug,
    adhanAudioSha256: clearAdhanAudio
        ? null
        : adhanAudioSha256 ?? this.adhanAudioSha256,
    adhanAudioPath: clearAdhanAudio
        ? null
        : adhanAudioPath ?? this.adhanAudioPath,
    iqamahEnabled: iqamahEnabled ?? this.iqamahEnabled,
    iqamahOffsetMinutes: (iqamahOffsetMinutes ?? this.iqamahOffsetMinutes)
        .clamp(1, 120)
        .toInt(),
    iqamahAudioSlug: clearIqamahAudio
        ? null
        : iqamahAudioSlug ?? this.iqamahAudioSlug,
    iqamahAudioSha256: clearIqamahAudio
        ? null
        : iqamahAudioSha256 ?? this.iqamahAudioSha256,
    iqamahAudioPath: clearIqamahAudio
        ? null
        : iqamahAudioPath ?? this.iqamahAudioPath,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
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
    'adhan_audio_slug': adhanAudioSlug,
    'adhan_audio_sha256': adhanAudioSha256,
    'adhan_audio_path': adhanAudioPath,
    'iqamah_enabled': iqamahEnabled,
    'iqamah_offset_minutes': iqamahOffsetMinutes,
    'iqamah_audio_slug': iqamahAudioSlug,
    'iqamah_audio_sha256': iqamahAudioSha256,
    'iqamah_audio_path': iqamahAudioPath,
  };
}

class PrayerSettingsStore extends ChangeNotifier {
  PrayerSettingsStore(this._preferences);

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

  Future<void> setAdhanAudio({
    required String slug,
    required String sha256,
    required String path,
  }) => _save(
    value.copyWith(
      adhanAudioSlug: slug,
      adhanAudioSha256: sha256,
      adhanAudioPath: path,
    ),
  );

  Future<void> clearAdhanAudio() => _save(value.copyWith(clearAdhanAudio: true));

  Future<void> setIqamahAudio({
    required String slug,
    required String sha256,
    required String path,
  }) => _save(
    value.copyWith(
      iqamahAudioSlug: slug,
      iqamahAudioSha256: sha256,
      iqamahAudioPath: path,
    ),
  );

  Future<void> setIqamahEnabled(bool enabled) =>
      _save(value.copyWith(iqamahEnabled: enabled));

  Future<void> setIqamahOffset(int minutes) => _save(
    value.copyWith(iqamahOffsetMinutes: minutes.clamp(1, 120).toInt()),
  );

  Future<void> clearIqamahAudio() => _save(
    value.copyWith(clearIqamahAudio: true, iqamahEnabled: false),
  );

  Future<void> _save(PrayerSettings next) async {
    value = next;
    await _preferences.setString(_storageKey, jsonEncode(next.toJson()));
    notifyListeners();
  }
}

String? _nullableString(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

String? _nullableDigest(Object? value) {
  final normalized = _nullableString(value);
  if (normalized == null || !RegExp(r'^[0-9a-f]{64}$').hasMatch(normalized)) {
    return null;
  }
  return normalized;
}
