import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'prayer_settings.dart';

/// Explicit, portable backup. Never exports cloud tokens, paths or audio files.
class LocalDataBackup {
  LocalDataBackup(this.preferences);
  final SharedPreferences preferences;
  static const favoriteKeys = [
    'favorites:stations',
    'favorites:reciters',
    'favorites:tracks',
  ];
  static const settingKeys = [
    'settings:theme',
    'settings:locale',
    'settings:speed',
  ];

  String export() {
    final prayer = preferences.getString('settings:prayer:v1');
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'tarteel-local-backup',
      'version': 1,
      'favorites': {
        for (final key in favoriteKeys)
          key: preferences.getStringList(key) ?? <String>[],
      },
      'settings': {
        for (final key in settingKeys)
          if (preferences.containsKey(key)) key: preferences.get(key),
      },
      if (prayer != null) 'prayer': _safePrayer(jsonDecode(prayer)),
    });
  }

  static Map<String, dynamic> _safePrayer(dynamic raw) {
    if (raw is! Map<String, dynamic>)
      throw const FormatException('INVALID_PRAYER');
    return PrayerSettings.fromJson(raw)
        .copyWith(
          audioPaths: {},
          remindersEnabled: false,
          reminderModes: {
            for (final kind in PrayerKind.values)
              kind: PrayerReminderMode.disabled,
          },
        )
        .toJson();
  }

  Future<int> restore(String text, {bool restoreSettings = false}) async {
    if (utf8.encode(text).length > 256 * 1024)
      throw const FormatException('BACKUP_TOO_LARGE');
    final root = jsonDecode(text);
    if (root is! Map ||
        root['format'] != 'tarteel-local-backup' ||
        root['version'] != 1 ||
        root['favorites'] is! Map ||
        root['settings'] is! Map) {
      throw const FormatException('INVALID_BACKUP');
    }
    final favorites = <String, List<String>>{};
    for (final key in favoriteKeys) {
      final rows = root['favorites'][key];
      if (rows is! List ||
          rows.length > 5000 ||
          rows.any(
            (v) =>
                v is! String ||
                v.isEmpty ||
                v.length > 200 ||
                RegExp(r'[\x00-\x1f]').hasMatch(v),
          )) {
        throw const FormatException('INVALID_FAVORITES');
      }
      favorites[key] = rows.cast<String>();
    }
    final settings = Map<String, dynamic>.from(root['settings'] as Map);
    if (settings.keys.any((key) => !settingKeys.contains(key)) ||
        (settings.containsKey('settings:theme') &&
            ![
              'system',
              'light',
              'dark',
            ].contains(settings['settings:theme'])) ||
        (settings.containsKey('settings:locale') &&
            !['ar', 'en'].contains(settings['settings:locale'])) ||
        (settings.containsKey('settings:speed') &&
            (settings['settings:speed'] is! num ||
                !(settings['settings:speed'] as num).isFinite ||
                (settings['settings:speed'] as num) < .75 ||
                (settings['settings:speed'] as num) > 2))) {
      throw const FormatException('INVALID_SETTINGS');
    }
    final prayer = root['prayer'] == null ? null : _safePrayer(root['prayer']);
    // All validation finishes before the first write. Favorites are merged.
    var added = 0;
    for (final key in favoriteKeys) {
      final values = (preferences.getStringList(key) ?? <String>[]).toSet();
      final before = values.length;
      values.addAll(favorites[key]!);
      added += values.length - before;
      if (!await preferences.setStringList(key, values.toList()))
        throw StateError('BACKUP_WRITE_FAILED');
    }
    if (restoreSettings) {
      for (final entry in settings.entries) {
        final ok = entry.value is num
            ? await preferences.setDouble(
                entry.key,
                (entry.value as num).toDouble(),
              )
            : await preferences.setString(entry.key, entry.value as String);
        if (!ok) throw StateError('BACKUP_WRITE_FAILED');
      }
      if (prayer != null &&
          !await preferences.setString(
            'settings:prayer:v1',
            jsonEncode(prayer),
          )) {
        throw StateError('BACKUP_WRITE_FAILED');
      }
    }
    return added;
  }
}
