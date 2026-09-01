import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

const islamicLibraryRepositoryUrl =
    'https://github.com/mohammed-2-5/islamic-library-data';
const islamicLibraryRevision = '4beafb9f6c9e05e7a1f1573b856dbc511859f716';
const islamicLibraryCdn =
    'https://cdn.jsdelivr.net/gh/mohammed-2-5/'
    'islamic-library-data@$islamicLibraryRevision/';

class IslamicContentAsset {
  const IslamicContentAsset({
    required this.path,
    this.sha256,
    this.expectedSize,
    this.group,
    this.rightsStatus = 'PER_ITEM',
  });

  final String path;
  final String? sha256;
  final int? expectedSize;
  final String? group;
  final String rightsStatus;

  factory IslamicContentAsset.fromJson(Map<String, dynamic> json) =>
      IslamicContentAsset(
        path: json['path'] as String,
        sha256: json['sha256'] as String?,
        expectedSize: (json['size'] as num?)?.toInt(),
        group: json['group'] as String?,
        rightsStatus: json['rights'] as String? ?? 'PER_ITEM',
      );
}

class IslamicThemeSegment {
  const IslamicThemeSegment({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.titleAr,
    required this.descriptionAr,
    required this.category,
    required this.colorValue,
  });

  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final String titleAr;
  final String descriptionAr;
  final String category;
  final int colorValue;

  bool contains(int surah, int ayah) =>
      surah == surahNumber && ayah >= fromAyah && ayah <= toAyah;
}

class IslamicAyahContent {
  const IslamicAyahContent({
    required this.surahNumber,
    required this.ayahNumber,
    this.arabic,
    this.english,
    this.tafseer,
    this.tajweedMarkup,
    this.theme,
  });

  final int surahNumber;
  final int ayahNumber;
  final String? arabic;
  final String? english;
  final String? tafseer;
  final String? tajweedMarkup;
  final IslamicThemeSegment? theme;
}

class IslamicContentProgress {
  const IslamicContentProgress({
    required this.group,
    required this.completed,
    required this.total,
    required this.receivedBytes,
    this.currentPath,
    this.error,
  });

  final String group;
  final int completed;
  final int total;
  final int receivedBytes;
  final String? currentPath;
  final Object? error;

  double get fraction => total == 0 ? 0 : completed / total;
}

/// Unified local-first content gateway for Islamic Library Data.
///
/// JSON bytes are fetched directly from the pinned provider CDN, verified,
/// written atomically to device storage, then indexed in SQLite. Supabase is
/// intentionally not used as a proxy or re-host for these files.
class IslamicContentRepository extends ChangeNotifier {
  IslamicContentRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;
  final Map<String, dynamic> _memory = <String, dynamic>{};
  final Map<String, IslamicContentAsset> _manifest =
      <String, IslamicContentAsset>{};
  Database? _database;
  Directory? _root;
  List<IslamicThemeSegment>? _themes;
  bool _cancelRequested = false;
  IslamicContentProgress? progress;

  Iterable<IslamicContentAsset> get manifestAssets => _manifest.values;

  Future<void> initialize() async {
    if (_database != null) return;
    final manifestText = await rootBundle.loadString(
      'assets/islamic_content_manifest.json',
    );
    final manifestJson = jsonDecode(manifestText) as Map<String, dynamic>;
    for (final value in manifestJson['assets'] as List<dynamic>) {
      final asset = IslamicContentAsset.fromJson(
        Map<String, dynamic>.from(value as Map),
      );
      _manifest[asset.path] = asset;
    }
    final support = await getApplicationSupportDirectory();
    _root = Directory(
      p.join(support.path, 'islamic-content', islamicLibraryRevision),
    );
    await _root!.create(recursive: true);
    _database = await openDatabase(
      p.join(support.path, 'islamic-content-index.sqlite3'),
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE content_assets (
            path TEXT NOT NULL,
            revision TEXT NOT NULL,
            sha256 TEXT NOT NULL,
            byte_size INTEGER NOT NULL,
            rights_status TEXT NOT NULL,
            verified_at TEXT NOT NULL,
            PRIMARY KEY(path, revision)
          )
        ''');
      },
    );
  }

  Future<dynamic> readJson(
    String path, {
    bool refresh = false,
    String rightsStatus = 'PER_ITEM',
  }) async {
    _validatePath(path);
    await initialize();
    if (!refresh && _memory.containsKey(path)) return _memory[path];
    final asset =
        _manifest[path] ??
        IslamicContentAsset(path: path, rightsStatus: rightsStatus);
    var file = _file(path);
    if (!refresh && await _isVerified(file, asset)) {
      final decoded = jsonDecode(await file.readAsString());
      _memory[path] = decoded;
      return decoded;
    }

    final uri = Uri.parse('$islamicLibraryCdn$path');
    final response = await _client.get(uri);
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw HttpException(
        'Islamic content HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    // Parse before committing so an HTML/error body never enters the cache.
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final actualSha = sha256.convert(response.bodyBytes).toString();
    if (asset.sha256 != null && actualSha != asset.sha256) {
      throw const FormatException('Islamic content SHA-256 mismatch');
    }
    if (asset.expectedSize != null &&
        response.bodyBytes.length != asset.expectedSize) {
      throw const FormatException('Islamic content byte-size mismatch');
    }
    await file.parent.create(recursive: true);
    final partial = File('${file.path}.partial');
    await partial.writeAsBytes(response.bodyBytes, flush: true);
    if (await file.exists()) await file.delete();
    file = await partial.rename(file.path);
    await _database!.insert('content_assets', <String, Object>{
      'path': path,
      'revision': islamicLibraryRevision,
      'sha256': actualSha,
      'byte_size': await file.length(),
      'rights_status': asset.rightsStatus,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _memory[path] = decoded;
    return decoded;
  }

  Future<Map<String, dynamic>> surah(
    int surah, {
    String language = 'ar',
  }) async {
    _validateSurah(surah);
    final value = await readJson('quran/chapters/$language/$surah.json');
    return Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> tajweed(int surah) async {
    _validateSurah(surah);
    final value = await readJson('quran/tajweed/$surah.json');
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<IslamicThemeSegment>> themes() async {
    if (_themes != null) return _themes!;
    _themes = parseIslamicThemeSegments(
      await readJson('quran/quran_segments.json'),
    );
    return _themes!;
  }

  Future<IslamicThemeSegment?> themeForAyah(int surah, int ayah) async {
    final values = await themes();
    return values.where((value) => value.contains(surah, ayah)).firstOrNull;
  }

  Future<Map<String, IslamicThemeSegment>> themesForVerseKeys(
    Iterable<String> verseKeys,
  ) async {
    final values = await themes();
    final result = <String, IslamicThemeSegment>{};
    for (final key in verseKeys) {
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;
      final match = values
          .where((value) => value.contains(surah, ayah))
          .firstOrNull;
      if (match != null) result[key] = match;
    }
    return result;
  }

  Future<IslamicAyahContent> ayahContent(int surah, int ayah) async {
    _validateSurah(surah);
    final values = await Future.wait<dynamic>(<Future<dynamic>>[
      this.surah(surah),
      this.surah(surah, language: 'en'),
      readJson('tafseer/muyassar.json'),
      tajweed(surah),
      themeForAyah(surah, ayah),
    ]);
    String? verseText(dynamic source) {
      final verses = (source as Map)['verses'] as List<dynamic>? ?? const [];
      final item = verses
          .where((value) => ((value as Map)['id'] as num?)?.toInt() == ayah)
          .firstOrNull;
      return item == null ? null : (item as Map)['text'] as String?;
    }

    final tafseer = (values[2] as List<dynamic>).where((value) {
      final item = value as Map;
      return int.tryParse('${item['number']}') == surah &&
          int.tryParse('${item['aya']}') == ayah;
    }).firstOrNull;
    final tajweedVerses =
        (values[3] as Map)['verses'] as List<dynamic>? ?? const <dynamic>[];
    final tajweedVerse = tajweedVerses
        .where((value) => ((value as Map)['id'] as num?)?.toInt() == ayah)
        .firstOrNull;
    return IslamicAyahContent(
      surahNumber: surah,
      ayahNumber: ayah,
      arabic: verseText(values[0]),
      english: verseText(values[1]),
      tafseer: tafseer == null ? null : (tafseer as Map)['text'] as String?,
      tajweedMarkup: tajweedVerse == null
          ? null
          : (tajweedVerse as Map)['text'] as String?,
      theme: values[4] as IslamicThemeSegment?,
    );
  }

  Future<void> synchronizeInBackground() async {
    // Pinned-version synchronization is deterministic: it warms the small
    // index/theme files and never blocks startup or replaces verified data.
    try {
      await Future.wait<dynamic>(<Future<dynamic>>[
        readJson('quran/quran_segments.json'),
        readJson('quran/hizb_quarters.json'),
        readJson('quran/qcf_surah_starts.json'),
        readJson('data/catalog.json'),
      ]);
    } catch (error) {
      debugPrint('Islamic content background sync deferred: $error');
    }
  }

  Future<void> downloadOfflineGroup(String group) async {
    await initialize();
    _cancelRequested = false;
    final paths = await _pathsForGroup(group);
    var bytes = 0;
    progress = IslamicContentProgress(
      group: group,
      completed: 0,
      total: paths.length,
      receivedBytes: 0,
    );
    notifyListeners();
    try {
      for (var index = 0; index < paths.length; index++) {
        if (_cancelRequested) return;
        final path = paths[index];
        await readJson(path);
        bytes += await _file(path).length();
        progress = IslamicContentProgress(
          group: group,
          completed: index + 1,
          total: paths.length,
          receivedBytes: bytes,
          currentPath: path,
        );
        notifyListeners();
      }
    } catch (error) {
      progress = IslamicContentProgress(
        group: group,
        completed: progress?.completed ?? 0,
        total: paths.length,
        receivedBytes: bytes,
        currentPath: progress?.currentPath,
        error: error,
      );
      notifyListeners();
      rethrow;
    }
  }

  void pauseOfflineDownload() {
    _cancelRequested = true;
  }

  Future<void> deleteOfflineGroup(String group) async {
    for (final path in await _pathsForGroup(group)) {
      final file = _file(path);
      if (await file.exists()) await file.delete();
      _memory.remove(path);
      await _database?.delete(
        'content_assets',
        where: 'path = ? AND revision = ?',
        whereArgs: <Object>[path, islamicLibraryRevision],
      );
    }
    progress = null;
    notifyListeners();
  }

  Future<List<String>> _pathsForGroup(String group) async {
    final paths = _manifest.values
        .where((asset) => asset.group == group)
        .map((asset) => asset.path)
        .toSet();
    if (group == 'quran') {
      for (var surah = 1; surah <= 114; surah++) {
        paths.add('quran/chapters/ar/$surah.json');
        paths.add('quran/chapters/en/$surah.json');
        paths.add('quran/tajweed/$surah.json');
      }
      paths.add('tafseer/muyassar.json');
    } else if (group == 'hadith') {
      for (final id in const <String>['bukhari', 'muslim', 'malik', 'ahmed']) {
        paths.add('hadith/$id.json');
      }
    } else if (group == 'stories') {
      final index =
          await readJson('prophet_stories/index.json') as List<dynamic>;
      for (final value in index) {
        final id = (value as Map)['id'];
        paths.add('prophet_stories/$id.json');
        paths.add('prophet_stories/quizzes/$id.json');
      }
    } else if (group == 'azkar') {
      paths.addAll(const <String>{
        'azkar/after_prayer.json',
        'azkar/morning_evening.json',
        'azkar/travel.json',
        'azkar/food.json',
        'azkar/sleep.json',
        'azkar/mosque.json',
        'azkar/home.json',
        'azkar/wudu.json',
      });
    }
    final result = paths.toList(growable: false)..sort();
    return result;
  }

  Future<bool> _isVerified(File file, IslamicContentAsset asset) async {
    if (!await file.exists()) return false;
    final rows = await _database!.query(
      'content_assets',
      columns: const <String>['sha256', 'byte_size'],
      where: 'path = ? AND revision = ?',
      whereArgs: <Object>[asset.path, islamicLibraryRevision],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final bytes = await file.readAsBytes();
    final actual = sha256.convert(bytes).toString();
    final indexed = rows.single['sha256'];
    return actual == indexed &&
        (asset.sha256 == null || actual == asset.sha256);
  }

  File _file(String path) =>
      File(p.joinAll(<String>[_root!.path, ...path.split('/')]));

  void _validatePath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('..') ||
        !path.endsWith('.json')) {
      throw ArgumentError.value(path, 'path', 'Unsafe content path');
    }
  }

  void _validateSurah(int surah) {
    if (surah < 1 || surah > 114) {
      throw RangeError.range(surah, 1, 114, 'surah');
    }
  }
}

List<IslamicThemeSegment> parseIslamicThemeSegments(dynamic decoded) {
  if (decoded is! Map) throw const FormatException('Invalid segment root');
  final result = <IslamicThemeSegment>[];
  for (final surahValue in decoded['surahs'] as List<dynamic>? ?? const []) {
    final surah = surahValue as Map;
    final surahNumber = (surah['surah_number'] as num?)?.toInt() ?? 0;
    for (final segmentValue
        in surah['segments'] as List<dynamic>? ?? const []) {
      final segment = segmentValue as Map;
      final rawColor = '${segment['color'] ?? '#E8F5E9'}'.replaceFirst('#', '');
      final rgb = int.tryParse(rawColor, radix: 16) ?? 0xE8F5E9;
      result.add(
        IslamicThemeSegment(
          surahNumber: surahNumber,
          fromAyah: (segment['start'] as num?)?.toInt() ?? 0,
          toAyah: (segment['end'] as num?)?.toInt() ?? 0,
          titleAr: segment['theme'] as String? ?? '',
          descriptionAr: segment['description'] as String? ?? '',
          category: segment['category'] as String? ?? '',
          colorValue: 0xff000000 | rgb,
        ),
      );
    }
  }
  if (result.isEmpty) throw const FormatException('No thematic segments');
  return List<IslamicThemeSegment>.unmodifiable(result);
}
