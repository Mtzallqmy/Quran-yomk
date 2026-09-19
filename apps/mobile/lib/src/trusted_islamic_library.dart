import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

typedef JsonMap = Map<String, dynamic>;

@immutable
class TrustedIslamicCategory {
  const TrustedIslamicCategory({
    required this.slug,
    required this.nameAr,
    required this.sortOrder,
    required this.itemCount,
  });

  final String slug;
  final String nameAr;
  final int sortOrder;
  final int itemCount;

  factory TrustedIslamicCategory.fromJson(JsonMap json) =>
      TrustedIslamicCategory(
        slug: '${json['slug'] ?? ''}',
        nameAr: '${json['name_ar'] ?? ''}',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 999,
        itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class TrustedIslamicSource {
  const TrustedIslamicSource({
    required this.slug,
    required this.title,
    required this.originalUrl,
    required this.licenseName,
    required this.licenseUrl,
    required this.licenseScope,
    required this.redistributionAllowed,
    this.notes,
  });

  final String slug;
  final String title;
  final String originalUrl;
  final String licenseName;
  final String licenseUrl;
  final String licenseScope;
  final bool redistributionAllowed;
  final String? notes;

  factory TrustedIslamicSource.fromJson(JsonMap json) => TrustedIslamicSource(
    slug: '${json['slug'] ?? ''}',
    title: '${json['title'] ?? ''}',
    originalUrl: '${json['original_url'] ?? ''}',
    licenseName: '${json['license_name'] ?? ''}',
    licenseUrl: '${json['license_url'] ?? ''}',
    licenseScope: '${json['license_scope'] ?? ''}',
    redistributionAllowed: json['redistribution_allowed'] == true,
    notes: json['notes'] as String?,
  );
}

@immutable
class TrustedIslamicAudioAsset {
  const TrustedIslamicAudioAsset({
    required this.id,
    required this.slug,
    required this.kind,
    required this.titleAr,
    required this.sourceSlug,
    required this.originalSourceUrl,
    required this.audioUrl,
    required this.mimeType,
    required this.byteSize,
    required this.sha256,
    required this.licenseName,
    required this.licenseUrl,
    required this.reviewStatus,
    required this.redistributionAllowed,
    this.voiceName,
    this.durationMs,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String slug;
  final String kind;
  final String titleAr;
  final String? voiceName;
  final String sourceSlug;
  final String originalSourceUrl;
  final String audioUrl;
  final String mimeType;
  final int byteSize;
  final int? durationMs;
  final String sha256;
  final String licenseName;
  final String licenseUrl;
  final String reviewStatus;
  final bool redistributionAllowed;
  final JsonMap metadata;

  bool get integrityValid =>
      audioUrl.startsWith('https://') &&
      mimeType.toLowerCase().contains('ogg') &&
      RegExp(r'^[0-9a-f]{64}$').hasMatch(sha256);

  factory TrustedIslamicAudioAsset.fromJson(JsonMap json) =>
      TrustedIslamicAudioAsset(
        id: '${json['id'] ?? ''}',
        slug: '${json['slug'] ?? ''}',
        kind: '${json['kind'] ?? ''}',
        titleAr: '${json['title_ar'] ?? ''}',
        voiceName: json['voice_name'] as String?,
        sourceSlug: '${json['source_slug'] ?? ''}',
        originalSourceUrl: '${json['original_source_url'] ?? ''}',
        audioUrl: '${json['audio_url'] ?? ''}',
        mimeType: '${json['mime_type'] ?? ''}',
        byteSize: (json['byte_size'] as num?)?.toInt() ?? 0,
        durationMs: (json['duration_ms'] as num?)?.toInt(),
        sha256: '${json['sha256'] ?? ''}',
        licenseName: '${json['license_name'] ?? ''}',
        licenseUrl: '${json['license_url'] ?? ''}',
        // The public API only returns rows selected by the approved +
        // redistribution_allowed RPC. Keep the explicit fields locally so a
        // cached asset remains self-describing.
        reviewStatus: '${json['review_status'] ?? 'approved'}',
        redistributionAllowed: json['redistribution_allowed'] != false,
        metadata: _map(json['metadata']),
      );
}

@immutable
class TrustedIslamicContentItem {
  const TrustedIslamicContentItem({
    required this.id,
    required this.sourceSlug,
    required this.sourceTitle,
    required this.sourceKey,
    required this.titleAr,
    required this.textAr,
    required this.categories,
    required this.categoryNamesAr,
    required this.repeatCount,
    required this.licenseName,
    required this.licenseUrl,
    required this.originalSourceUrl,
    required this.reviewStatus,
    required this.sha256,
    required this.metadata,
    this.reference,
    this.sourceFileSha256,
    this.sourceRevision,
    this.audio,
  });

  final String id;
  final String sourceSlug;
  final String sourceTitle;
  final String sourceKey;
  final String titleAr;
  final String textAr;
  final List<String> categories;
  final List<String> categoryNamesAr;
  final String? reference;
  final int repeatCount;
  final TrustedIslamicAudioAsset? audio;
  final String licenseName;
  final String licenseUrl;
  final String originalSourceUrl;
  final String reviewStatus;
  final String sha256;
  final String? sourceFileSha256;
  final String? sourceRevision;
  final JsonMap metadata;

  factory TrustedIslamicContentItem.fromJson(JsonMap json) =>
      TrustedIslamicContentItem(
        id: '${json['id'] ?? ''}',
        sourceSlug: '${json['source_slug'] ?? ''}',
        sourceTitle: '${json['source_title'] ?? ''}',
        sourceKey: '${json['source_key'] ?? ''}',
        titleAr: '${json['title_ar'] ?? ''}',
        textAr: '${json['text_ar'] ?? ''}',
        categories: _strings(json['categories']),
        categoryNamesAr: _strings(json['category_names_ar']),
        reference: json['reference'] as String?,
        repeatCount: (json['repeat_count'] as num?)?.toInt() ?? 1,
        audio: json['audio'] is Map
            ? TrustedIslamicAudioAsset.fromJson(_map(json['audio']))
            : null,
        licenseName: '${json['license_name'] ?? ''}',
        licenseUrl: '${json['license_url'] ?? ''}',
        originalSourceUrl: '${json['original_source_url'] ?? ''}',
        reviewStatus: '${json['review_status'] ?? 'approved'}',
        sha256: '${json['sha256'] ?? ''}',
        sourceFileSha256: json['source_file_sha256'] as String?,
        sourceRevision: json['source_revision'] as String?,
        metadata: _map(json['metadata']),
      );
}

@immutable
class TrustedIslamicScheduleTemplate {
  const TrustedIslamicScheduleTemplate({
    required this.id,
    required this.slug,
    required this.titleAr,
    required this.categorySlug,
    required this.triggerKind,
    required this.offsetMinutes,
    required this.defaultEnabled,
    required this.metadata,
    this.fixedLocalTime,
    this.prayer,
    this.audioAssetId,
  });

  final String id;
  final String slug;
  final String titleAr;
  final String categorySlug;
  final String triggerKind;
  final String? fixedLocalTime;
  final String? prayer;
  final int offsetMinutes;
  final String? audioAssetId;
  final bool defaultEnabled;
  final JsonMap metadata;

  factory TrustedIslamicScheduleTemplate.fromJson(JsonMap json) =>
      TrustedIslamicScheduleTemplate(
        id: '${json['id'] ?? ''}',
        slug: '${json['slug'] ?? ''}',
        titleAr: '${json['title_ar'] ?? ''}',
        categorySlug: '${json['category_slug'] ?? ''}',
        triggerKind: '${json['trigger_kind'] ?? ''}',
        fixedLocalTime: json['fixed_local_time'] as String?,
        prayer: json['prayer'] as String?,
        offsetMinutes: (json['offset_minutes'] as num?)?.toInt() ?? 0,
        audioAssetId: json['audio_asset_id'] as String?,
        defaultEnabled: json['default_enabled'] == true,
        metadata: _map(json['metadata']),
      );
}

class TrustedIslamicLibraryException implements Exception {
  const TrustedIslamicLibraryException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => '$code: $message';
}

class TrustedIslamicLibraryApi {
  TrustedIslamicLibraryApi({
    http.Client? client,
    String? baseUrl,
    String? apiKey,
  }) : _client = client ?? http.Client(),
       baseUrl = (baseUrl ?? const String.fromEnvironment(
         'ISLAMIC_LIBRARY_API_BASE_URL',
         defaultValue:
             'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/islamic-library',
       )).replaceAll(RegExp(r'/$'), ''),
       apiKey = apiKey ?? const String.fromEnvironment(
         'TARTEEL_API_KEY',
         defaultValue: 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK',
       );

  static const timeout = Duration(seconds: 15);
  final http.Client _client;
  final String baseUrl;
  final String apiKey;

  Future<JsonMap> get(
    String path, {
    Map<String, String?> query = const <String, String?>{},
  }) async {
    final filtered = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.trim().isNotEmpty)
          entry.key: entry.value!,
    };
    final uri = Uri.parse(
      '$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
    late http.Response response;
    try {
      response = await _client.get(uri, headers: <String, String>{
        'accept': 'application/json',
        'apikey': apiKey,
      }).timeout(timeout);
    } on TimeoutException {
      throw const TrustedIslamicLibraryException(
        'NETWORK_TIMEOUT',
        'Timed out while loading Islamic content',
      );
    } on http.ClientException {
      throw const TrustedIslamicLibraryException(
        'NETWORK_UNAVAILABLE',
        'Unable to reach the Islamic content service',
      );
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw TrustedIslamicLibraryException(
        'INVALID_RESPONSE',
        'Islamic content service returned invalid JSON (${response.statusCode})',
      );
    }
    if (decoded is! Map) {
      throw const TrustedIslamicLibraryException(
        'INVALID_RESPONSE',
        'Islamic content service returned an invalid payload',
      );
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode >= 200 && response.statusCode < 300) return map;
    final error = _map(map['error']);
    throw TrustedIslamicLibraryException(
      '${error['code'] ?? 'HTTP_${response.statusCode}'}',
      '${error['message'] ?? 'Islamic content request failed'}',
    );
  }
}

class TrustedIslamicLibraryRepository extends ChangeNotifier {
  TrustedIslamicLibraryRepository({
    TrustedIslamicLibraryApi? api,
    http.Client? audioClient,
  }) : api = api ?? TrustedIslamicLibraryApi(),
       _audioClient = audioClient ?? http.Client();

  final TrustedIslamicLibraryApi api;
  final http.Client _audioClient;

  Database? _database;
  Directory? _root;
  Future<void>? _initialization;
  bool _syncing = false;
  String? _lastError;

  bool get syncing => _syncing;
  String? get lastError => _lastError;

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory(p.join(support.path, 'trusted-islamic-library-v1'));
    await _root!.create(recursive: true);
    _database = await openDatabase(
      p.join(support.path, 'trusted-islamic-library-v1.sqlite3'),
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE content_cache (
            id TEXT NOT NULL,
            category TEXT NOT NULL,
            json TEXT NOT NULL,
            sha256 TEXT NOT NULL,
            cached_at TEXT NOT NULL,
            PRIMARY KEY(id, category)
          )
        ''');
        await database.execute(
          'CREATE INDEX content_cache_category_idx ON content_cache(category, cached_at DESC)',
        );
        await database.execute('''
          CREATE TABLE document_cache (
            cache_key TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE audio_cache (
            sha256 TEXT PRIMARY KEY,
            slug TEXT NOT NULL,
            file_path TEXT NOT NULL,
            byte_size INTEGER NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<List<TrustedIslamicCategory>> categories({bool refresh = false}) async {
    await initialize();
    final cached = await _readDocumentList(
      'categories',
      TrustedIslamicCategory.fromJson,
    );
    if (!refresh && cached.isNotEmpty) {
      unawaited(_refreshCategories());
      return cached;
    }
    return _refreshCategories(fallback: cached);
  }

  Future<List<TrustedIslamicCategory>> _refreshCategories({
    List<TrustedIslamicCategory> fallback = const <TrustedIslamicCategory>[],
  }) async {
    try {
      final root = await api.get('categories');
      final raw = _maps(root['data']);
      await _writeDocument('categories', raw);
      _lastError = null;
      return raw.map(TrustedIslamicCategory.fromJson).toList(growable: false);
    } catch (error) {
      _lastError = '$error';
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<List<TrustedIslamicSource>> sources({bool refresh = false}) async {
    await initialize();
    final cached = await _readDocumentList('sources', TrustedIslamicSource.fromJson);
    if (!refresh && cached.isNotEmpty) {
      unawaited(_refreshSources());
      return cached;
    }
    return _refreshSources(fallback: cached);
  }

  Future<List<TrustedIslamicSource>> _refreshSources({
    List<TrustedIslamicSource> fallback = const <TrustedIslamicSource>[],
  }) async {
    try {
      final root = await api.get('sources');
      final raw = _maps(root['data']);
      await _writeDocument('sources', raw);
      _lastError = null;
      return raw.map(TrustedIslamicSource.fromJson).toList(growable: false);
    } catch (error) {
      _lastError = '$error';
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<List<TrustedIslamicScheduleTemplate>> schedules({bool refresh = false}) async {
    await initialize();
    final cached = await _readDocumentList(
      'schedules',
      TrustedIslamicScheduleTemplate.fromJson,
    );
    if (!refresh && cached.isNotEmpty) {
      unawaited(_refreshSchedules());
      return cached;
    }
    return _refreshSchedules(fallback: cached);
  }

  Future<List<TrustedIslamicScheduleTemplate>> _refreshSchedules({
    List<TrustedIslamicScheduleTemplate> fallback =
        const <TrustedIslamicScheduleTemplate>[],
  }) async {
    try {
      final root = await api.get('schedules');
      final raw = _maps(root['data']);
      await _writeDocument('schedules', raw);
      _lastError = null;
      return raw.map(TrustedIslamicScheduleTemplate.fromJson).toList(growable: false);
    } catch (error) {
      _lastError = '$error';
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<List<TrustedIslamicContentItem>> content(
    String category, {
    bool refresh = false,
  }) async {
    await initialize();
    final cached = await _cachedContent(category);
    if (!refresh && cached.isNotEmpty) {
      unawaited(refreshCategory(category));
      return cached;
    }
    try {
      return await refreshCategory(category);
    } catch (_) {
      if (cached.isNotEmpty) return cached;
      rethrow;
    }
  }

  Future<List<TrustedIslamicContentItem>> refreshCategory(String category) async {
    await initialize();
    _validateCategory(category);
    _syncing = true;
    _lastError = null;
    notifyListeners();
    try {
      final result = <TrustedIslamicContentItem>[];
      final rawAll = <JsonMap>[];
      var page = 1;
      while (true) {
        final root = await api.get(
          'content',
          query: <String, String?>{
            'category': category,
            'page': '$page',
            'limit': '200',
          },
        );
        final raw = _maps(root['data']);
        for (final json in raw) {
          final item = TrustedIslamicContentItem.fromJson(json);
          if (item.reviewStatus != 'approved' ||
              !RegExp(r'^[0-9a-f]{64}$').hasMatch(item.sha256)) {
            throw const TrustedIslamicLibraryException(
              'CONTENT_INTEGRITY_INVALID',
              'Server content failed review or SHA-256 validation',
            );
          }
          result.add(item);
          rawAll.add(json);
        }
        final next = (root['next_page'] as num?)?.toInt();
        if (next == null || next <= page) break;
        page = next;
      }
      await _replaceCachedCategory(category, rawAll);
      return result;
    } catch (error) {
      _lastError = '$error';
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<List<TrustedIslamicAudioAsset>> audio({
    String? kind,
    bool refresh = false,
  }) async {
    await initialize();
    final key = 'audio:${kind ?? 'all'}';
    final cached = await _readDocumentList(key, TrustedIslamicAudioAsset.fromJson);
    if (!refresh && cached.isNotEmpty) {
      unawaited(_refreshAudio(kind: kind));
      return cached;
    }
    return _refreshAudio(kind: kind, fallback: cached);
  }

  Future<List<TrustedIslamicAudioAsset>> _refreshAudio({
    String? kind,
    List<TrustedIslamicAudioAsset> fallback = const <TrustedIslamicAudioAsset>[],
  }) async {
    final key = 'audio:${kind ?? 'all'}';
    try {
      final root = await api.get(
        'audio',
        query: <String, String?>{'kind': kind, 'page': '1', 'limit': '100'},
      );
      final raw = _maps(root['data']);
      final approved = <JsonMap>[];
      for (final entry in raw) {
        final normalized = <String, dynamic>{
          ...entry,
          'review_status': 'approved',
          'redistribution_allowed': true,
        };
        final asset = TrustedIslamicAudioAsset.fromJson(normalized);
        if (!asset.integrityValid || !asset.redistributionAllowed) {
          throw const TrustedIslamicLibraryException(
            'AUDIO_INTEGRITY_INVALID',
            'Approved audio metadata failed validation',
          );
        }
        approved.add(normalized);
      }
      await _writeDocument(key, approved);
      _lastError = null;
      return approved.map(TrustedIslamicAudioAsset.fromJson).toList(growable: false);
    } catch (error) {
      _lastError = '$error';
      if (fallback.isNotEmpty) return fallback;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<File> downloadAudio(TrustedIslamicAudioAsset asset) async {
    await initialize();
    if (!asset.redistributionAllowed ||
        asset.reviewStatus != 'approved' ||
        !asset.integrityValid) {
      throw const TrustedIslamicLibraryException(
        'AUDIO_RIGHTS_BLOCKED',
        'Audio is not approved for redistribution',
      );
    }
    final cached = await cachedAudio(asset.sha256);
    if (cached != null) return cached;

    late http.Response response;
    try {
      response = await _audioClient
          .get(Uri.parse(asset.audioUrl))
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const TrustedIslamicLibraryException(
        'AUDIO_DOWNLOAD_TIMEOUT',
        'Audio download timed out',
      );
    } on http.ClientException {
      throw const TrustedIslamicLibraryException(
        'AUDIO_DOWNLOAD_FAILED',
        'Unable to download audio',
      );
    }
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw TrustedIslamicLibraryException(
        'AUDIO_HTTP_${response.statusCode}',
        'Unable to download approved audio',
      );
    }
    if (asset.byteSize > 0 && response.bodyBytes.length != asset.byteSize) {
      throw const TrustedIslamicLibraryException(
        'AUDIO_SIZE_MISMATCH',
        'Downloaded audio size does not match the reviewed asset',
      );
    }
    final actual = sha256.convert(response.bodyBytes).toString();
    if (actual != asset.sha256) {
      throw const TrustedIslamicLibraryException(
        'AUDIO_SHA256_MISMATCH',
        'Downloaded audio failed integrity verification',
      );
    }

    final directory = Directory(p.join(_root!.path, 'audio'));
    await directory.create(recursive: true);
    final target = File(p.join(directory.path, '${asset.sha256}.ogg'));
    final partial = File('${target.path}.partial');
    await partial.writeAsBytes(response.bodyBytes, flush: true);
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
    await _database!.insert(
      'audio_cache',
      <String, Object>{
        'sha256': asset.sha256,
        'slug': asset.slug,
        'file_path': target.path,
        'byte_size': response.bodyBytes.length,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
    return target;
  }

  Future<File?> cachedAudio(String sha256Value) async {
    await initialize();
    final rows = await _database!.query(
      'audio_cache',
      where: 'sha256 = ?',
      whereArgs: <Object>[sha256Value],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final path = rows.first['file_path'] as String?;
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) {
      await _database!.delete('audio_cache', where: 'sha256 = ?', whereArgs: <Object>[sha256Value]);
      return null;
    }
    final bytes = await file.readAsBytes();
    if (sha256.convert(bytes).toString() != sha256Value) {
      await file.delete();
      await _database!.delete('audio_cache', where: 'sha256 = ?', whereArgs: <Object>[sha256Value]);
      return null;
    }
    return file;
  }

  Future<void> synchronizeInBackground() async {
    await initialize();
    try {
      await Future.wait<dynamic>(<Future<dynamic>>[
        categories(refresh: true),
        sources(refresh: true),
        schedules(refresh: true),
        audio(refresh: true),
      ]);
    } catch (error) {
      debugPrint('TRUSTED_ISLAMIC_LIBRARY_SYNC_DEFERRED:${error.runtimeType}');
    }
  }

  Future<List<TrustedIslamicContentItem>> _cachedContent(String category) async {
    final rows = await _database!.query(
      'content_cache',
      where: 'category = ?',
      whereArgs: <Object>[category],
      orderBy: 'id',
    );
    return rows.map((row) {
      final decoded = jsonDecode(row['json'] as String);
      return TrustedIslamicContentItem.fromJson(Map<String, dynamic>.from(decoded as Map));
    }).toList(growable: false);
  }

  Future<void> _replaceCachedCategory(String category, List<JsonMap> values) async {
    await _database!.transaction((txn) async {
      await txn.delete('content_cache', where: 'category = ?', whereArgs: <Object>[category]);
      final batch = txn.batch();
      final cachedAt = DateTime.now().toUtc().toIso8601String();
      for (final json in values) {
        final id = '${json['id'] ?? ''}';
        final digest = '${json['sha256'] ?? ''}';
        if (id.isEmpty || !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) continue;
        batch.insert(
          'content_cache',
          <String, Object>{
            'id': id,
            'category': category,
            'json': jsonEncode(json),
            'sha256': digest,
            'cached_at': cachedAt,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _writeDocument(String key, List<JsonMap> values) async {
    await _database!.insert(
      'document_cache',
      <String, Object>{
        'cache_key': key,
        'json': jsonEncode(values),
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<T>> _readDocumentList<T>(
    String key,
    T Function(JsonMap json) parser,
  ) async {
    final rows = await _database!.query(
      'document_cache',
      where: 'cache_key = ?',
      whereArgs: <Object>[key],
      limit: 1,
    );
    if (rows.isEmpty) return <T>[];
    try {
      return _maps(jsonDecode(rows.first['json'] as String))
          .map(parser)
          .toList(growable: false);
    } catch (_) {
      return <T>[];
    }
  }

  void _validateCategory(String category) {
    if (!RegExp(r'^[a-z][a-z0-9_]{1,49}$').hasMatch(category)) {
      throw ArgumentError.value(category, 'category', 'Invalid category slug');
    }
  }
}

JsonMap _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<JsonMap> _maps(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false)
    : <JsonMap>[];

List<String> _strings(Object? value) => value is List
    ? value.map((item) => '$item').toList(growable: false)
    : const <String>[];
