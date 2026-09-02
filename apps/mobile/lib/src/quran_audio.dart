import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

enum QuranAudioProviderKind { alQuranCloud, mp3Quran }

QuranAudioProviderKind? quranAudioProviderFromPersistedName(String? value) {
  if (value == null || value.isEmpty) return null;
  for (final provider in QuranAudioProviderKind.values) {
    if (provider.name == value) return provider;
  }
  return null;
}

bool validQuranReciterIdentityFields({
  required QuranAudioProviderKind provider,
  required String reciterId,
  required String edition,
}) {
  if (reciterId.isEmpty || edition.isEmpty) return false;
  switch (provider) {
    case QuranAudioProviderKind.alQuranCloud:
      return reciterId == 'alquran:$edition';
    case QuranAudioProviderKind.mp3Quran:
      final match = RegExp(
        r'^mp3quran:([1-9][0-9]*):([1-9][0-9]*)$',
      ).firstMatch(reciterId);
      return match != null && edition == '${match.group(1)}-${match.group(2)}';
  }
}

String _identityPart(Object? value) => Uri.encodeComponent('${value ?? ''}');

class QuranAudioIdentityV1 {
  const QuranAudioIdentityV1({
    required this.provider,
    required this.providerReciterId,
    required this.edition,
    required this.surahNumber,
    this.moshafId,
    this.riwayah,
    this.ayahNumber,
  });

  final QuranAudioProviderKind provider;
  final String providerReciterId;
  final String edition;
  final String? moshafId;
  final String? riwayah;
  final int surahNumber;
  final int? ayahNumber;

  String get providerWire => switch (provider) {
    QuranAudioProviderKind.alQuranCloud => 'ALQURAN_CLOUD',
    QuranAudioProviderKind.mp3Quran => 'MP3QURAN',
  };

  String get key => <Object?>[
    'v1',
    providerWire,
    providerReciterId,
    edition,
    moshafId,
    riwayah,
    surahNumber,
    ayahNumber,
  ].map(_identityPart).join('|');

  Map<String, dynamic> toJson() => <String, dynamic>{
    'schema_version': 1,
    'provider': providerWire,
    'provider_reciter_id': providerReciterId,
    'edition': edition,
    'moshaf_id': moshafId,
    'riwayah': riwayah,
    'surah_number': surahNumber,
    'ayah_number': ayahNumber,
  };
}

class QuranAudioCatalogReciter {
  const QuranAudioCatalogReciter({
    required this.id,
    required this.provider,
    required this.edition,
    required this.nameAr,
    required this.nameEn,
    required this.availableSurahs,
    required this.bitrates,
    this.riwayah,
    this.serverUrl,
    this.supportsAyahAudio = false,
  });

  final String id;
  final QuranAudioProviderKind provider;
  final String edition;
  final String nameAr;
  final String nameEn;
  final String? riwayah;
  final String? serverUrl;
  final Set<int> availableSurahs;
  final Set<int> bitrates;
  final bool supportsAyahAudio;

  bool get hasValidIdentity => validQuranReciterIdentityFields(
    provider: provider,
    reciterId: id,
    edition: edition,
  );

  String get providerReciterId {
    switch (provider) {
      case QuranAudioProviderKind.alQuranCloud:
        return edition;
      case QuranAudioProviderKind.mp3Quran:
        return RegExp(r'^mp3quran:([1-9][0-9]*):[1-9][0-9]*$')
                .firstMatch(id)
                ?.group(1) ??
            '';
    }
  }

  String? get moshafId {
    if (provider != QuranAudioProviderKind.mp3Quran) return null;
    return RegExp(r'^mp3quran:[1-9][0-9]*:([1-9][0-9]*)$')
        .firstMatch(id)
        ?.group(1);
  }

  String get identityKey => <Object?>[
    'v1',
    provider.name,
    providerReciterId,
    edition,
    moshafId,
    riwayah,
  ].map(_identityPart).join('|');

  bool sameIdentity(QuranAudioCatalogReciter other) =>
      hasValidIdentity && other.hasValidIdentity && identityKey == other.identityKey;

  QuranAudioIdentityV1 identityFor({
    required int surahNumber,
    int? ayahNumber,
  }) => QuranAudioIdentityV1(
    provider: provider,
    providerReciterId: providerReciterId,
    edition: edition,
    moshafId: moshafId,
    riwayah: riwayah,
    surahNumber: surahNumber,
    ayahNumber: ayahNumber,
  );

  Reciter toReciter() => Reciter(
    id: id,
    slug: id.replaceAll(':', '-'),
    nameAr: nameAr,
    nameEn: nameEn,
    rewaya: riwayah,
  );
}

class QuranAudioRequest {
  const QuranAudioRequest({
    required this.surah,
    this.reciter,
    this.bitrateKbps = 128,
    this.ayahGlobalNumber,
    this.ayahInSurah,
  });

  final Surah surah;
  final QuranAudioCatalogReciter? reciter;
  final int bitrateKbps;
  final int? ayahGlobalNumber;
  final int? ayahInSurah;

  bool get isAyah => ayahGlobalNumber != null;
}

class QuranAudioMedia {
  const QuranAudioMedia({
    required this.id,
    required this.provider,
    required this.reciter,
    required this.surah,
    required this.bitrateKbps,
    required this.playbackUri,
    required this.downloadUri,
    required this.rightsStatus,
    required this.rehostingAllowed,
    this.ayahGlobalNumber,
    this.ayahInSurah,
    this.expectedSize,
    this.checksumSha256,
    this.localPath,
  });

  final String id;
  final QuranAudioProviderKind provider;
  final QuranAudioCatalogReciter reciter;
  final Surah surah;
  final int bitrateKbps;
  final int? ayahGlobalNumber;
  final int? ayahInSurah;
  final Uri playbackUri;
  final Uri downloadUri;
  final int? expectedSize;
  final String? checksumSha256;
  final String? localPath;
  final bool rehostingAllowed;
  final String rightsStatus;

  bool get isLocal => localPath != null;

  bool get hasValidIdentity =>
      id.isNotEmpty &&
      provider == reciter.provider &&
      reciter.hasValidIdentity &&
      surah.number >= 1 &&
      surah.number <= 114 &&
      (ayahGlobalNumber == null ||
          (ayahGlobalNumber! >= 1 && ayahGlobalNumber! <= 6236)) &&
      (ayahInSurah == null ||
          (ayahInSurah! >= 1 && ayahInSurah! <= surah.ayahCount));

  QuranAudioIdentityV1 get identity => reciter.identityFor(
    surahNumber: surah.number,
    ayahNumber: ayahInSurah,
  );

  String get storageKey => <Object?>[
    identity.key,
    bitrateKbps,
    ayahGlobalNumber ?? 0,
  ].map(_identityPart).join('|');

  bool sameTrackIdentity(QuranAudioMedia other) =>
      hasValidIdentity && other.hasValidIdentity && storageKey == other.storageKey;

  QuranAudioMedia asLocal(String path, {String? checksum, int? size}) =>
      QuranAudioMedia(
        id: id,
        provider: provider,
        reciter: reciter,
        surah: surah,
        bitrateKbps: bitrateKbps,
        ayahGlobalNumber: ayahGlobalNumber,
        ayahInSurah: ayahInSurah,
        playbackUri: Uri.file(path),
        downloadUri: downloadUri,
        expectedSize: size ?? expectedSize,
        checksumSha256: checksum ?? checksumSha256,
        localPath: path,
        rehostingAllowed: rehostingAllowed,
        rightsStatus: rightsStatus,
      );
}

abstract class QuranAudioProvider {
  QuranAudioProviderKind get kind;
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber});
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request);
}

abstract class QuranAudioLocalLookup {
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote);
}

class QuranAudioRepository {
  QuranAudioRepository({
    required List<QuranAudioProvider> providers,
    required this.localLookup,
  }) : _providers = List<QuranAudioProvider>.unmodifiable(providers);

  final List<QuranAudioProvider> _providers;
  final QuranAudioLocalLookup localLookup;
  final Map<String, List<QuranAudioCatalogReciter>> _catalogCache =
      <String, List<QuranAudioCatalogReciter>>{};

  Future<List<QuranAudioCatalogReciter>> reciters({
    int? surahNumber,
    bool refresh = false,
  }) async {
    final key = '${surahNumber ?? 0}';
    final cached = _catalogCache[key];
    if (!refresh && cached != null) return cached;
    final settled = await Future.wait(
      _providers.map(
        (provider) => provider
            .reciters(surahNumber: surahNumber)
            .catchError((_) => <QuranAudioCatalogReciter>[]),
      ),
    );
    final values = settled
        .expand((rows) => rows)
        .where((reciter) => reciter.hasValidIdentity)
        .toList(growable: false);
    _catalogCache[key] = values;
    return values;
  }

  Future<QuranAudioMedia> resolve(QuranAudioRequest request) async {
    if (request.surah.number < 1 || request.surah.number > 114) {
      throw StateError('QURAN_AUDIO_SURAH_IDENTITY_INVALID');
    }
    final explicitReciter = request.reciter;
    if (explicitReciter != null && !explicitReciter.hasValidIdentity) {
      throw StateError('QURAN_AUDIO_RECITER_IDENTITY_INVALID');
    }
    final ordered = explicitReciter == null
        ? _providers
        : _providers
              .where((provider) => provider.kind == explicitReciter.provider)
              .toList(growable: false);
    if (ordered.isEmpty) {
      throw StateError('QURAN_AUDIO_PROVIDER_UNAVAILABLE');
    }

    Object? lastError;
    for (final provider in ordered) {
      try {
        final remote = await provider.resolve(request);
        if (remote == null) continue;
        if (!remote.hasValidIdentity ||
            remote.provider != provider.kind ||
            remote.reciter.provider != provider.kind) {
          throw StateError('QURAN_AUDIO_PROVIDER_IDENTITY_MISMATCH');
        }
        if (remote.surah.number != request.surah.number ||
            remote.ayahGlobalNumber != request.ayahGlobalNumber ||
            remote.ayahInSurah != request.ayahInSurah) {
          throw StateError('QURAN_AUDIO_TRACK_IDENTITY_MISMATCH');
        }
        if (explicitReciter != null &&
            !remote.reciter.sameIdentity(explicitReciter)) {
          throw StateError(
            'QURAN_AUDIO_RECITER_MISMATCH:${explicitReciter.identityKey}:${remote.reciter.identityKey}',
          );
        }
        final local = await localLookup.localMedia(remote);
        if (local == null) return remote;
        if (!local.isLocal || !local.sameTrackIdentity(remote)) {
          throw StateError('QURAN_AUDIO_LOCAL_IDENTITY_MISMATCH');
        }
        return local;
      } catch (error) {
        lastError = error;
      }
    }
    throw StateError('QURAN_AUDIO_UNAVAILABLE: ${lastError ?? 'NO_SOURCE'}');
  }
}

class AlQuranCloudAudioProvider implements QuranAudioProvider {
  AlQuranCloudAudioProvider({http.Client? client})
    : _client = client ?? http.Client();

  static const _api = 'https://api.alquran.cloud/v1';
  static const _cdn = 'https://cdn.islamic.network/quran';
  static const _supportedBitrates = <int>{64, 128, 192};
  final http.Client _client;

  @override
  QuranAudioProviderKind get kind => QuranAudioProviderKind.alQuranCloud;

  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async {
    final response = await _client
        .get(Uri.parse('$_api/edition/format/audio'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('ALQURAN_EDITIONS_HTTP_${response.statusCode}');
    }
    final root = jsonDecode(response.body);
    final rows = root is Map<String, dynamic> && root['data'] is List
        ? root['data'] as List<dynamic>
        : const <dynamic>[];
    return rows
        .whereType<Map<Object?, Object?>>()
        .map((raw) => Map<String, dynamic>.from(raw))
        .where((row) => row['language'] == 'ar')
        .map((row) {
          final edition = row['identifier'] as String? ?? '';
          return QuranAudioCatalogReciter(
            id: 'alquran:$edition',
            provider: kind,
            edition: edition,
            nameAr: row['name'] as String? ?? edition,
            nameEn: row['englishName'] as String? ?? edition,
            riwayah: row['type'] as String?,
            availableSurahs: Set<int>.from(
              List<int>.generate(114, (index) => index + 1),
            ),
            bitrates: _supportedBitrates,
            supportsAyahAudio: row['type'] == 'versebyverse',
          );
        })
        .where((reciter) => reciter.hasValidIdentity)
        .toList(growable: false);
  }

  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async {
    var reciter = request.reciter;
    if (reciter != null && reciter.provider != kind) return null;
    reciter ??= (await reciters(surahNumber: request.surah.number)).firstWhere(
      (value) => value.edition == 'ar.alafasy',
      orElse: () => throw StateError('ALQURAN_DEFAULT_RECITER_MISSING'),
    );
    if (!reciter.hasValidIdentity ||
        !reciter.availableSurahs.contains(request.surah.number)) {
      return null;
    }
    if (request.isAyah && !reciter.supportsAyahAudio) return null;

    final bitrate = _supportedBitrates.contains(request.bitrateKbps)
        ? request.bitrateKbps
        : 128;
    final relative = request.isAyah
        ? 'audio/$bitrate/${reciter.edition}/${request.ayahGlobalNumber}.mp3'
        : 'audio-surah/$bitrate/${reciter.edition}/${request.surah.number}.mp3';
    final uri = Uri.parse('$_cdn/$relative');
    final size = await _probe(uri);
    if (size == null) return null;
    return QuranAudioMedia(
      id: request.isAyah
          ? 'alquran:${reciter.edition}:ayah:${request.ayahGlobalNumber}:$bitrate'
          : 'alquran:${reciter.edition}:surah:${request.surah.number}:$bitrate',
      provider: kind,
      reciter: reciter,
      surah: request.surah,
      bitrateKbps: bitrate,
      ayahGlobalNumber: request.ayahGlobalNumber,
      ayahInSurah: request.ayahInSurah,
      playbackUri: uri,
      downloadUri: uri,
      expectedSize: size,
      rehostingAllowed: false,
      rightsStatus: 'DOCUMENTED_DIRECT_EXTERNAL',
    );
  }

  Future<int?> _probe(Uri uri) async {
    final request = http.Request('HEAD', uri);
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 400) return null;
    final streamedLength = response.contentLength;
    if (streamedLength != null && streamedLength > 0) return streamedLength;
    final declaredLength = int.tryParse(
      response.headers['content-length'] ?? '',
    );
    return declaredLength != null && declaredLength > 0 ? declaredLength : null;
  }
}

class Mp3QuranAudioProvider implements QuranAudioProvider {
  Mp3QuranAudioProvider({http.Client? client})
    : _client = client ?? http.Client();

  static const _api = 'https://www.mp3quran.net/api/v3';
  final http.Client _client;

  @override
  QuranAudioProviderKind get kind => QuranAudioProviderKind.mp3Quran;

  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async {
    final query = <String, String>{'language': 'ar'};
    if (surahNumber != null) query['sura'] = '$surahNumber';
    final uri = Uri.parse('$_api/reciters').replace(queryParameters: query);
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('MP3QURAN_RECITERS_HTTP_${response.statusCode}');
    }
    final root = jsonDecode(response.body);
    final rows = root is Map<String, dynamic> && root['reciters'] is List
        ? root['reciters'] as List<dynamic>
        : const <dynamic>[];
    final result = <QuranAudioCatalogReciter>[];
    for (final rawReciter in rows.whereType<Map<Object?, Object?>>()) {
      final reciter = Map<String, dynamic>.from(rawReciter);
      final reciterId = (reciter['id'] as num?)?.toInt() ?? 0;
      for (final rawMoshaf
          in (reciter['moshaf'] as List<dynamic>? ?? const <dynamic>[])
              .whereType<Map<Object?, Object?>>()) {
        final moshaf = Map<String, dynamic>.from(rawMoshaf);
        final moshafId = (moshaf['id'] as num?)?.toInt() ?? 0;
        final server = moshaf['server'] as String? ?? '';
        final surahs = (moshaf['surah_list'] as String? ?? '')
            .split(',')
            .map(int.tryParse)
            .whereType<int>()
            .where((number) => number >= 1 && number <= 114)
            .toSet();
        if (reciterId == 0 ||
            moshafId == 0 ||
            !server.startsWith('https://') ||
            surahs.isEmpty) {
          continue;
        }
        final value = QuranAudioCatalogReciter(
          id: 'mp3quran:$reciterId:$moshafId',
          provider: kind,
          edition: '$reciterId-$moshafId',
          nameAr: reciter['name'] as String? ?? '',
          nameEn: reciter['name'] as String? ?? '',
          riwayah: moshaf['name'] as String?,
          serverUrl: server,
          availableSurahs: surahs,
          bitrates: const <int>{},
        );
        if (value.hasValidIdentity) result.add(value);
      }
    }
    return result;
  }

  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async {
    if (request.isAyah) return null;
    var reciter = request.reciter;
    if (reciter != null && reciter.provider != kind) return null;
    reciter ??= (await reciters(surahNumber: request.surah.number)).firstOrNull;
    if (reciter == null ||
        !reciter.hasValidIdentity ||
        !reciter.availableSurahs.contains(request.surah.number)) {
      return null;
    }
    final server = reciter.serverUrl?.replaceAll(RegExp(r'/+$'), '');
    if (server == null || server.isEmpty) return null;
    final uri = Uri.parse(
      '$server/${request.surah.number.toString().padLeft(3, '0')}.mp3',
    );
    if (uri.scheme != 'https') return null;
    return QuranAudioMedia(
      id: 'mp3quran:${reciter.edition}:surah:${request.surah.number}',
      provider: kind,
      reciter: reciter,
      surah: request.surah,
      bitrateKbps: 0,
      playbackUri: uri,
      downloadUri: uri,
      rehostingAllowed: false,
      rightsStatus: 'DOCUMENTED_DIRECT_EXTERNAL',
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
