import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/l10n.dart';
import 'package:tarteel/src/screens/quran_study.dart';
import 'ui_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/content_catalog.dart';
import 'package:tarteel/src/playback_progress.dart';
import 'package:tarteel/src/learning.dart';
import 'package:tarteel/src/screens/quran_index.dart';
import 'package:tarteel/src/screens/prayer_reliability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'resume distinguishes editions and ignores completed or short media',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PlaybackProgressStore(
        await SharedPreferences.getInstance(),
      );
      await store.save('reciter-a:edition1', const Duration(seconds: 37));
      expect(
        store.position('reciter-a:edition1', const Duration(minutes: 3)),
        const Duration(seconds: 37),
      );
      expect(store.position('reciter-a:edition2', null), Duration.zero);
      expect(
        store.position('reciter-a:edition1', const Duration(seconds: 38)),
        Duration.zero,
      );
      await store.save(
        'reciter-a:edition1',
        const Duration(minutes: 3),
        completed: true,
      );
      expect(store.position('reciter-a:edition1', null), Duration.zero);
    },
  );
  test('resume storage is bounded and corrupt data does not crash', () async {
    SharedPreferences.setMockInitialValues({
      PlaybackProgressStore.key: 'invalid',
    });
    final store = PlaybackProgressStore(await SharedPreferences.getInstance());
    expect(store.position('x', null), Duration.zero);
    for (var i = 0; i < 82; i++) {
      await store.save('item$i', const Duration(seconds: 10));
    }
    expect(store.position('item0', null), Duration.zero);
    expect(store.position('item81', null), const Duration(seconds: 10));
  });
  test('personal review restores ranges outside bundled thematic samples', () {
    expect(personalReviewSegment('2:255-257')?.id, '2:255-257');
    expect(personalReviewSegment('2:257-255'), null);
    expect(personalReviewSegment('115:1-2'), null);
    expect(personalReviewSegment('wrong'), null);
  });
  test('Quran search ignores diacritics without changing source text', () {
    const original = 'إِنَّا أَعْطَيْنَاكَ';
    expect(normalizeQuranQuery(original), contains(normalizeQuranQuery('انا')));
    expect(original, 'إِنَّا أَعْطَيْنَاكَ');
  });
  test(
    'content outage stays optional and path injection is rejected',
    () async {
      final api = ContentCatalogApi(
        baseUrl: 'https://example.org',
        client: MockClient((_) async => http.Response('{}', 503)),
      );
      await expectLater(api.translations(), throwsFormatException);
      expect(() => api.translation('../secret', 1), throwsFormatException);
      expect(() => api.translation('english_test', 115), throwsFormatException);
      api.dispose();
    },
  );
  test('translation metadata retains provider identity and version', () async {
    final api = ContentCatalogApi(
      baseUrl: 'https://example.org',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'kind': 'translation',
                'edition': '1.1.2',
                'metadata': {
                  'key': 'english_saheeh',
                  'publisher': 'QuranEnc.com',
                },
              },
            ],
          }),
          200,
        ),
      ),
    );
    final values = await api.translations();
    expect(values.single['edition'], '1.1.2');
    expect(
      (values.single['metadata'] as Map<String, dynamic>)['publisher'],
      'QuranEnc.com',
    );
    api.dispose();
  });
  testWidgets(
    'alarm history distinguishes preparation from hearing and corrupt history is safe',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrayerReliabilityDetails(
                status: {
                  'nextAlarmAt': DateTime(
                    2026,
                    10,
                    24,
                    20,
                  ).millisecondsSinceEpoch,
                  'nextAlarmTitle': 'العشاء',
                  'nextAlarmPath': 'user_makkah.mp3',
                  'dndFilter': 1,
                  'eventsJson': jsonEncode([
                    {'at': 1000, 'state': 'AUDIO_READY', 'title': 'تجربة'},
                  ]),
                },
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('التسجيل المضاف'), findsOneWidget);
      await tester.tap(find.text('سجل التنبيهات على هذا الجهاز'));
      await tester.pumpAndSettle();
      expect(find.text('تم تجهيز الصوت (لا يؤكد السماع)'), findsOneWidget);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PrayerReliabilityDetails(status: {'eventsJson': 'corrupt'}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'study opens an arbitrary range without requesting optional translations',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final services = UiServices(await SharedPreferences.getInstance());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [servicesProvider.overrideWithValue(services)],
          child: MaterialApp(
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const QuranStudyPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Surah>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1. الفاتحة').last);
      await tester.pumpAndSettle();
      expect(find.text('ابدأ حفظ المقطع'), findsOneWidget);
      expect(find.text('ترجمات معاني القرآن — QuranEnc'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('ابدأ حفظ المقطع'));
      await tester.tap(find.text('ابدأ حفظ المقطع'));
      await tester.pumpAndSettle();
      expect(find.text('طريقة الحفظ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
