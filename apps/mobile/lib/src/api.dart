import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'offline_clip_contract.dart';
import 'quran_models.dart';

class ApiException implements Exception {
  const ApiException(
    this.code,
    this.message, {
    this.statusCode,
    this.requestId,
  });
  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  @override
  String toString() => '$code: $message';
}

class TarteelApiClient {
  TarteelApiClient({http.Client? client, String? baseUrl, String? apiKey})
    : _client = client ?? http.Client(),
      baseUrl = _resolveBaseUrl(baseUrl),
      apiKey =
          apiKey ??
          const String.fromEnvironment(
            'TARTEEL_API_KEY',
            defaultValue: 'sb_publishable_dLYCid35ZkeIE95xqiyHoQ_bEhWWISK',
          );

  static const productionBaseUrl =
      'https://qkroecnecdxghcqvvoxn.supabase.co/functions/v1/tarteel-api';
  static const Duration timeout = Duration(seconds: 12);
  final http.Client _client;
  final String baseUrl;
  final String apiKey;

  static String _resolveBaseUrl(String? override) {
    const configured = String.fromEnvironment(
      'TARTEEL_API_BASE_URL',
      defaultValue: productionBaseUrl,
    );
    final value = override ?? configured;
    return (value.contains('.invalid') ? productionBaseUrl : value).replaceAll(
      RegExp(r'/$'),
      '',
    );
  }

  Map<String, String> get _headers => <String, String>{
    'accept': 'application/json',
    'apikey': apiKey,
  };

  Uri _uri(
    String path, [
    Map<String, String?> query = const <String, String?>{},
  ]) {
    final filtered = <String, String>{
      for (final entry in query.entries)
        if (entry.value != null && entry.value!.isNotEmpty)
          entry.key: entry.value!,
    };
    return Uri.parse(
      '$baseUrl/${path.replaceFirst(RegExp(r'^/'), '')}',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }

  Future<JsonMap> _get(
    String path, {
    Map<String, String?> query = const <String, String?>{},
    bool allowRetry = true,
  }) async {
    final attempts = allowRetry ? 2 : 1;
    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final response = await _client
            .get(_uri(path, query), headers: _headers)
            .timeout(timeout);
        dynamic decoded;
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          throw ApiException(
            'INVALID_RESPONSE',
            'Service returned invalid JSON',
            statusCode: response.statusCode,
            requestId: response.headers['x-request-id'],
          );
        }
        if (decoded is! Map) {
          throw ApiException(
            'INVALID_RESPONSE',
            'Service returned an invalid response',
            statusCode: response.statusCode,
            requestId: response.headers['x-request-id'],
          );
        }
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return Map<String, dynamic>.from(decoded);
        }
        final error = jsonMap(decoded['error']);
        final exception = ApiException(
          error['code'] is String
              ? error['code'] as String
              : 'HTTP_${response.statusCode}',
          error['message'] is String
              ? error['message'] as String
              : 'Service request failed',
          statusCode: response.statusCode,
          requestId: error['request_id'] is String
              ? error['request_id'] as String
              : response.headers['x-request-id'],
        );
        if (attempt + 1 < attempts && response.statusCode >= 500) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
        throw exception;
      } on TimeoutException {
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
      } on http.ClientException {
        if (attempt + 1 < attempts) {
          await Future<void>.delayed(const Duration(milliseconds: 450));
          continue;
        }
      }
    }
    throw const ApiException(
      'NETWORK_UNAVAILABLE',
      'Unable to reach Tarteel service',
    );
  }

  Future<PageResult<Station>> stations({
    int page = 1,
    int limit = 200,
    String? source,
    String? category,
    String? provider,
    String? search,
  }) async {
    final root = await _get(
      'stations',
      query: <String, String?>{
        'page': '$page',
        'limit': '$limit',
        'source': source,
        'category': category,
        'provider': provider,
        'search': search,
      },
    );
    return PageResult<Station>(
      data: jsonList(
        root['data'],
      ).map((e) => Station.fromJson(jsonMap(e))).toList(growable: false),
      page: root['page'] is int ? root['page'] as int : page,
      limit: root['limit'] is int ? root['limit'] as int : limit,
      total: root['total'] is int ? root['total'] as int : 0,
      nextPage: root['next_page'] is int ? root['next_page'] as int : null,
    );
  }

  Future<Station> station(String slug) async => Station.fromJson(
    jsonMap((await _get('stations/${Uri.encodeComponent(slug)}'))['data']),
  );

  Future<OfflineClipPolicy> offlineClipPolicy(String slug) async =>
      OfflineClipPolicy.fromJson(
        jsonMap(
          (await _get(
            'stations/${Uri.encodeComponent(slug)}/offline-clip-policy',
            allowRetry: false,
          ))['data'],
        ),
      );

  Future<NowPlaying> nowPlaying(String slug) async => NowPlaying.fromJson(
    jsonMap(
      (await _get(
        'stations/${Uri.encodeComponent(slug)}/now-playing',
        allowRetry: false,
      ))['data'],
    ),
  );

  Future<JsonMap> virtualRadio({
    List<String> failedStationIds = const <String>[],
  }) async => jsonMap(
    (await _get(
      'virtual-radio/tarteel',
      query: <String, String?>{
        'failed_station_ids': failedStationIds.isEmpty
            ? null
            : failedStationIds.take(8).join(','),
      },
      allowRetry: false,
    ))['data'],
  );

  Future<List<ContentSource>> contentSources() async => jsonList(
    (await _get('content-sources'))['data'],
  ).map((e) => ContentSource.fromJson(jsonMap(e))).toList(growable: false);

  Future<List<Category>> categories() async => jsonList(
    (await _get('categories'))['data'],
  ).map((e) => Category.fromJson(jsonMap(e))).toList(growable: false);

  Future<PageResult<Reciter>> reciters({
    String? query,
    int page = 1,
    int limit = 30,
  }) async {
    final root = await _get(
      'reciters',
      query: <String, String?>{'q': query, 'page': '$page', 'limit': '$limit'},
    );
    return PageResult<Reciter>(
      data: jsonList(
        root['data'],
      ).map((e) => Reciter.fromJson(jsonMap(e))).toList(growable: false),
      page: root['page'] is int ? root['page'] as int : page,
      limit: root['limit'] is int ? root['limit'] as int : limit,
      total: root['total'] is int ? root['total'] as int : 0,
      nextPage: root['next_page'] is int ? root['next_page'] as int : null,
    );
  }

  Future<Reciter> reciter(String id) async =>
      Reciter.fromJson(jsonMap((await _get('reciters/$id'))['data']));

  Future<List<ReciterTrack>> reciterTracks(String id) async => jsonList(
    (await _get('reciters/$id/surahs', allowRetry: false))['data'],
  ).map((e) => ReciterTrack.fromJson(jsonMap(e))).toList(growable: false);

  Future<List<Surah>> surahs() async {
    final values = jsonList(
      (await _get('surahs'))['data'],
    ).map((e) => Surah.fromJson(jsonMap(e))).toList(growable: false);
    if (values.length != 114 ||
        values.asMap().entries.any(
          (entry) => entry.value.number != entry.key + 1,
        )) {
      throw const ApiException(
        'CATALOG_INTEGRITY',
        'Surah catalog is incomplete or unordered',
      );
    }
    return values;
  }

  Future<QuranPassage> quranPassage(QuranBrowseMode mode, int number) async =>
      QuranPassage.fromJson(
        jsonMap(
          (await _get('quran/${mode.name}/$number', allowRetry: true))['data'],
        ),
      );

  Future<List<QuranAudioReciter>> quranAudioReciters(int surahNumber) async {
    final root = jsonMap(
      (await _get(
        'quran/reciters',
        query: <String, String?>{'surah': '$surahNumber'},
      ))['data'],
    );
    return jsonList(root['reciters'])
        .map((e) => QuranAudioReciter.fromJson(jsonMap(e)))
        .toList(growable: false);
  }

  Future<List<QuranAudioTrack>> quranAudioTracks(String reciterId) async {
    final root = jsonMap(
      (await _get(
        'quran/reciters/${Uri.encodeComponent(reciterId)}/tracks',
      ))['data'],
    );
    return jsonList(
      root['tracks'],
    ).map((e) => QuranAudioTrack.fromJson(jsonMap(e))).toList(growable: false);
  }

  Future<List<FeaturedItem>> featured() async => jsonList(
    (await _get('featured'))['data'],
  ).map((e) => FeaturedItem.fromJson(jsonMap(e))).toList(growable: false);

  Future<JsonMap> appConfig() async =>
      jsonMap((await _get('app-config'))['data']);

  Future<SearchBundle> search(String query) async {
    if (query.trim().length < 2) {
      return const SearchBundle(
        stations: <Station>[],
        reciters: <Reciter>[],
        surahs: <Surah>[],
      );
    }
    return SearchBundle.fromJson(
      jsonMap(
        (await _get(
          'search',
          query: <String, String?>{'q': query.trim()},
          allowRetry: false,
        ))['data'],
      ),
    );
  }

  void close() => _client.close();
}
