import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrayerKind { fajr, sunrise, dhuhr, asr, maghrib, isha }

enum PrayerCalculationMethod { muslimWorldLeague, egyptian, ummAlQura }

enum PrayerAsrMethod { shafi, hanafi }

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
      remindersEnabled: json['reminders_enabled'] == true,
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

  int offsetFor(PrayerKind prayer) => offsets[prayer] ?? 0;

  PrayerSettings copyWith({
    String? locationName,
    double? latitude,
    double? longitude,
    String? timezone,
    PrayerCalculationMethod? calculationMethod,
    PrayerAsrMethod? asrMethod,
    Map<PrayerKind, int>? offsets,
    bool? remindersEnabled,
  }) => PrayerSettings(
    locationName: locationName ?? this.locationName,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    timezone: timezone ?? this.timezone,
    calculationMethod: calculationMethod ?? this.calculationMethod,
    asrMethod: asrMethod ?? this.asrMethod,
    offsets: Map<PrayerKind, int>.unmodifiable(offsets ?? this.offsets),
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
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

  Future<void> setRemindersEnabled(bool enabled) =>
      _save(value.copyWith(remindersEnabled: enabled));

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
