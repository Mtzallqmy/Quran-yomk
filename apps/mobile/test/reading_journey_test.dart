import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/app.dart';
import 'package:tarteel/src/reading_journey.dart';
import 'package:tarteel/src/services.dart';

import 'ui_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent taps cannot write stale copies; daily goal survives restart',
    () async {
      SharedPreferences.setMockInitialValues({'mushaf:bookmarks:v1': '[]'});
      final preferences = await SharedPreferences.getInstance();
      var now = DateTime(2026, 11, 18);
      final journey = ReadingJourneyStore(preferences, clock: () => now);

      expect(
        await Future.wait([journey.togglePage(1), journey.togglePage(2)]),
        [true, false],
      );
      expect(await journey.setDailyGoal(3), isTrue);
      expect(journey.firstUnreadPage, 2);
      expect(journey.pagesReadToday, 1);

      now = DateTime(2026, 11, 19);
      final restored = ReadingJourneyStore(preferences, clock: () => now);
      expect(restored.dailyGoal, 3);
      expect(restored.pagesReadToday, 0);
      expect(restored.hasRead(1), isTrue);
      expect(await restored.togglePage(1), isTrue);
      expect(restored.hasRead(1), isFalse);
      expect(preferences.getString('mushaf:bookmarks:v1'), '[]');
    },
  );

  test('a complete khatmah can be archived once', () async {
    SharedPreferences.setMockInitialValues({
      'mushaf:reading-journey:v1': jsonEncode({
        'pages': {
          for (var p = 1; p <= ReadingJourneyStore.pageCount; p++)
            '$p': '2026-11-18',
        },
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    final journey = ReadingJourneyStore(preferences);
    expect(journey.khatmahComplete, isTrue);
    expect(journey.firstUnreadPage, isNull);
    expect(await journey.startNextKhatmah(), isTrue);
    expect(await journey.startNextKhatmah(), isFalse);
    final restored = ReadingJourneyStore(preferences);
    expect(restored.completedKhatmahs, 1);
    expect(restored.firstUnreadPage, 1);
  });

  test(
    'malformed progress leaves app usable and rejects invalid identities',
    () async {
      SharedPreferences.setMockInitialValues({
        'mushaf:reading-journey:v1': '{',
      });
      final journey = ReadingJourneyStore(
        await SharedPreferences.getInstance(),
      );
      expect(journey.pagesRead, 0);
      expect(() => journey.togglePage(605), throwsRangeError);
      expect(() => journey.setDailyGoal(0), throwsRangeError);
      expect(await journey.startNextKhatmah(), isFalse);
    },
  );
  testWidgets('home opens the journey and reader records a completed page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'tarteel_remote_config:v1': '{"prayer_features_enabled":false}',
    });
    final services = UiServices(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TarteelApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('رحلتي مع القرآن'));
    await tester.pumpAndSettle();
    expect(find.text('0 من 604 صفحة'), findsOneWidget);

    await tester.tap(find.text('تعديل الهدف اليومي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '٣');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('0 من 3 صفحة'), findsOneWidget);

    await tester.tap(find.text('افتح أول صفحة غير مكتملة'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('خيارات المصحف'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إتمام قراءة الصفحة'));
    await tester.pumpAndSettle();
    expect(services.mushaf.journey.hasRead(1), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 من 604 صفحة'), findsOneWidget);
    expect(find.text('1 من 3 صفحة'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
