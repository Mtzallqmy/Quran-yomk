import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// A source-neutral model used by the Quran radio UI.
///
/// Keeping this separate from [Station] means a future catalog can replace the
/// current JSON source without changing the player or presentation layer.
class QuranRadioStation {
  const QuranRadioStation({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.status,
    this.nameAr,
    this.description,
    this.country,
    this.language,
    this.genres = const <String>[],
    this.streamFormat,
    this.bitrate,
    this.website,
    this.imageUrl,
    this.frequency,
    this.lastChecked,
  });

  final int id;
  final String name;
  final String? nameAr;
  final String? description;
  final String? country;
  final String? language;
  final List<String> genres;
  final String streamUrl;
  final String? streamFormat;
  final String? bitrate;
  final String? website;
  final String status;
  final String? imageUrl;
  final String? frequency;
  final DateTime? lastChecked;

  String get displayName =>
      nameAr != null && nameAr!.trim().isNotEmpty ? nameAr!.trim() : name;

  Uri? get streamUri => Uri.tryParse(streamUrl);

  bool get usesHttps => streamUri?.scheme.toLowerCase() == 'https';

  bool get isActive => status.toLowerCase() == 'active';

  /// Tarteel disables clear-text network traffic on Android. HTTP entries are
  /// still returned by the source catalog, but are intentionally not playable.
  bool get isPlayable => isActive && usesHttps && streamUrl.isNotEmpty;

  String get playbackId => 'islamic-radio-api-$id';

  factory QuranRadioStation.fromJson(Map<String, dynamic> json) {
    final rawGenres = json['genre'];
    return QuranRadioStation(
      id: _asInt(json['id']),
      name: _asString(json['name'], 'Radio ${json['id'] ?? ''}'),
      nameAr: _nullableString(json['nameAr']),
      description: _nullableString(json['description']),
      country: _nullableString(json['country']),
      language: _nullableString(json['language']),
      genres: rawGenres is List
          ? rawGenres
                .whereType<Object>()
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const <String>[],
      streamUrl: _asString(json['streamUrl']),
      streamFormat: _nullableString(json['streamFormat']),
      bitrate: _nullableString(json['bitrate']),
      website: _nullableString(json['website']),
      status: _asString(json['status'], 'unknown'),
      imageUrl: _nullableString(json['img']),
      frequency: _nullableString(json['frequency']),
      lastChecked: DateTime.tryParse(_asString(json['lastChecked'])),
    );
  }

  /// Adapter to Tarteel's existing audio_service/just_audio playback contract.
  /// The UI never needs to know about this conversion.
  Station toPlaybackStation() => Station(
    id: playbackId,
    slug: playbackId,
    nameAr: displayName,
    nameEn: name == displayName ? null : name,
    description: description,
    logoUrl: imageUrl,
    category: 'QURAN_GENERAL',
    source: 'EXTERNAL',
    streamType: (streamFormat ?? 'stream').toUpperCase(),
    playbackUrl: isPlayable ? streamUrl : null,
    status: status.toUpperCase(),
    healthStatus: isPlayable ? 'HEALTHY' : 'UNAVAILABLE',
    provider: 'UTHUMANY_ISLAMIC_RADIO_API',
    providerName: 'Islamic Radio API',
    integrationBasis: 'stations.json',
    attribution: 'uthumany/islamic-radio-api',
    availabilityStatus: isPlayable ? 'PLAYABLE' : 'UNAVAILABLE',
  );
}

abstract class RadioService {
  Future<List<QuranRadioStation>> fetchStations({bool refresh = false});
  void close();
}

class RadioCatalogException implements Exception {
  const RadioCatalogException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

class IslamicRadioApiService implements RadioService {
  IslamicRadioApiService({
    http.Client? client,
    Uri? catalogUri,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       catalogUri = catalogUri ?? Uri.parse(defaultCatalogUrl);

  /// This is the actual stations.json inside the repository requested for the
  /// integration. It is deliberately isolated here so the source can later be
  /// changed without touching widgets or playback code.
  static const String defaultCatalogUrl =
      'https://raw.githubusercontent.com/uthumany/islamic-radio-api/main/client/public/api/stations.json';

  final http.Client _client;
  final Uri catalogUri;
  final Duration timeout;
  List<QuranRadioStation>? _memoryCache;

  @override
  Future<List<QuranRadioStation>> fetchStations({bool refresh = false}) async {
    if (!refresh && _memoryCache != null) return _memoryCache!;

    http.Response response;
    try {
      response = await _client
          .get(
            catalogUri,
            headers: const <String, String>{
              'accept': 'application/json',
              'user-agent': 'Tarteel-Quran-Radio/1.0',
            },
          )
          .timeout(timeout);
    } on TimeoutException catch (error) {
      throw RadioCatalogException(
        'انتهت مهلة تحميل إذاعات القرآن. تحقق من الاتصال وحاول مجددًا.',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw RadioCatalogException(
        'تعذر الاتصال بمصدر إذاعات القرآن.',
        cause: error,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RadioCatalogException(
        'مصدر إذاعات القرآن أعاد HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        throw const FormatException('Root object is not a JSON map');
      }
      final root = Map<String, dynamic>.from(decoded);
      final rawStations = root['stations'];
      if (rawStations is! List) {
        throw const FormatException('stations is missing');
      }

      final stations =
          rawStations
              .whereType<Map>()
              .map(
                (row) =>
                    QuranRadioStation.fromJson(Map<String, dynamic>.from(row)),
              )
              .where(
                (station) => station.id > 0 && station.streamUrl.isNotEmpty,
              )
              .toList(growable: false)
            ..sort((a, b) {
              final playable = (b.isPlayable ? 1 : 0).compareTo(
                a.isPlayable ? 1 : 0,
              );
              if (playable != 0) return playable;
              return a.displayName.compareTo(b.displayName);
            });

      if (stations.isEmpty) {
        throw const FormatException('No valid stations in catalog');
      }

      _memoryCache = List<QuranRadioStation>.unmodifiable(stations);
      return _memoryCache!;
    } on FormatException catch (error) {
      throw RadioCatalogException(
        'تعذر قراءة stations.json لأن تنسيق البيانات غير صالح.',
        cause: error,
      );
    } on JsonUnsupportedObjectError catch (error) {
      throw RadioCatalogException(
        'تعذر قراءة بيانات إذاعات القرآن.',
        cause: error,
      );
    }
  }

  @override
  void close() => _client.close();
}

String _asString(Object? value, [String fallback = '']) =>
    value is String ? value : (value == null ? fallback : value.toString());

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
