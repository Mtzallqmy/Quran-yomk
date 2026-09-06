import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';
import 'package:tarteel/src/screens/prayer_times.dart';
import 'package:tarteel/src/theme.dart';

void main() {
  testWidgets('prayer view is RTL-safe and shows next prayer and reminders', (
    tester,
  ) async {
    final settings = PrayerSettings.taiz().copyWith(
      remindersEnabled: true,
      reminderModes: const <PrayerKind, PrayerReminderMode>{
        PrayerKind.maghrib: PrayerReminderMode.adhan,
      },
    );
    final times = <PrayerKind, DateTime>{
      PrayerKind.fajr: DateTime.utc(2026, 1, 15, 2),
      PrayerKind.sunrise: DateTime.utc(2026, 1, 15, 3, 30),
      PrayerKind.dhuhr: DateTime.utc(2026, 1, 15, 9),
      PrayerKind.asr: DateTime.utc(2026, 1, 15, 12, 30),
      PrayerKind.maghrib: DateTime.utc(2026, 1, 15, 15),
      PrayerKind.isha: DateTime.utc(2026, 1, 15, 16, 30),
    };
    final day = PrayerDay(
      date: DateTime.utc(2026, 1, 15),
      timezone: 'Asia/Aden',
      times: times,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: TarteelTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: PrayerTimesView(
                snapshot: PrayerSnapshot(
                  today: day,
                  next: PrayerOccurrence(
                    prayer: PrayerKind.maghrib,
                    time: times[PrayerKind.maghrib]!,
                  ),
                ),
                settings: settings,
                now: DateTime.utc(2026, 1, 15, 14),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('تعز'), findsOneWidget);
    expect(find.text('المغرب'), findsNWidgets(2));
    expect(find.text('التذكير مفعل'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_active_outlined), findsNWidgets(4));
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
