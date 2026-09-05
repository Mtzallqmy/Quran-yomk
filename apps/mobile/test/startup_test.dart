import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/src/offline_clip_service.dart';
import '../lib/src/quran_download_service.dart';
import '../lib/src/startup.dart';

void main() {
  testWidgets('optional work cannot hold the first frame', (tester) async {
    final blocked = Completer<void>();
    var started = false;
    var independent = false;
    initializeAfterFirstFrame(<String, Future<void> Function()>{
      'slow': () {
        started = true;
        return blocked.future;
      },
      'failure': () => throw StateError('private-provider-error'),
      'independent': () async {
        independent = true;
      },
    });
    expect(started, isFalse);
    await tester.pumpWidget(const SizedBox(key: ValueKey('first-frame')));
    expect(find.byKey(const ValueKey('first-frame')), findsOneWidget);
    expect(started, isTrue);
    expect(independent, isTrue);
    expect(tester.takeException(), isNull);
    blocked.complete();
    await tester.pump();
  });

  test('early offline operations share initialization', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final clips = createOfflineClipService(preferences);
    final downloads = createQuranDownloadService(preferences);
    final clipLoad = clips.initialize();
    final downloadLoad = downloads.initialize();
    expect(identical(clipLoad, clips.initialize()), isTrue);
    expect(identical(downloadLoad, downloads.initialize()), isTrue);
    await Future.wait<void>(<Future<void>>[
      clipLoad,
      downloadLoad,
      clips.delete('missing'),
      downloads.delete('missing'),
    ]);
    expect(clips.clips, isEmpty);
    expect(downloads.tasks, isEmpty);
  });

  test('main waits only for audio and preferences', () {
    final source = File('lib/main.dart').readAsStringSync();
    final criticalPath = source.split('  runApp(').first;
    expect(criticalPath, contains('await AudioService.init('));
    expect(criticalPath, contains('await SharedPreferences.getInstance()'));
    for (final optional in <String>[
      'mushafPages',
      'islamicContent',
      'offlineClips',
      'quranDownloads',
      'remoteConfig',
    ]) {
      expect(criticalPath, isNot(contains('await $optional.')));
    }
  });
}
