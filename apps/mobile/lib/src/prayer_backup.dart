import 'adhan_library.dart';
import 'prayer_settings.dart';

/// Portable preferences only. Coordinates, manual timetables and private paths
/// stay on this phone. No cloud row is ever an executable Android alarm.
class PrayerBackup {
  static Map<String, dynamic> encode(PrayerSettings value) => {
    'schema': 1,
    'calculation_method': value.calculationMethod.name,
    'asr_method': value.asrMethod.name,
    'offsets': {for (final e in value.offsets.entries) e.key.name: e.value},
    'reminder_modes': {
      for (final p in PrayerKind.values.where((p) => p.isRequiredPrayer))
        p.name: value.reminderModeFor(p).name,
    },
    'before_minutes': {
      for (final e in value.beforeMinutes.entries) e.key.name: e.value,
    },
    'after_minutes': {
      for (final e in value.afterMinutes.entries) e.key.name: e.value,
    },
    'volumes': {for (final e in value.volumes.entries) e.key.name: e.value},
    'audio_assets': {
      for (final e in value.audioPaths.entries)
        if (builtInAdhanSounds.any((s) => s.path == e.value))
          e.key.name: e.value,
    },
  };

  static PrayerSettings decode(dynamic raw, PrayerSettings local) {
    const fields = {
      'schema',
      'calculation_method',
      'asr_method',
      'offsets',
      'reminder_modes',
      'before_minutes',
      'after_minutes',
      'volumes',
      'audio_assets',
    };
    if (raw is! Map ||
        raw.keys.toSet().difference(fields).isNotEmpty ||
        fields.difference(raw.keys.toSet()).isNotEmpty ||
        raw['schema'] != 1 ||
        !PrayerCalculationMethod.values.any(
          (v) => v.name == raw['calculation_method'],
        ) ||
        !PrayerAsrMethod.values.any((v) => v.name == raw['asr_method'])) {
      throw const FormatException('INVALID_PRAYER_BACKUP');
    }
    for (final key in [
      'offsets',
      'reminder_modes',
      'before_minutes',
      'after_minutes',
      'volumes',
      'audio_assets',
    ]) {
      final map = raw[key];
      if (map is! Map) throw const FormatException('INVALID_PRAYER_BACKUP');
      for (final e in map.entries) {
        final value = e.value;
        final valid =
            PrayerKind.values.any((p) => p.name == e.key) &&
            switch (key) {
              'offsets' => value is int && value >= -60 && value <= 60,
              'before_minutes' ||
              'after_minutes' => value is int && value >= 0 && value <= 120,
              'volumes' =>
                value is num && value.isFinite && value >= 0 && value <= 1,
              'reminder_modes' =>
                e.key != 'sunrise' &&
                    PrayerReminderMode.values.any((m) => m.name == value),
              _ => builtInAdhanSounds.any((sound) => sound.path == value),
            };
        if (!valid) throw const FormatException('INVALID_PRAYER_BACKUP');
      }
    }
    return PrayerSettings.fromJson({
      ...local.toJson(),
      ...Map<String, dynamic>.from(raw),
      'audio_paths': {
        ...local.toJson()['audio_paths'] as Map,
        ...raw['audio_assets'] as Map,
      },
    });
  }
}
