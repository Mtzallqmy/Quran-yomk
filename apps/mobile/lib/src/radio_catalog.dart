import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Normalize mirrors of the same stream without collapsing different stations
/// on a shared server. Query parameters remain significant.
String canonicalRadioUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null || !uri.hasAuthority) return '';
  var host = uri.host.toLowerCase();
  if (host == 'qurango.net' || host.endsWith('.qurango.net')) {
    host = 'qurango.net';
  }
  final port = uri.hasPort && uri.port != 80 && uri.port != 443
      ? ':${uri.port}'
      : '';
  return '$host$port${uri.path.replaceFirst(RegExp(r'/+$'), '')}'
      '${uri.hasQuery ? '?${uri.query}' : ''}';
}

String normalizedStationName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[\u064b-\u065f\u0670\u0640]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[^a-z0-9\u0621-\u064a]'), '');

/// Existing IDs always win, preserving favorites and playback history.
List<Station> mergeRadioCatalogs(
  List<Station> existing,
  List<Station> additions,
) {
  final result = List<Station>.of(existing);
  final ids = existing.map((s) => s.id).toSet();
  final urls = existing.map((s) => canonicalRadioUrl(s.playbackUrl)).toSet();
  final names = existing.map((s) => normalizedStationName(s.nameAr)).toSet();
  final providerKeys = existing.map(_providerKey).whereType<String>().toSet();
  for (final station in additions) {
    final url = canonicalRadioUrl(station.playbackUrl);
    final name = normalizedStationName(station.nameAr);
    final providerKey = _providerKey(station);
    if (station.id.isEmpty ||
        url.isEmpty ||
        name.isEmpty ||
        Uri.tryParse(station.playbackUrl ?? '')?.scheme != 'https' ||
        ids.contains(station.id) ||
        urls.contains(url) ||
        names.contains(name) ||
        (providerKey != null && providerKeys.contains(providerKey)))
      continue;
    result.add(station);
    ids.add(station.id);
    urls.add(url);
    names.add(name);
    if (providerKey != null) providerKeys.add(providerKey);
  }
  return result;
}

String? _providerKey(Station station) {
  final match = RegExp(
    r'^(?:neon-mp3quran-|mp3quran-radio-)(\d+)$',
  ).firstMatch(station.slug);
  return match == null ? null : 'mp3quran:${match[1]}';
}

class SupplementalRadioApi {
  SupplementalRadioApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl =
          baseUrl ?? const String.fromEnvironment('TARTEEL_CLOUD_BASE_URL');
  final http.Client _client;
  final String _baseUrl;
  bool get enabled => Uri.tryParse(_baseUrl)?.scheme == 'https';

  Future<List<Station>> stations() async {
    if (!enabled) return const [];
    final response = await _client
        .get(
          Uri.parse(
            '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1/radio/stations',
          ),
          headers: const {'accept': 'application/json'},
        )
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200 || response.bodyBytes.length > 1024 * 1024) {
      throw const FormatException('RADIO_CATALOG_UNAVAILABLE');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map ||
        body['data'] is! List ||
        (body['data'] as List).length > 500) {
      throw const FormatException('RADIO_CATALOG_INVALID');
    }
    return (body['data'] as List)
        .map((row) => Station.fromJson(jsonMap(row)))
        .toList();
  }
}
