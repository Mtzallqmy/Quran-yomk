import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/quran_download_contract.dart';

void main() {
  const fatihah = Surah(
    id: 1,
    number: 1,
    nameAr: 'الفاتحة',
    nameEn: 'Al-Fatihah',
    ayahCount: 7,
  );

  test(
    'AlQuran Cloud maps editions and resolves surah and ayah CDN URLs',
    () async {
      final provider = AlQuranCloudAudioProvider(
        client: MockClient((request) async {
          if (request.method == 'HEAD') {
            return http.Response(
              '',
              200,
              headers: <String, String>{'content-length': '12345'},
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode(<String, dynamic>{
                'data': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'identifier': 'ar.alafasy',
                    'language': 'ar',
                    'name': 'مشاري العفاسي',
                    'englishName': 'Mishary Alafasy',
                    'format': 'audio',
                    'type': 'versebyverse',
                  },
                ],
              }),
            ),
            200,
            headers: const <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );

      final reciter = (await provider.reciters()).single;
      expect(reciter.provider, QuranAudioProviderKind.alQuranCloud);
      expect(reciter.supportsAyahAudio, isTrue);
      expect(reciter.bitrates, containsAll(<int>[64, 128, 192]));

      final surah = await provider.resolve(
        QuranAudioRequest(surah: fatihah, reciter: reciter, bitrateKbps: 128),
      );
      expect(
        surah?.playbackUri.toString(),
        'https://cdn.islamic.network/quran/audio-surah/128/ar.alafasy/1.mp3',
      );
      expect(surah?.expectedSize, 12345);
      expect(surah?.rehostingAllowed, isFalse);

      final ayah = await provider.resolve(
        QuranAudioRequest(
          surah: fatihah,
          reciter: reciter,
          bitrateKbps: 64,
          ayahGlobalNumber: 1,
          ayahInSurah: 1,
        ),
      );
      expect(
        ayah?.playbackUri.toString(),
        'https://cdn.islamic.network/quran/audio/64/ar.alafasy/1.mp3',
      );
    },
  );

  test('MP3Quran schema is isolated and normalized', () async {
    final provider = Mp3QuranAudioProvider(
      client: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(<String, dynamic>{
              'reciters': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 5,
                  'name': 'أحمد العجمي',
                  'moshaf': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 5,
                      'name': 'حفص عن عاصم',
                      'server': 'https://server.example/ajm/',
                      'surah_list': '1,2,114',
                    },
                  ],
                },
              ],
            }),
          ),
          200,
          headers: const <String, String>{
            'content-type': 'application/json; charset=utf-8',
          },
        ),
      ),
    );

    final reciter = (await provider.reciters(surahNumber: 1)).single;
    expect(reciter.riwayah, 'حفص عن عاصم');
    expect(reciter.availableSurahs, <int>{1, 2, 114});
    final media = await provider.resolve(
      QuranAudioRequest(surah: fatihah, reciter: reciter),
    );
    expect(media?.playbackUri.toString(), 'https://server.example/ajm/001.mp3');
    expect(media?.provider, QuranAudioProviderKind.mp3Quran);
  });

  test(
    'repository uses an integrity-checked local file before remote streaming',
    () async {
      const reciter = QuranAudioCatalogReciter(
        id: 'test:reciter',
        provider: QuranAudioProviderKind.alQuranCloud,
        edition: 'test.edition',
        nameAr: 'قارئ',
        nameEn: 'Reciter',
        availableSurahs: <int>{1},
        bitrates: <int>{128},
      );
      final remote = QuranAudioMedia(
        id: 'remote',
        provider: QuranAudioProviderKind.alQuranCloud,
        reciter: reciter,
        surah: fatihah,
        bitrateKbps: 128,
        playbackUri: Uri.parse('https://cdn.example/1.mp3'),
        downloadUri: Uri.parse('https://cdn.example/1.mp3'),
        rightsStatus: 'APPROVED',
        rehostingAllowed: false,
      );
      final repository = QuranAudioRepository(
        providers: <QuranAudioProvider>[_StaticProvider(remote)],
        localLookup: _LocalLookup(),
      );
      final resolved = await repository.resolve(
        const QuranAudioRequest(surah: fatihah, reciter: reciter),
      );
      expect(resolved.isLocal, isTrue);
      expect(resolved.localPath, '/verified/offline/1.mp3');
      expect(resolved.downloadUri, remote.downloadUri);
    },
  );

  test('explicit reciter never falls through to another provider', () async {
    const selected = QuranAudioCatalogReciter(
      id: 'mp3quran:10:20',
      provider: QuranAudioProviderKind.mp3Quran,
      edition: '10-20',
      nameAr: 'عبدالباسط عبدالصمد',
      nameEn: 'Abdul Basit Abdus Samad',
      availableSurahs: <int>{1},
      bitrates: <int>{},
      serverUrl: 'https://example.invalid/abdulbasit',
    );
    const wrong = QuranAudioCatalogReciter(
      id: 'alquran:ar.alafasy',
      provider: QuranAudioProviderKind.alQuranCloud,
      edition: 'ar.alafasy',
      nameAr: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
      availableSurahs: <int>{1},
      bitrates: <int>{128},
    );
    final wrongMedia = QuranAudioMedia(
      id: 'wrong',
      provider: QuranAudioProviderKind.alQuranCloud,
      reciter: wrong,
      surah: fatihah,
      bitrateKbps: 128,
      playbackUri: Uri.parse('https://cdn.example/wrong.mp3'),
      downloadUri: Uri.parse('https://cdn.example/wrong.mp3'),
      rightsStatus: 'APPROVED',
      rehostingAllowed: false,
    );
    final repository = QuranAudioRepository(
      providers: <QuranAudioProvider>[
        _NullProvider(QuranAudioProviderKind.mp3Quran),
        _StaticProvider(wrongMedia),
      ],
      localLookup: _NullLocalLookup(),
    );

    await expectLater(
      repository.resolve(
        const QuranAudioRequest(surah: fatihah, reciter: selected),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'message',
          contains('QURAN_AUDIO_UNAVAILABLE'),
        ),
      ),
    );
  });

  test('repository rejects a resolved media identity mismatch', () async {
    const selected = QuranAudioCatalogReciter(
      id: 'mp3quran:10:20',
      provider: QuranAudioProviderKind.mp3Quran,
      edition: '10-20',
      nameAr: 'عبدالباسط عبدالصمد',
      nameEn: 'Abdul Basit Abdus Samad',
      availableSurahs: <int>{1},
      bitrates: <int>{},
    );
    const wrong = QuranAudioCatalogReciter(
      id: 'mp3quran:99:88',
      provider: QuranAudioProviderKind.mp3Quran,
      edition: '99-88',
      nameAr: 'إبراهيم الأخضر',
      nameEn: 'Ibrahim Al Akhdar',
      availableSurahs: <int>{1},
      bitrates: <int>{},
    );
    final wrongMedia = QuranAudioMedia(
      id: 'wrong-same-provider',
      provider: QuranAudioProviderKind.mp3Quran,
      reciter: wrong,
      surah: fatihah,
      bitrateKbps: 0,
      playbackUri: Uri.parse('https://cdn.example/wrong.mp3'),
      downloadUri: Uri.parse('https://cdn.example/wrong.mp3'),
      rightsStatus: 'APPROVED',
      rehostingAllowed: false,
    );
    final repository = QuranAudioRepository(
      providers: <QuranAudioProvider>[_KindStaticProvider(wrongMedia)],
      localLookup: _NullLocalLookup(),
    );

    await expectLater(
      repository.resolve(
        const QuranAudioRequest(surah: fatihah, reciter: selected),
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message.toString(),
          'message',
          contains('QURAN_AUDIO_RECITER_MISMATCH'),
        ),
      ),
    );
  });

  test('provider refuses explicit reciter from another provider', () async {
    const selected = QuranAudioCatalogReciter(
      id: 'mp3quran:10:20',
      provider: QuranAudioProviderKind.mp3Quran,
      edition: '10-20',
      nameAr: 'عبدالباسط عبدالصمد',
      nameEn: 'Abdul Basit Abdus Samad',
      availableSurahs: <int>{1},
      bitrates: <int>{},
    );
    final provider = AlQuranCloudAudioProvider(
      client: MockClient((_) async => http.Response('', 500)),
    );
    final media = await provider.resolve(
      const QuranAudioRequest(surah: fatihah, reciter: selected),
    );
    expect(media, isNull);
  });

  test('full Mushaf download requires exactly 114 resolved surahs', () async {
    final service = _DownloadContractFake();
    expect(
      () => service.downloadMushaf(const <QuranAudioMedia>[]),
      throwsArgumentError,
    );
  });
}

class _StaticProvider implements QuranAudioProvider {
  _StaticProvider(this.media);
  final QuranAudioMedia media;
  @override
  QuranAudioProviderKind get kind => QuranAudioProviderKind.alQuranCloud;
  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async =>
      <QuranAudioCatalogReciter>[media.reciter];
  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async => media;
}

class _KindStaticProvider implements QuranAudioProvider {
  _KindStaticProvider(this.media);
  final QuranAudioMedia media;
  @override
  QuranAudioProviderKind get kind => media.provider;
  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async =>
      <QuranAudioCatalogReciter>[media.reciter];
  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async => media;
}

class _NullProvider implements QuranAudioProvider {
  _NullProvider(this.kind);
  @override
  final QuranAudioProviderKind kind;
  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async =>
      const <QuranAudioCatalogReciter>[];
  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async => null;
}

class _LocalLookup implements QuranAudioLocalLookup {
  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async =>
      remote.asLocal(
        '/verified/offline/1.mp3',
        checksum: List<String>.filled(64, 'a').join(),
      );
}

class _NullLocalLookup implements QuranAudioLocalLookup {
  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async => null;
}

class _DownloadContractFake extends QuranDownloadService {
  @override
  bool get supported => true;
  @override
  List<QuranDownloadTask> get tasks => const <QuranDownloadTask>[];
  @override
  Future<void> initialize() async {}
  @override
  Future<QuranDownloadTask> download(QuranAudioMedia media) =>
      throw UnimplementedError();
  @override
  Future<List<QuranDownloadTask>> downloadMany(
    Iterable<QuranAudioMedia> media,
  ) async => <QuranDownloadTask>[];
  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async => null;
  @override
  Future<void> pause(String taskId) async {}
  @override
  Future<void> resume(String taskId) async {}
  @override
  Future<void> cancel(String taskId) async {}
  @override
  Future<void> retry(String taskId) async {}
  @override
  Future<void> delete(String taskId) async {}
}
