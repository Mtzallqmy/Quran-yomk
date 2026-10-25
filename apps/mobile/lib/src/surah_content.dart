import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

enum SurahScope { sura, page, aya, word }

class SurahProject {
  const SurahProject(this.slug, this.title, this.scope);
  final String slug;
  final String title;
  final SurahScope scope;

  static SurahProject? parse(dynamic value) {
    if (value is! Map) return null;
    final slug = value['slug'];
    final scope = SurahScope.values
        .where((v) => v.name == value['type'])
        .firstOrNull;
    if (slug is! String ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(slug) ||
        scope == null ||
        value['published'] == false)
      return null;
    return SurahProject(slug, '${value['title'] ?? slug}', scope);
  }
}

/// No permanent caching grant has been verified for any discovered project.
class SurahRightsRegistry {
  static const attribution = 'سورة — مركز تفسير للدراسات القرآنية';
  static const website = 'https://surahapp.com/';
  static const documentation = 'https://dev.surahapp.com/api/docs';
  bool mayPersist(String slug) => false;
  bool mayEmbedMedia(String slug) => false;
}

class SurahCachePolicy {
  const SurahCachePolicy({
    this.ttl = const Duration(minutes: 3),
    this.capacity = 32,
  });
  final Duration ttl;
  final int capacity;
}

class SurahContentEntry {
  SurahContentEntry(this.data, this.project, this.sourceUrl);
  final Map<String, dynamic> data;
  final SurahProject project;
  final Uri sourceUrl;
  int? get wordNumber => (data['word_number'] as num?)?.toInt();
  String get word => plain('${data['word'] ?? ''}');
  String get text {
    final content = data['content'];
    return content is List
        ? content.cast<String>().map(plain).join('\n\n')
        : plain('${content ?? ''}');
  }

  String get sha256Hex =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();
  static String plain(String value) {
    final fragment = html.parseFragment(value);
    for (final element in fragment.querySelectorAll(
      'script,style,iframe,object',
    )) {
      element.remove();
    }
    return (fragment.text ?? '').trim();
  }
}

class _SessionEntry {
  _SessionEntry(this.value, this.at, this.etag);
  final dynamic value;
  final DateTime at;
  final String? etag;
}

/// Official educational content only. aya_text is never a canonical text source.
class SurahApiClient {
  SurahApiClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    this.policy = const SurahCachePolicy(),
    DateTime Function()? clock,
  }) : _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;
  static const base = 'https://dev.surahapp.com/api/v1';
  final http.Client _client;
  final Duration timeout;
  final SurahCachePolicy policy;
  final DateTime Function() _clock;
  final _cache = <String, _SessionEntry>{};
  final _pending = <String, Future<dynamic>>{};
  final _aborts = <Completer<void>>{};
  bool _closed = false;
  List<SurahProject>? _projects;

  Future<dynamic> _get(String path) {
    if (_closed) return Future.error(StateError('CLIENT_CLOSED'));
    final cached = _cache[path];
    if (cached != null && _clock().difference(cached.at) < policy.ttl)
      return Future.value(cached.value);
    return _pending.putIfAbsent(
      path,
      () => _request(path, cached).whenComplete(() {
        _pending.remove(path);
      }),
    );
  }

  Future<dynamic> _request(String path, _SessionEntry? cached) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final abort = Completer<void>();
      _aborts.add(abort);
      try {
        final request = http.AbortableRequest(
          'GET',
          Uri.parse('$base/$path'),
          abortTrigger: abort.future,
        );
        request.headers.addAll({
          'Accept': 'application/json',
          'User-Agent': 'Tarteel/0.9.1',
          if (cached?.etag != null) 'If-None-Match': cached!.etag!,
        });
        final response =
            await (() async {
              final stream = await _client.send(request);
              final bytes = <int>[];
              await for (final chunk in stream.stream) {
                bytes.addAll(chunk);
                if (bytes.length > 2 * 1024 * 1024)
                  throw StateError('CONTENT_TOO_LARGE');
              }
              return http.Response.bytes(
                bytes,
                stream.statusCode,
                headers: stream.headers,
              );
            })().timeout(
              timeout,
              onTimeout: () {
                if (!abort.isCompleted) abort.complete();
                throw TimeoutException('ONLINE_REQUIRED');
              },
            );
        if (response.statusCode == 304 && cached != null) {
          _cache[path] = _SessionEntry(cached.value, _clock(), cached.etag);
          return cached.value;
        }
        if (response.statusCode >= 500 && attempt == 0) continue;
        if (response.statusCode != 200)
          throw StateError(
            response.statusCode == 404
                ? 'CONTENT_NOT_AVAILABLE'
                : 'CONTENT_TEMPORARILY_UNAVAILABLE',
          );
        final value = jsonDecode(utf8.decode(response.bodyBytes));
        if (!(response.headers['cache-control'] ?? '').contains('no-store')) {
          if (_cache.length >= policy.capacity)
            _cache.remove(_cache.keys.first);
          _cache[path] = _SessionEntry(
            value,
            _clock(),
            response.headers['etag'],
          );
        }
        return value;
      } on TimeoutException {
        if (attempt == 1) rethrow;
      } on http.ClientException {
        if (attempt == 1) rethrow;
      } finally {
        _aborts.remove(abort);
        if (!abort.isCompleted) abort.complete();
      }
    }
    throw StateError('ONLINE_REQUIRED');
  }

  Future<List<SurahProject>> projects([SurahScope? scope]) async {
    final result = await _get(
      scope == null ? 'projects' : 'projects/${scope.name}',
    );
    if (result is! List) throw const FormatException('INVALID_CATALOG');
    final seen = <String>{};
    final values = result
        .map(SurahProject.parse)
        .whereType<SurahProject>()
        .where((p) => seen.add(p.slug))
        .toList();
    if (scope == null) _projects = values;
    return values;
  }

  Future<Map<String, dynamic>> project(String slug) async {
    await _published(slug);
    final result = await _get('project/$slug');
    if (result is! Map) throw const FormatException('INVALID_PROJECT');
    return Map<String, dynamic>.from(result);
  }

  Future<SurahProject> _published(String slug) async {
    final project = (_projects ?? await projects())
        .where((p) => p.slug == slug)
        .firstOrNull;
    if (project == null) throw StateError('PROJECT_NOT_AVAILABLE');
    return project;
  }

  /// Location: [sura], [page], [sura, aya], or [sura, aya, word].
  /// end appends the documented final-component range endpoint; at most32 rows.
  Future<List<SurahContentEntry>> read(
    String slug,
    List<int> location, {
    int? end,
  }) async {
    final project = await _published(slug);
    final count = switch (project.scope) {
      SurahScope.sura || SurahScope.page => 1,
      SurahScope.aya => 2,
      SurahScope.word => 3,
    };
    if (location.length != count ||
        location.any((v) => v < 1) ||
        location.first > (project.scope == SurahScope.page ? 604 : 114) ||
        (count > 1 && location[1] > 286) ||
        (count > 2 && location[2] > 200))
      throw ArgumentError('INVALID_LOCATION');
    if (end != null &&
        (end < location.last ||
            end - location.last >= 32 ||
            end >
                (count == 1
                    ? (project.scope == SurahScope.page ? 604 : 114)
                    : (count == 2 ? 286 : 200))))
      throw ArgumentError('INVALID_RANGE');
    if (slug == 'word-pic') throw StateError('MEDIA_RIGHTS_UNVERIFIED');
    final path =
        '${project.scope.name}/$slug/${[...location, if (end != null) end].join('/')}';
    final raw = await _get(path);
    final rows = raw is List ? raw : [raw];
    final seen = <String>{};
    return rows.map((row) {
      if (row is! Map ||
          !(row['content'] is String ||
              (project.scope == SurahScope.page &&
                  row['content'] is List &&
                  (row['content'] as List).every((v) => v is String))))
        throw const FormatException('INVALID_CONTENT');
      final keys = switch (project.scope) {
        SurahScope.sura => ['sura_number'],
        SurahScope.page => ['page_number'],
        SurahScope.aya => ['sura_number', 'aya_number'],
        SurahScope.word => ['sura_number', 'aya_number', 'word_number'],
      };
      final reference = keys.map((key) => (row[key] as num?)?.toInt()).toList();
      for (var i = 0; i < count; i++) {
        if (reference[i] == null ||
            reference[i]! < location[i] ||
            reference[i]! > (i == count - 1 ? end ?? location[i] : location[i]))
          throw const FormatException('CONTENT_REFERENCE_MISMATCH');
      }
      if (!seen.add(reference.join(':')))
        throw const FormatException('DUPLICATE_CONTENT');
      return SurahContentEntry(
        Map<String, dynamic>.from(row),
        project,
        Uri.parse('$base/$path'),
      );
    }).toList();
  }

  void close() {
    _closed = true;
    for (final abort in _aborts) {
      if (!abort.isCompleted) abort.complete();
    }
    _cache.clear();
    _projects = null;
    _client.close();
  }
}

class SurahProjectsRepository {
  SurahProjectsRepository(this.api);
  final SurahApiClient api;
  Future<List<SurahProject>> discover() => api.projects();
}

class SurahTafsirRepository {
  SurahTafsirRepository(this.api);
  final SurahApiClient api;
  Future<List<SurahContentEntry>> ayah(String slug, int surah, int ayah) =>
      api.read(slug, [surah, ayah]);
}

class SurahWordRepository {
  SurahWordRepository(this.api);
  final SurahApiClient api;
  Future<List<SurahContentEntry>> words(
    String slug,
    int surah,
    int ayah,
    int from, {
    int? to,
  }) => api.read(slug, [surah, ayah, from], end: to);
}

class SurahPageBenefitsRepository {
  SurahPageBenefitsRepository(this.api);
  final SurahApiClient api;
  Future<List<SurahContentEntry>> page(String slug, int page) =>
      api.read(slug, [page]);
}
