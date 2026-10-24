import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/learning.dart';
import 'package:tarteel/src/prayer_reminders.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final times = PrayerTimesService();

  test(
    'civil Hijri epoch, leap year and 30-year boundaries are local and deterministic',
    () {
      final epoch = DateTime.utc(622, 7, 19);
      expect(civilHijriForDate(epoch), (year: 1, month: 1, day: 1));
      expect(civilHijriForDate(epoch.add(const Duration(days: 353))), (
        year: 1,
        month: 12,
        day: 29,
      ));
      expect(civilHijriForDate(epoch.add(const Duration(days: 354))), (
        year: 2,
        month: 1,
        day: 1,
      ));
      expect(civilHijriForDate(epoch.add(const Duration(days: 708))), (
        year: 2,
        month: 12,
        day: 30,
      ));
      expect(civilHijriForDate(epoch.add(const Duration(days: 709))), (
        year: 3,
        month: 1,
        day: 1,
      ));
      expect(civilHijriForDate(epoch.add(const Duration(days: 10631))), (
        year: 31,
        month: 1,
        day: 1,
      ));
      expect(civilHijriForDate(DateTime.utc(2025, 3, 1)), (
        year: 1446,
        month: 9,
        day: 1,
      ));
    },
  );

  test(
    'DST spring and autumn calendars contain every local date exactly once',
    () async {
      final settings = PrayerSettings.taiz().copyWith(
        locationName: 'New York',
        latitude: 40.7128,
        longitude: -74.006,
        timezone: 'America/New_York',
        manualTimes: {PrayerKind.fajr: 330},
      );
      for (final start in [
        DateTime.utc(2026, 3, 7),
        DateTime.utc(2026, 10, 31),
      ]) {
        final days = await times.calendar(
          from: start,
          days: 4,
          settings: settings,
        );
        expect(
          days
              .map(
                (day) =>
                    DateTime.utc(day.date.year, day.date.month, day.date.day),
              )
              .toSet(),
          hasLength(4),
        );
        for (var i = 0; i < days.length; i++) {
          expect(
            days[i].date.day,
            DateTime.utc(start.year, start.month, start.day + i).day,
          );
          expect(days[i].timeFor(PrayerKind.fajr).hour, 5);
          expect(days[i].timeFor(PrayerKind.fajr).minute, 30);
        }
        final difference = days[1]
            .timeFor(PrayerKind.fajr)
            .difference(days[0].timeFor(PrayerKind.fajr));
        expect(difference.inHours, start.month == 3 ? 23 : 25);
      }
    },
  );

  test(
    'reminder date IDs use civil date, not timezone-offset elapsed days',
    () async {
      await times.initialize();
      final location = tz.getLocation('Asia/Aden');
      final zoned = tz.TZDateTime(location, 2026, 1, 15);
      expect(
        PrayerReminderIds.forPrayerOnDate(PrayerKind.fajr, zoned),
        PrayerReminderIds.forPrayerOnDate(
          PrayerKind.fajr,
          DateTime.utc(2026, 1, 15),
        ),
      );
      final all = <int>{};
      for (var day = 0; day < 366; day++) {
        for (final prayer in PrayerKind.values.where(
          (p) => p.isRequiredPrayer,
        )) {
          final date = DateTime.utc(2026, 1, 1 + day);
          all.addAll([
            PrayerReminderIds.forPrayerOnDate(prayer, date),
            PrayerReminderIds.before(prayer, date),
            PrayerReminderIds.after(prayer, date),
          ]);
        }
      }
      expect(all, hasLength(366 * 5 * 3));
      for (final id in AdhkarReminderController.ids.values) {
        expect(all.contains(id), isFalse);
      }
    },
  );

  test(
    'legacy settings migrate without losing reminders, offsets or unrelated favorites',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites:v1': 'preserved',
        'settings:prayer:v1':
            '{"location_name":"تعز","latitude":13.5795,"longitude":44.0209,"timezone":"Asia/Aden","reminders_enabled":true,"offsets":{"fajr":-5}}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = PrayerSettingsStore(prefs)..load();
      expect(
        store.value.reminderModeFor(PrayerKind.fajr),
        PrayerReminderMode.notificationOnly,
      );
      await store.setReminderMinutes(PrayerKind.fajr, before: 12, after: 20);
      await store.setPrayerAudio(PrayerKind.fajr, '/private/fajr.ogg');
      await store.setPrayerVolume(PrayerKind.fajr, .4);
      final restored = PrayerSettingsStore(prefs)..load();
      expect(restored.value.beforeMinutesFor(PrayerKind.fajr), 12);
      expect(restored.value.afterMinutesFor(PrayerKind.fajr), 20);
      expect(restored.value.offsetFor(PrayerKind.fajr), -5);
      expect(restored.value.audioPathFor(PrayerKind.fajr), '/private/fajr.ogg');
      expect(restored.value.volumeFor(PrayerKind.fajr), .4);
      expect(prefs.getString('favorites:v1'), 'preserved');
    },
  );

  test(
    'before and after reminders use prayer-relative time, remain bounded and cancel cleanly',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrayerSettingsStore(await SharedPreferences.getInstance())
        ..load();
      await store.setReminderMode(
        PrayerKind.fajr,
        PrayerReminderMode.shortAlert,
      );
      await store.setReminderMinutes(PrayerKind.fajr, before: 15, after: 20);
      await store.setPrayerVolume(PrayerKind.fajr, .5);
      final gateway = _Gateway();
      final controller = PrayerReminderController(
        notifications: LocalNotificationService(gateway: gateway),
        prayerTimes: times,
        settings: store,
        clock: () => DateTime.utc(2026, 1, 15),
      );
      await controller.reconcile();
      expect(
        gateway.pending,
        hasLength(PrayerReminderController.extendedScheduleDays * 3),
      );
      final day = DateTime.utc(2026, 1, 15);
      final main = gateway
          .pending[PrayerReminderIds.forPrayerOnDate(PrayerKind.fajr, day)]!;
      expect(main.audioPath, 'assets/audio/reminder.wav');
      expect(main.volume, .5);
      expect(
        gateway
            .pending[PrayerReminderIds.before(PrayerKind.fajr, day)]!
            .scheduledAt
            .difference(main.scheduledAt),
        const Duration(minutes: -15),
      );
      expect(
        gateway
            .pending[PrayerReminderIds.after(PrayerKind.fajr, day)]!
            .scheduledAt
            .difference(main.scheduledAt),
        const Duration(minutes: 20),
      );
      final ids = gateway.pending.keys.toSet();
      await controller.reconcile();
      expect(gateway.pending.keys.toSet(), ids);
      await controller.setEnabled(false);
      expect(gateway.pending, isEmpty);
      controller.dispose();
    },
  );

  test(
    'existing adhkar reminder engine retains IDs and timezone at DST boundary',
    () async {
      await times.initialize();
      SharedPreferences.setMockInitialValues({});
      final store = LearningStore(await SharedPreferences.getInstance())
        ..load();
      await store.setReminderMode('morning', AdhkarReminderMode.tone);
      final gateway = _Gateway();
      final controller = AdhkarReminderController(
        notifications: LocalNotificationService(gateway: gateway),
        store: store,
        timezone: () => 'America/New_York',
      );
      await controller.schedule(
        'morning',
        hour: 7,
        minute: 0,
        now: DateTime.utc(2026, 3, 7, 13),
      );
      expect(gateway.pending, hasLength(1));
      final request = gateway.pending[AdhkarReminderController.ids['morning']]!;
      final local = tz.TZDateTime.from(
        request.scheduledAt,
        tz.getLocation(request.timezone),
      );
      expect(local.day, 8);
      expect(local.hour, 7);
      expect(request.audioPath, 'assets/audio/reminder.wav');
      expect(request.repeatDaily, isTrue);
      await controller.cancel('morning');
      expect(gateway.pending, isEmpty);
    },
  );

  test(
    'all supported calculation methods produce finite ordered Yemen times',
    () async {
      for (final method in PrayerCalculationMethod.values) {
        final settings = PrayerSettings.taiz().copyWith(
          calculationMethod: method,
        );
        final day = await times.dayFor(
          date: DateTime(2026, 10, 23),
          settings: settings,
        );
        expect(day.timeFor(PrayerKind.fajr).hour, inInclusiveRange(4, 6));
        expect(day.timeFor(PrayerKind.maghrib).hour, inInclusiveRange(17, 19));
        expect(day.requiredPrayers.first.prayer, PrayerKind.fajr);
        expect(day.requiredPrayers.last.prayer, PrayerKind.isha);
      }
    },
  );
}

class _Gateway implements LocalNotificationGateway {
  final pending = <int, LocalNotificationRequest>{};
  @override
  Future<String?> initialize(void Function(String) onTap) async => null;
  @override
  Future<bool> permissionGranted() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> openSystemSettings() async => true;
  @override
  Future<bool> exactSchedulingAvailable() async => true;
  @override
  Future<bool> requestExactSchedulingPermission() async => true;
  @override
  Future<bool> remoteChannelExists() async => true;
  @override
  Future<bool> remoteChannelEnabled() async => true;
  @override
  Future<void> show(LocalNotificationRequest request) async {}
  @override
  Future<void> schedule(
    LocalNotificationRequest request, {
    required bool exact,
  }) async {
    pending[request.id] = request;
  }

  @override
  Future<void> cancel(int id) async {
    pending.remove(id);
  }
}
