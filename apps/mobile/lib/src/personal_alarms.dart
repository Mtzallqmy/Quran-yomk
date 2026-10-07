import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'local_notifications.dart';

class PersonalAlarm {
  const PersonalAlarm({required this.id, required this.title, required this.minutes,
    required this.audioPath, this.enabled = true, this.timezone = 'Asia/Aden'});
  final int id;
  final String title;
  final int minutes;
  final String audioPath;
  final bool enabled;
  final String timezone;
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'minutes': minutes,
    'path': audioPath, 'enabled': enabled, 'timezone': timezone};
  factory PersonalAlarm.fromJson(Map<String, dynamic> json) => PersonalAlarm(
    id: json['id'] as int, title: json['title'] as String,
    minutes: json['minutes'] as int, audioPath: json['path'] as String,
    enabled: json['enabled'] == true, timezone: json['timezone'] as String? ?? 'Asia/Aden');
}

class PersonalAlarmStore extends ChangeNotifier {
  PersonalAlarmStore(this.preferences, this.notifications);
  final SharedPreferences preferences;
  final LocalNotificationService notifications;
  final List<PersonalAlarm> _alarms = [];
  List<PersonalAlarm> get alarms => List.unmodifiable(_alarms);
  static const key = 'personal_audio_alarms:v1';
  void load() {
    try {
      final values = jsonDecode(preferences.getString(key) ?? '[]') as List;
      for (final value in values) {
        final alarm = PersonalAlarm.fromJson(Map<String, dynamic>.from(value as Map));
        if (alarm.id >= 8_000_000 && alarm.id < 9_000_000 && alarm.minutes >= 0 && alarm.minutes < 1440) _alarms.add(alarm);
      }
    } catch (_) { /* Keep other saved data intact. */ }
  }
  int get nextId {
    for (var id = 8_000_001; id < 9_000_000; id++) {
      if (!_alarms.any((value) => value.id == id)) return id;
    }
    throw StateError('ALARM_LIMIT');
  }
  Future<void> save(PersonalAlarm alarm, {DateTime? now}) async {
    if (alarm.minutes < 0 || alarm.minutes >= 1440 || alarm.audioPath.isEmpty) throw ArgumentError('INVALID_ALARM');
    await notifications.initialize();
    if (alarm.enabled) {
      if (!await notifications.requestPermission()) throw StateError('NOTIFICATION_PERMISSION_REQUIRED');
      if (!await notifications.exactSchedulingAvailable() && !await notifications.requestExactSchedulingPermission()) {
        throw StateError('EXACT_ALARM_PERMISSION_REQUIRED');
      }
      final location = tz.getLocation(alarm.timezone);
      final current = tz.TZDateTime.from(now ?? DateTime.now(), location);
      var time = tz.TZDateTime(location, current.year, current.month, current.day, alarm.minutes ~/ 60, alarm.minutes % 60);
      if (!time.isAfter(current)) time = tz.TZDateTime(location, current.year, current.month, current.day + 1, alarm.minutes ~/ 60, alarm.minutes % 60);
      await notifications.schedule(LocalNotificationRequest(id: alarm.id, title: alarm.title,
        body: 'المنبه الشخصي', scheduledAt: time, timezone: alarm.timezone,
        payload: '/personal-alarms', audioPath: alarm.audioPath, repeatDaily: true));
    } else { await notifications.cancel(alarm.id); }
    _alarms.removeWhere((value) => value.id == alarm.id); _alarms.add(alarm);
    await _persist(); notifyListeners();
  }
  Future<void> remove(int id) async {
    await notifications.cancel(id); _alarms.removeWhere((value) => value.id == id);
    await _persist(); notifyListeners();
  }
  Future<void> _persist() async { await preferences.setString(key, jsonEncode(_alarms.map((value) => value.toJson()).toList())); }
}
