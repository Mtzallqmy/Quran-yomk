import 'dart:convert';
import 'package:http/http.dart' as http;

/// Optional public metadata/translation API. No database or administrative keys.
class ContentCatalogApi {
  ContentCatalogApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'TARTEEL_CONTENT_BASE_URL',
            defaultValue:
                'https://br-curly-salad-bajy1evn-tarteelcontent.compute.c-8.eu-central-1.aws.neon.tech',
          );
  final http.Client _client;
  final String baseUrl;
  Future<Map<String, dynamic>> _get(String path) async {
    final base = Uri.parse(baseUrl);
    if (base.scheme != 'https' || base.userInfo.isNotEmpty)
      throw const FormatException('Invalid content service');
    final r = await _client
        .get(base.resolve(path))
        .timeout(const Duration(seconds: 12));
    if (r.statusCode != 200 || r.bodyBytes.length > 4 * 1024 * 1024)
      throw const FormatException('Content temporarily unavailable');
    return Map<String, dynamic>.from(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map,
    );
  }

  Future<List<Map<String, dynamic>>> translations() async {
    final root = await _get('/v1/catalog');
    return (root['data'] as List)
        .whereType<Map<String, dynamic>>()
        .where((r) => r['kind'] == 'translation')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<Map<String, dynamic>> translation(String key, int surah) {
    if (!RegExp(r'^[a-z0-9_]{1,100}$').hasMatch(key) ||
        surah < 1 ||
        surah > 114)
      throw const FormatException('Invalid translation identity');
    return _get('/v1/translations/$key/$surah');
  }

  Future<Map<String, dynamic>> mushafLibrary() => _get('/v1/mushaf-library');

  /// Metadata from Neon; large SVG page bytes remain in external asset storage.
  Future<Map<String, dynamic>> mushafPageIndex(int page) {
    if (page < 1 || page > 604) throw RangeError.range(page, 1, 604, 'page');
    return _get('/v1/mushaf/page/$page');
  }

  Future<Map<String, dynamic>> thematicSurahIndex(int surah) {
    if (surah < 1 || surah > 114) throw RangeError.range(surah, 1, 114, 'surah');
    return _get('/v1/mushaf/themes/$surah');
  }


  void dispose() => _client.close();
}
