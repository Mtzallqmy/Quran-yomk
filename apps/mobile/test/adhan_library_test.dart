import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:tarteel/src/native_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/adhan_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'built-in short reminder remains selected without downloaded files',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = AdhanLibraryStore(preferences)..load();
      await store.select('built-in-reminder');
      final reopened = AdhanLibraryStore(preferences)..load();
      expect(reopened.selectedPath, 'assets/audio/reminder.wav');
      expect(reopened.isDownloaded('built-in-reminder'), isTrue);
      expect(
        reopened.availablePaths['built-in-adhan'],
        'assets/audio/adhan.ogg',
      );
    },
  );

  test(
    'successive imports retain older paths used by per-prayer choices',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final directory = await Directory.systemTemp.createTemp('tarteel-adhan-');
      final first = await File('${directory.path}/first.wav').writeAsBytes([1]);
      final second = await File('${directory.path}/second.wav')
          .writeAsBytes([2]);
      var nextPath = first.path;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeAudio.channel, (_) async => nextPath);
      try {
        final preferences = await SharedPreferences.getInstance();
        final store = AdhanLibraryStore(preferences)..load();
        expect(await store.importPhoneAudio(), isTrue);
        final firstId = store.selectedId;
        nextPath = second.path;
        expect(await store.importPhoneAudio(), isTrue);
        expect(store.selectedId, isNot(firstId));
        final reopened = AdhanLibraryStore(preferences)..load();
        expect(reopened.availablePaths[firstId], first.path);
        expect(reopened.selectedPath, second.path);
        expect(await first.exists(), isTrue);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(NativeAudio.channel, null);
        await directory.delete(recursive: true);
      }
    },
  );

  test('catalog exposes only attributed public-domain recordings', () {
    expect(adhanRecordings, isNotEmpty);
    for (final recording in adhanRecordings) {
      expect(recording.sourceUrl, startsWith('https://'));
      expect(recording.licenseUrl, startsWith('https://'));
      expect(recording.licenseLabel, contains('ملكية عامة'));
    }
  });

  test('missing selected file is cleared on load', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'adhan:selected:v1': 'missing',
      'adhan:files:v1': '{"missing":"/tmp/adhan-does-not-exist.ogg"}',
    });
    final store = AdhanLibraryStore(await SharedPreferences.getInstance())
      ..load();
    expect(store.selectedId, isNull);
    expect(store.selectedPath, isNull);
    expect(store.isDownloaded('missing'), isFalse);
    expect(File('/tmp/adhan-does-not-exist.ogg').existsSync(), isFalse);
  });
}
