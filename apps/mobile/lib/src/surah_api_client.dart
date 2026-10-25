import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Public, read-only Surah API adapter. Quran text still comes from the
/// independently verified canonical source; this adapter handles study data.
/// API responses are not written to SQLite, Neon or the APK.
class SurahApiException implements Exception {
  const SurahApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'SurahApiException($statusCode): $message';
}

class SurahProject {
  const SurahProject({
    required this.slug,
    required this.title,
    this.type = '',
  });

  final String slug;
  final String title;
  final String type;

  static SurahProject? tryParse(Map<String, dynamic> value) {
    final slug = (value['slug'] ?? value['project_slug'] ?? '').toString();
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(slug)) return null;
    final title = (value['name_ar'] ??
            value['title_ar'] ??
            value['name'] ??
            value['title'] ??
            slug)
        .toString();
    final rawType = value['type'];
    final type = rawType is String
        ? rawType
        : rawType is Map
            ? (rawType['slug'] ?? rawType['name'] ?? '').toString()
            : '';
    return SurahProject(slug: slug, title: title, type: type);
  }
}

class SurahApiClient {
  SurahApiClient({http.Client? client, Uri? baseUri, this.timeout = const Duration(seconds: 12)})
      : _client = client ?? http.Client(),
        _baseUri = baseUri ?? Uri.parse('https://dev.surahapp.com/api/v1');

  final http.Client _client;
  final Uri _baseUri;
  final Duration timeout;

  static String _slug(String value) {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(value)) {
      throw ArgumentError.value(value, 'slug', 'Invalid project slug');
    }
    return value;
  }

  static int _surah(int number) {
    if (number < 1 || number > 114) {
      throw RangeError.range(number, 1, 114, 'surahNumber');
    }
    return number;
  }

  static int _positive(int number, String name) {
    if (number < 1) throw RangeError.value(number, name, 'Must be positive');
    return number;
  }

  Future<Object?> _get(String path) async {
    if (_baseUri.scheme != 'https') {
      throw StateError('Surah API requires HTTPS');
    }
    final uri = Uri.parse('${_baseUri.toString().replaceFirst(RegExp(r'/$'), '')}/$path');
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'accept': 'application/json'})
          .timeout(timeout);
    } on TimeoutException {
      throw const SurahApiException('Request timed out');
    } on http.ClientException {
      throw const SurahApiException('Network unavailable');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SurahApiException('Upstream rejected request',
          statusCode: response.statusCode);
    }
    if (response.bodyBytes.length > 4 * 1024 * 1024) {
      throw const SurahApiException('Unexpectedly large API response');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const SurahApiException('Malformed JSON response');
    }
  }

  /// Discover slugs from the API, never from a hard-coded project list.
  Future<List<SurahProject>> projects({String? type}) async {
    if (type != null) _slug(type);
    final response = await _get(type == null ? 'projects' : 'projects/${_slug(type)}');
    final result = <String, SurahProject>{};

    void collect(Object? value, [int depth = 0]) {
      if (depth > 6) return;
      if (value is List) {
        for (final item in value) {
          collect(item, depth + 1);
        }
      } else if (value is Map) {
        final data = Map<String, dynamic>.from(value);
        final project = SurahProject.tryParse(data);
        if (project != null) {
          result[project.slug] = project;
        } else {
          for (final entry in data.values) {
            collect(entry, depth + 1);
          }
        }
      }
    }

    collect(response);
    return List.unmodifiable(result.values);
  }

  Future<Object?> project(String slug) => _get('project/${_slug(slug)}');

  Future<Object?> sura(String slug, int surahNumber) =>
      _get('sura/${_slug(slug)}/${_surah(surahNumber)}');

  Future<Object?> page(String slug, int pageNumber) {
    if (pageNumber < 1 || pageNumber > 604) {
      throw RangeError.range(pageNumber, 1, 604, 'pageNumber');
    }
    return _get('page/${_slug(slug)}/$pageNumber');
  }

  Future<Object?> aya(String slug, int surahNumber, int ayahNumber) =>
      _get('aya/${_slug(slug)}/${_surah(surahNumber)}/${_positive(ayahNumber, 'ayahNumber')}');

  Future<Object?> word(String slug, int surahNumber, int ayahNumber, int wordNumber) =>
      _get('word/${_slug(slug)}/${_surah(surahNumber)}/${_positive(ayahNumber, 'ayahNumber')}/${_positive(wordNumber, 'wordNumber')}');

  /// Only read-only range requests that the public documentation advertises.
  Future<Object?> ayahRange(String slug, int surahNumber, int fromAyah, int toAyah) {
    _surah(surahNumber);
    _positive(fromAyah, 'fromAyah');
    _positive(toAyah, 'toAyah');
    if (fromAyah > toAyah) throw ArgumentError('Invalid ayah range');
    return _get('aya/${_slug(slug)}/$surahNumber/$fromAyah/$toAyah');
  }

  void close() => _client.close();
}
