import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/playback.dart';
import 'package:tarteel/src/quran_audio.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/offline_clip_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'actual handler advances local queue and cancels pending study transition on pause',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const codec = StandardMethodCodec();
      String? playerId;
      int loads = 0;
      void event(int state) {
        final id = playerId;
        if (id == null) return;
        messenger.handlePlatformMessage(
          'com.ryanheise.just_audio.events.$id',
          codec.encodeSuccessEnvelope(<String, dynamic>{
            'processingState': state,
            'updateTime': DateTime.now().millisecondsSinceEpoch,
            'updatePosition': 0,
            'bufferedPosition': 60000000,
            'duration': 60000000,
            'currentIndex': 0,
            'androidAudioSessionId': null,
            'icyMetadata': null,
          }),
          (_) {},
        );
      }

      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.audio_session'),
        (call) async => call.method == 'setActive' ? true : null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('com.ryanheise.just_audio.methods'),
        (call) async {
          if (call.method == 'init') {
            playerId =
                (call.arguments as Map<Object?, Object?>)['id'] as String;
            final id = playerId!;
            messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.events.$id'),
              (_) async => null,
            );
            messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.data.$id'),
              (_) async => null,
            );
            messenger.setMockMethodCallHandler(
              MethodChannel('com.ryanheise.just_audio.methods.$id'),
              (call) async {
                if (call.method == 'load') {
                  loads++;
                  scheduleMicrotask(() => event(3));
                  return <String, dynamic>{'duration': 60000000};
                }
                return <String, dynamic>{};
              },
            );
          }
          return <String, dynamic>{};
        },
      );
      OfflineClip clip(String id) => OfflineClip(
        id: id,
        stationId: 'test',
        stationNameAr: 'تجربة $id',
        filePath: '/test/$id.ogg',
        createdAt: DateTime(2026),
        duration: const Duration(minutes: 1),
        sizeBytes: 1000,
        format: 'ogg',
        partial: false,
      );
      final handler = TarteelAudioHandler();
      await handler.playOfflineClip(clip('first'));
      await handler.appendOfflineClip(clip('second'));
      expect(handler.queue.value.length, 2);
      event(4);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(handler.mediaItem.value?.id, 'offline:second');
      expect(loads, 2);
      await handler.selectQueueItem(0);
      handler.setStudyPause(const Duration(seconds: 1));
      event(4);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await handler.pause();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(handler.mediaItem.value?.id, 'offline:first');
      expect(handler.playbackState.value.playing, false);
      const reciter = QuranAudioCatalogReciter(
        id: 'mp3quran:1:1',
        provider: QuranAudioProviderKind.mp3Quran,
        edition: '1',
        nameAr: 'اختبار',
        nameEn: 'test',
        availableSurahs: {1},
        bitrates: {128},
      );
      const surah = Surah(
        id: 1,
        number: 1,
        nameAr: 'الفاتحة',
        nameEn: 'Al-Fatihah',
        ayahCount: 7,
      );
      final media = QuranAudioMedia(
        id: 'test-edition-1',
        provider: QuranAudioProviderKind.mp3Quran,
        reciter: reciter,
        surah: surah,
        bitrateKbps: 128,
        playbackUri: Uri.parse('https://example.org/001.mp3'),
        downloadUri: Uri.parse('https://example.org/001.mp3'),
        rightsStatus: 'test',
        rehostingAllowed: false,
      );
      await handler.playQuranAudio([media], 0);
      await handler.appendOfflineClip(clip('after-surah'));
      event(4);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(handler.mediaItem.value?.id, 'offline:after-surah');
      expect(handler.playbackState.value.queueIndex, 1);
      await handler.stop();
    },
  );
}
