import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/quran_playback_store.dart';
import 'package:tarteel/src/quran_playlist_store.dart';

const _surah = Surah(
  id: 1,
  number: 1,
  nameAr: 'الفاتحة',
  nameEn: 'Al-Fatihah',
  ayahCount: 7,
);

QuranAudioCatalogReciter _mp3({
  String reciter = '10',
  String moshaf = '20',
  String? riwayah = 'حفص عن عاصم',
}) => QuranAudioCatalogReciter(
  id: 'mp3quran:$reciter:$moshaf',
  provider: QuranAudioProviderKind.mp3Quran,
  edition: '$reciter-$moshaf',
  nameAr: 'قارئ',
  nameEn: 'Reciter',
  riwayah: riwayah,
  serverUrl: 'https://example.test/audio',
  availableSurahs: const <int>{1},
  bitrates: const <int>{},
);

QuranAudioMedia _media(
  QuranAudioCatalogReciter reciter, {
  Surah surah = _surah,
}) => QuranAudioMedia(
  id: 'media:${reciter.id}:${surah.number}',
  provider: reciter.provider,
  reciter: reciter,
  surah: surah,
  bitrateKbps: 0,
  playbackUri: Uri.parse('https://example.test/001.mp3'),
  downloadUri: Uri.parse('https://example.test/001.mp3'),
  rightsStatus: 'DOCUMENTED_DIRECT_EXTERNAL',
  rehostingAllowed: false,
);

class _StaticProvider implements QuranAudioProvider {
  _StaticProvider(this.kind, this.media);

  @override
  final QuranAudioProviderKind kind;
  final QuranAudioMedia? media;

  @override
  Future<List<QuranAudioCatalogReciter>> reciters({int? surahNumber}) async =>
      media == null
      ? const <QuranAudioCatalogReciter>[]
      : <QuranAudioCatalogReciter>[media!.reciter];

  @override
  Future<QuranAudioMedia?> resolve(QuranAudioRequest request) async => media;
}

class _StaticLocal implements QuranAudioLocalLookup {
  const _StaticLocal(this.value);
  final QuranAudioMedia? value;

  @override
  Future<QuranAudioMedia?> localMedia(QuranAudioMedia remote) async => value;
}

void main() {
  group('canonical reciter identity', () {
    test(
      'MP3Quran identity exposes provider reciter and moshaf without changing stable id',
      () {
        final reciter = _mp3(reciter: '10', moshaf: '20');
        expect(reciter.hasValidIdentity, isTrue);
        expect(reciter.id, 'mp3quran:10:20');
        expect(reciter.providerReciterId, '10');
        expect(reciter.moshafId, '20');
        final identity = reciter.identityFor(surahNumber: 1);
        expect(identity.toJson(), containsPair('provider', 'MP3QURAN'));
        expect(identity.toJson(), containsPair('provider_reciter_id', '10'));
        expect(identity.toJson(), containsPair('moshaf_id', '20'));
        expect(identity.toJson(), containsPair('surah_number', 1));
      },
    );

    test('malformed composite identity fails closed', () {
      const reciter = QuranAudioCatalogReciter(
        id: 'mp3quran:10:99',
        provider: QuranAudioProviderKind.mp3Quran,
        edition: '10-20',
        nameAr: 'قارئ',
        nameEn: 'Reciter',
        availableSurahs: <int>{1},
        bitrates: <int>{},
      );
      expect(reciter.hasValidIdentity, isFalse);
    });

    test('riwayah mismatch is not the same selected identity', () {
      final requested = _mp3(riwayah: 'حفص عن عاصم');
      final different = _mp3(riwayah: 'رواية أخرى');
      expect(requested.sameIdentity(different), isFalse);
      expect(requested.identityKey, isNot(different.identityKey));
    });

    test('track storage identity separates reciters and surahs', () {
      final first = _media(_mp3(reciter: '10', moshaf: '20'));
      final otherReciter = _media(_mp3(reciter: '11', moshaf: '21'));
      const secondSurah = Surah(
        id: 2,
        number: 2,
        nameAr: 'البقرة',
        nameEn: 'Al-Baqarah',
        ayahCount: 286,
      );
      final otherSurah = _media(
        _mp3(reciter: '10', moshaf: '20'),
        surah: secondSurah,
      );
      expect(first.storageKey, isNot(otherReciter.storageKey));
      expect(first.storageKey, isNot(otherSurah.storageKey));
    });
  });

  group('resolver identity enforcement', () {
    test('wrong returned surah is rejected for an explicit reciter', () async {
      final reciter = _mp3();
      const wrongSurah = Surah(
        id: 2,
        number: 2,
        nameAr: 'البقرة',
        nameEn: 'Al-Baqarah',
        ayahCount: 286,
      );
      final repository = QuranAudioRepository(
        providers: <QuranAudioProvider>[
          _StaticProvider(
            QuranAudioProviderKind.mp3Quran,
            _media(reciter, surah: wrongSurah),
          ),
        ],
        localLookup: const _StaticLocal(null),
      );
      await expectLater(
        repository.resolve(QuranAudioRequest(surah: _surah, reciter: reciter)),
        throwsA(
          predicate(
            (error) => '$error'.contains('QURAN_AUDIO_TRACK_IDENTITY_MISMATCH'),
          ),
        ),
      );
    });

    test(
      'wrong local cached reciter is rejected instead of replacing remote',
      () async {
        final requested = _mp3(reciter: '10', moshaf: '20');
        final remote = _media(requested);
        final wrongLocal = _media(
          _mp3(reciter: '11', moshaf: '21'),
        ).asLocal('/tmp/wrong.mp3');
        final repository = QuranAudioRepository(
          providers: <QuranAudioProvider>[
            _StaticProvider(QuranAudioProviderKind.mp3Quran, remote),
          ],
          localLookup: _StaticLocal(wrongLocal),
        );
        await expectLater(
          repository.resolve(
            QuranAudioRequest(surah: _surah, reciter: requested),
          ),
          throwsA(
            predicate(
              (error) =>
                  '$error'.contains('QURAN_AUDIO_LOCAL_IDENTITY_MISMATCH'),
            ),
          ),
        );
      },
    );
  });

  group('persisted identity fail closed', () {
    test('playlist never coerces an unknown provider to MP3Quran', () {
      final json = <String, dynamic>{
        'id': 'entry',
        'bitrate_kbps': 0,
        'surah': _surah.toJson(),
        'reciter': <String, dynamic>{
          'id': 'mystery:10:20',
          'provider': 'mysteryProvider',
          'edition': '10-20',
          'name_ar': 'قارئ',
          'name_en': 'Reciter',
          'available_surahs': <int>[1],
          'bitrates': <int>[],
        },
      };
      expect(
        () => QuranPlaylistEntry.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('valid legacy playlist record remains readable', () {
      final reciter = _mp3();
      final original = QuranPlaylistEntry(
        id: 'legacy-id-format-is-preserved',
        reciter: reciter,
        surah: _surah,
        bitrateKbps: 0,
      );
      final restored = QuranPlaylistEntry.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.reciter.sameIdentity(reciter), isTrue);
      expect(restored.surah.number, 1);
    });

    test('recent playback rejects an unknown provider', () {
      expect(
        () => QuranPlaybackSnapshot.fromJson(<String, dynamic>{
          'provider': 'unknown',
          'reciter_id': 'mp3quran:10:20',
          'edition': '10-20',
          'reciter_name': 'Reciter',
          'bitrate_kbps': 0,
          'surah_number': 1,
          'position_ms': 0,
          'played_at': '2026-09-02T00:00:00.000Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('valid recent playback identity remains readable', () {
      final restored = QuranPlaybackSnapshot.fromJson(<String, dynamic>{
        'provider': QuranAudioProviderKind.mp3Quran.name,
        'reciter_id': 'mp3quran:10:20',
        'edition': '10-20',
        'reciter_name': 'Reciter',
        'riwayah': 'حفص عن عاصم',
        'bitrate_kbps': 0,
        'surah_number': 1,
        'position_ms': 1500,
        'played_at': '2026-09-02T00:00:00.000Z',
      });
      expect(restored.hasValidIdentity, isTrue);
      expect(restored.surahNumber, 1);
      expect(restored.position, const Duration(milliseconds: 1500));
    });
  });
}
