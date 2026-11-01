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

  Future<List<Map<String, dynamic>>> surahProjects() async {
    final root = await _get('/v1/surah-projects');
    if (root['contentStorage'] != 'metadata_only' ||
        root['contentAccess'] != 'direct_official_api' ||
        root['projects'] is! List) {
      throw const FormatException('INVALID_SURAH_REGISTRY');
    }
    return (root['projects'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> distributionConfig() async {
    final data = await _get('/v1/bootstrap');
    final release = data['release'];
    if (data['schema'] != 1 ||
        release is! Map ||
        release['application_id'] != 'app.tarteel.tarteel' ||
        release['architecture'] != 'arm64-v8a' ||
        release['channel'] != 'preview' ||
        release['version_code'] is! int ||
        (release['version_code'] as int) <= 2074 ||
        release['minimum_sdk'] is! int ||
        (release['minimum_sdk'] as int) < 26 ||
        release['version_name'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch('${release['apk_sha256']}') ||
        release['certificate_sha256'] !=
            '5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8') {
      throw const FormatException('INVALID_DISTRIBUTION');
    }
    final url = Uri.tryParse('${release['apk_url']}');
    if (url == null ||
        url.scheme != 'https' ||
        url.host != 'github.com' ||
        url.userInfo.isNotEmpty ||
        !url.path.startsWith('/Mtzallqmy/Quran-yomk/releases/download/')) {
      throw const FormatException('INVALID_RELEASE_URL');
    }
    return {
      'latest_android_version': release['version_name'],
      'recommended_android_version': release['version_name'],
      'latest_android_version_code': release['version_code'],
      'android_update_url': url.toString(),
      'android_update_sha256': release['apk_sha256'],
    };
  }

  void dispose() => _client.close();
}
