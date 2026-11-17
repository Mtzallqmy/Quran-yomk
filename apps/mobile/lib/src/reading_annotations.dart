import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ReadingAnnotation {
  const ReadingAnnotation({required this.title, required this.note});
  final String title;
  final String note;

  Map<String, String> toJson() => {'title': title, 'note': note};
}

/// Keys are canonical Hafs ayah identities. The Quran text and visual page
/// numbers are resolved from the verified corpus when reading an annotation.
class ReadingAnnotations extends ChangeNotifier {
  ReadingAnnotations(this._preferences) {
    try {
      final raw = _preferences.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final row = entry.value;
        if (!_ayahKey.hasMatch(entry.key) || row is! Map<String, dynamic>) {
          continue;
        }
        final title = row['title'];
        final note = row['note'];
        if (title is String && note is String) {
          _records[entry.key] = ReadingAnnotation(title: title, note: note);
        }
      }
    } on FormatException {
      // Invalid local JSON does not block access to the canonical reader.
    } on TypeError {
      // Prior keys may come from older or damaged local backups.
    }
  }

  static const _key = 'mushaf:ayah-annotations:v1';
  static final _ayahKey = RegExp(r'^hafs:[1-9][0-9]{0,2}:[1-9][0-9]{0,2}$');
  final SharedPreferences _preferences;
  final _records = <String, ReadingAnnotation>{};
  bool _saving = false;

  Map<String, ReadingAnnotation> get records => Map.unmodifiable(_records);
  ReadingAnnotation? operator [](String ayah) => _records[ayah];

  Future<bool> save(String ayah, ReadingAnnotation? value) async {
    if (!_ayahKey.hasMatch(ayah)) throw ArgumentError.value(ayah, 'ayah');
    if (_saving) return false;
    final next = Map<String, ReadingAnnotation>.of(_records);
    if (value == null || (value.title.isEmpty && value.note.isEmpty)) {
      next.remove(ayah);
    } else {
      next[ayah] = value;
    }
    _saving = true;
    try {
      final saved = await _preferences.setString(
        _key,
        jsonEncode(next.map((key, value) => MapEntry(key, value.toJson()))),
      );
      if (!saved) return false;
      _records
        ..clear()
        ..addAll(next);
      notifyListeners();
      return true;
    } on Exception {
      return false;
    } finally {
      _saving = false;
    }
  }
}
