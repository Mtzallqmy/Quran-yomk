import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/prayer_reminders.dart';
import 'package:tarteel/src/prayer_settings.dart';
import 'package:tarteel/src/prayer_times.dart';

void main() {
  test('local notification schedule, reschedule and cancel are bounded', () async {
    final gateway = _FakeGateway();
    final service = LocalNotificationService(gateway: gateway);
    final request = LocalNotificationRequest(
      id: 99,
      title: 'ترتيل',
      body: 'اختبار',
      scheduledAt: DateTime.utc(2026, 1, 15, 12),
      timezone: 'Asia/Aden',
      payload: '/prayer-times',
    );

    await service.schedule(request);
    await service.reschedule(
      LocalNotificationRequest(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledAt: request.scheduledAt.add(const Duration(minutes: 5)),
        timezone: request.timezone,
        payload: request.payload,
      ),
    );
    expect(gateway.pending, hasLength(1));
    expect(gateway.cancelled.where((id) => id == 99), hasLength(2));
    await service.cancel(99);
    expect(gateway.pending, isEmpty);
  });

  test('prayer reminders use stable IDs and disable cancels all', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final settings = PrayerSettingsStore(preferences)..load();
    final gateway = _FakeGateway();
    final controller = PrayerReminderController(
      notifications: LocalNotificationService(gateway: gateway),
      prayerTimes: PrayerTimesService(),
      settings: settings,
      clock: () => DateTime.utc(2026, 1, 15),
    );
    await controller.start();
    expect(gateway.pending, isEmpty);

    expect(await controller.setEnabled(true), isTrue);
    expect(gateway.pending.keys.toSet(), PrayerReminderIds.all.toSet());
    expect(gateway.pending, hasLength(5));
    final maghrib = gateway.pending[PrayerReminderIds.maghrib]!;

    await settings.setOffset(PrayerKind.maghrib, 10);
    await controller.reconcile();
    expect(gateway.pending, hasLength(5));
    expect(
      gateway.pending[PrayerReminderIds.maghrib]!.scheduledAt.difference(
        maghrib.scheduledAt,
      ),
      const Duration(minutes: 10),
    );

    await controller.setEnabled(false);
    expect(gateway.pending, isEmpty);
    controller.dispose();
  });

  test('passed prayers are scheduled for the following Taiz day', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final settings = PrayerSettingsStore(preferences)..load();
    await settings.setRemindersEnabled(true);
    final gateway = _FakeGateway();
    final controller = PrayerReminderController(
      notifications: LocalNotificationService(gateway: gateway),
      prayerTimes: PrayerTimesService(),
      settings: settings,
      clock: () => DateTime.utc(2026, 1, 15, 21),
    );

    await controller.start();
    expect(gateway.pending, hasLength(5));
    expect(
      gateway.pending.values.every((request) => request.scheduledAt.day == 16),
      isTrue,
    );
    controller.dispose();
  });

  test('denied permission keeps reminders disabled without scheduling', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final settings = PrayerSettingsStore(preferences)..load();
    final gateway = _FakeGateway(permission: false);
    final controller = PrayerReminderController(
      notifications: LocalNotificationService(gateway: gateway),
      prayerTimes: PrayerTimesService(),
      settings: settings,
    );

    expect(await controller.setEnabled(true), isFalse);
    expect(settings.value.remindersEnabled, isFalse);
    expect(gateway.pending, isEmpty);
    controller.dispose();
  });

  test('prayer settings persist locally and malformed data fails closed', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final settings = PrayerSettingsStore(preferences)..load();
    await settings.setOffset(PrayerKind.fajr, -5);
    await settings.setRemindersEnabled(true);

    final reloaded = PrayerSettingsStore(preferences)..load();
    expect(reloaded.value.locationName, 'تعز');
    expect(reloaded.value.timezone, 'Asia/Aden');
    expect(reloaded.value.offsetFor(PrayerKind.fajr), -5);
    expect(reloaded.value.remindersEnabled, isTrue);

    await preferences.setString('settings:prayer:v1', '{broken');
    final recovered = PrayerSettingsStore(preferences)..load();
    expect(recovered.value.locationName, 'تعز');
    expect(recovered.value.remindersEnabled, isFalse);
  });

  test('Android manifest schedules without exact alarm permission', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(manifest, contains('ScheduledNotificationReceiver'));
    expect(manifest, contains('ScheduledNotificationBootReceiver'));
    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(manifest, isNot(contains('USE_EXACT_ALARM')));
  });
}

class _FakeGateway implements LocalNotificationGateway {
  _FakeGateway({this.permission = true});

  final bool permission;
  final Map<int, LocalNotificationRequest> pending =
      <int, LocalNotificationRequest>{};
  final List<int> cancelled = <int>[];

  @override
  Future<String?> initialize(void Function(String payload) onTap) async => null;

  @override
  Future<bool> permissionGranted() async => permission;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> show(LocalNotificationRequest request) async {}

  @override
  Future<void> schedule(LocalNotificationRequest request) async {
    pending[request.id] = request;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    pending.remove(id);
  }
}
