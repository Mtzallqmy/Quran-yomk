import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_models.dart';

enum MushafReaderPresentation { page, text }

class MushafPosition {
  const MushafPosition({
    required this.mode,
    required this.number,
    this.verseKey,
    this.surahNumber,
    this.ayahNumber,
    this.pageNumber,
  });

  final QuranBrowseMode mode;
  final int number;
  final String? verseKey;
  final int? surahNumber;
  final int? ayahNumber;
  final int? pageNumber;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'mode': mode.name,
    'number': number,
    'verse_key': verseKey,
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
    'page_number': pageNumber,
  };

  factory MushafPosition.fromJson(Map<String, dynamic> json) => MushafPosition(
    mode: QuranBrowseMode.values.firstWhere(
      (value) => value.name == json['mode'],
      orElse: () => QuranBrowseMode.surah,
    ),
    number: (json['number'] as num?)?.toInt() ?? 1,
    verseKey: json['verse_key'] as String?,
    surahNumber: (json['surah_number'] as num?)?.toInt(),
    ayahNumber: (json['ayah_number'] as num?)?.toInt(),
    pageNumber: (json['page_number'] as num?)?.toInt(),
  );
}

class MushafBookmark {
  const MushafBookmark({
    required this.verseKey,
    required this.surahNumber,
    required this.ayahNumber,
    required this.pageNumber,
    required this.createdAt,
  });

  final String verseKey;
  final int surahNumber;
  final int ayahNumber;
  final int pageNumber;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'verse_key': verseKey,
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
    'page_number': pageNumber,
    'created_at': createdAt.toIso8601String(),
  };

  factory MushafBookmark.fromJson(Map<String, dynamic> json) => MushafBookmark(
    verseKey: json['verse_key'] as String? ?? '',
    surahNumber: (json['surah_number'] as num?)?.toInt() ?? 1,
    ayahNumber: (json['ayah_number'] as num?)?.toInt() ?? 1,
    pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
    createdAt:
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class MushafStore extends ChangeNotifier {
  MushafStore(this._prefs);

  static const _positionKey = 'mushaf:last-position:v1';
  static const _bookmarksKey = 'mushaf:bookmarks:v1';
  static const _fontScaleKey = 'mushaf:font-scale';
  static const _tajweedKey = 'mushaf:show-tajweed';
  static const _themesKey = 'mushaf:show-themes';
  static const _presentationKey = 'mushaf:presentation:v1';
  static const _pageEditionKey = 'mushaf:page-edition:v1';

  final SharedPreferences _prefs;
  final Map<String, MushafBookmark> _bookmarks = <String, MushafBookmark>{};

  MushafPosition? lastPosition;
  double fontScale = 1.0;
  bool showTajweed = true;
  bool showThemes = false;
  MushafReaderPresentation presentation = MushafReaderPresentation.page;
  String pageEdition = 'madinahHafsSvg';

  List<MushafBookmark> get bookmarks {
    final values = _bookmarks.values.toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return values;
  }

  void load() {
    final rawPosition = _prefs.getString(_positionKey);
    if (rawPosition != null) {
      try {
        final value = jsonDecode(rawPosition);
        if (value is Map) {
          lastPosition = MushafPosition.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      } catch (_) {}
    }

    final rawBookmarks = _prefs.getString(_bookmarksKey);
    if (rawBookmarks != null) {
      try {
        final values = jsonDecode(rawBookmarks);
        if (values is List) {
          for (final value in values) {
            if (value is! Map) continue;
            final bookmark = MushafBookmark.fromJson(
              Map<String, dynamic>.from(value),
            );
            if (bookmark.verseKey.isNotEmpty) {
              _bookmarks[bookmark.verseKey] = bookmark;
            }
          }
        }
      } catch (_) {}
    }

    fontScale = (_prefs.getDouble(_fontScaleKey) ?? 1.0).clamp(0.75, 1.8);
    showTajweed = _prefs.getBool(_tajweedKey) ?? true;
    showThemes = _prefs.getBool(_themesKey) ?? false;
    presentation = MushafReaderPresentation.values.firstWhere(
      (value) => value.name == _prefs.getString(_presentationKey),
      orElse: () => MushafReaderPresentation.page,
    );
    pageEdition = _prefs.getString(_pageEditionKey) ?? 'madinahHafsSvg';
  }

  bool isBookmarked(String verseKey) => _bookmarks.containsKey(verseKey);

  Future<void> setLastPosition(MushafPosition value) async {
    lastPosition = value;
    await _prefs.setString(_positionKey, jsonEncode(value.toJson()));
    notifyListeners();
  }

  Future<void> toggleBookmark(QuranVerse verse) async {
    if (_bookmarks.containsKey(verse.verseKey)) {
      _bookmarks.remove(verse.verseKey);
    } else {
      _bookmarks[verse.verseKey] = MushafBookmark(
        verseKey: verse.verseKey,
        surahNumber: verse.surahNumber,
        ayahNumber: verse.ayahNumber,
        pageNumber: verse.pageNumber,
        createdAt: DateTime.now(),
      );
    }
    await _persistBookmarks();
    notifyListeners();
  }

  Future<void> setFontScale(double value) async {
    fontScale = value.clamp(0.75, 1.8);
    await _prefs.setDouble(_fontScaleKey, fontScale);
    notifyListeners();
  }

  Future<void> setShowTajweed(bool value) async {
    showTajweed = value;
    await _prefs.setBool(_tajweedKey, value);
    notifyListeners();
  }

  Future<void> setShowThemes(bool value) async {
    showThemes = value;
    await _prefs.setBool(_themesKey, value);
    notifyListeners();
  }

  Future<void> setPresentation(MushafReaderPresentation value) async {
    presentation = value;
    await _prefs.setString(_presentationKey, value.name);
    notifyListeners();
  }

  Future<void> setPageEdition(String value) async {
    pageEdition = value;
    await _prefs.setString(_pageEditionKey, value);
    notifyListeners();
  }

  Future<void> _persistBookmarks() => _prefs.setString(
    _bookmarksKey,
    jsonEncode(_bookmarks.values.map((value) => value.toJson()).toList()),
  );
}
