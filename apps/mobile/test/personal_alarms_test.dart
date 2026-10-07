import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:tarteel/src/local_notifications.dart';
import 'package:tarteel/src/personal_alarms.dart';

void main() {
  setUp(() { tz_data.initializeTimeZones(); SharedPreferences.setMockInitialValues({}); });
  test('daily phone alarm schedules tomorrow and survives reload', () async {
    final gateway = _Gateway();
    final prefs = await SharedPreferences.getInstance();
    final store = PersonalAlarmStore(prefs, LocalNotificationService(gateway: gateway));
    final alarm = PersonalAlarm(id: store.nextId, title: 'منبهي', minutes: 360, audioPath: '/private/audio.mp3');
    await store.save(alarm, now: DateTime.utc(2026, 10, 7, 8));
    final request = gateway.pending[alarm.id]!;
    expect(request.scheduledAt.toUtc(), DateTime.utc(2026, 10, 8, 3));
    expect(request.audioPath, '/private/audio.mp3');
    expect(request.repeatDaily, isTrue);
    expect(PersonalAlarmStore(prefs, store.notifications)..load(), isA<PersonalAlarmStore>());
    final restored = PersonalAlarmStore(prefs, store.notifications)..load();
    expect(restored.alarms.single.id, alarm.id);
    await restored.remove(alarm.id);
    expect(gateway.pending, isEmpty);
  });
  test('denied exact alarm permission does not pretend alarm is saved', () async {
    final gateway = _Gateway(exact: false);
    final store = PersonalAlarmStore(await SharedPreferences.getInstance(), LocalNotificationService(gateway: gateway));
    await expectLater(store.save(PersonalAlarm(id: store.nextId, title: 'منبه', minutes: 500, audioPath: '/private/audio.mp3')),
      throwsStateError);
    expect(store.alarms, isEmpty); expect(gateway.pending, isEmpty);
  });
}
class _Gateway implements LocalNotificationGateway {
  _Gateway({this.exact = true});
  final bool exact;
  final pending = <int, LocalNotificationRequest>{};
  @override Future<String?> initialize(void Function(String) onTap) async => null;
  @override Future<bool> permissionGranted() async => true;
  @override Future<bool> requestPermission() async => true;
  @override Future<bool> openSystemSettings() async => true;
  @override Future<bool> exactSchedulingAvailable() async => exact;
  @override Future<bool> requestExactSchedulingPermission() async => exact;
  @override Future<bool> remoteChannelExists() async => true;
  @override Future<bool> remoteChannelEnabled() async => true;
  @override Future<void> show(LocalNotificationRequest request) async {}
  @override Future<void> schedule(LocalNotificationRequest request, {required bool exact}) async { pending[request.id] = request; }
  @override Future<void> cancel(int id) async { pending.remove(id); }
}
