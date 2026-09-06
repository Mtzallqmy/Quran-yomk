import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

enum PrayerCalculationMethod { muslimWorldLeague, egyptian, ummAlQura }

enum PrayerAsrMethod { shafi, hanafi }

enum PrayerReminderMode { disabled, notificationOnly, adhan }

extension PrayerReminderModeLabel on PrayerReminderMode {
  String get nameAr => switch (this) {
    PrayerReminderMode.disabled => 'متوقف',
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
    return PrayerSettings(
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
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'calculation_method': calculationMethod.name,
    'asr_method': asrMethod.name,
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

  Future<void> _save(PrayerSettings next) async {
    value = next;
    await _preferences.setString(_storageKey, jsonEncode(next.toJson()));
    notifyListeners();
  }
}
