import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'local_notifications.dart';
import 'prayer_settings.dart';

@immutable
class PersonalReminder {
  const PersonalReminder({
    required this.key,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.playSound,
  });

  final String key;
  final bool enabled;
  final int hour;
  final int minute;
  final bool playSound;

  PersonalReminder copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    bool? playSound,
  }) {
    return PersonalReminder(
      key: key,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      playSound: playSound ?? this.playSound,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
        'play_sound': playSound,
      };

  factory PersonalReminder.fromJson(Map<String, dynamic> json) {
    return PersonalReminder(
      key: json['key'] as String,
      enabled: json['enabled'] == true,
      hour: ((json['hour'] as num?)?.toInt() ?? 8).clamp(0, 23).toInt(),
      minute: ((json['minute'] as num?)?.toInt() ?? 0).clamp(0, 59).toInt(),
      playSound: json['play_sound'] != false,
    );
  }
}

class PersonalReminderStore extends ChangeNotifier {
  PersonalReminderStore(this._preferences);

  static const _storageKey = 'local:personal_reminders:v1';
  final SharedPreferences _preferences;
  final Map<String, PersonalReminder> _values = <String, PersonalReminder>{
    'salawat': const PersonalReminder(
      key: 'salawat',
      enabled: false,
      hour: 12,
      minute: 0,
      playSound: true,
    ),
    'daily_wird': const PersonalReminder(
      key: 'daily_wird',
      enabled: false,
      hour: 18,
      minute: 30,
      playSound: true,
    ),
    'daily_quran': const PersonalReminder(
      key: 'daily_quran',
      enabled: false,
      hour: 7,
      minute: 0,
      playSound: true,
    ),
  };

  Iterable<PersonalReminder> get values => _values.values;
  PersonalReminder getByKey(String key) => _values[key]!;

  void load() {
    final raw = _preferences.getString(_storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;
      for (final item in decoded) {
        if (item is! Map) continue;
        final reminder = PersonalReminder.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (_values.containsKey(reminder.key)) {
          _values[reminder.key] = reminder;
        }
      }
    } catch (_) {
      debugPrint('PERSONAL_REMINDER_STORE_INVALID');
    }
  }

  Future<void> update(PersonalReminder reminder) async {
    if (!_values.containsKey(reminder.key)) return;
    _values[reminder.key] = reminder;
    await _persist();
    notifyListeners();
  }

  Future<void> setEnabled(String key, bool enabled) {
    return update(getByKey(key).copyWith(enabled: enabled));
  }

  Future<void> setTime(String key, TimeOfDay time) {
    return update(
      getByKey(key).copyWith(hour: time.hour, minute: time.minute),
    );
  }

  Future<void> setSound(String key, bool playSound) {
    return update(getByKey(key).copyWith(playSound: playSound));
  }

  Future<void> _persist() {
    return _preferences.setString(
      _storageKey,
      jsonEncode(_values.values.map((value) => value.toJson()).toList()),
    );
  }
}

class _ReminderContent {
  const _ReminderContent(this.title, this.body, this.route);

  final String title;
  final String body;
  final String route;
}

class PersonalReminderController {
  PersonalReminderController({
    required this.notifications,
    required this.store,
    required this.prayerSettings,
  });

  final LocalNotificationService notifications;
  final PersonalReminderStore store;
  final PrayerSettingsStore prayerSettings;
  bool _started = false;

  static const _ids = <String, int>{
    'salawat': 740101,
    'daily_wird': 740102,
    'daily_quran': 740103,
  };

  Future<void> start() async {
    if (!_started) {
      _started = true;
      store.addListener(_changed);
      prayerSettings.addListener(_changed);
    }
    await reconcile();
  }

  Future<void> reconcile() async {
    await notifications.initialize();
    final timezone = prayerSettings.value.timezone;
    final location = tz.getLocation(timezone);
    final now = tz.TZDateTime.now(location);
    final permitted = await notifications.permissionGranted();

    for (final reminder in store.values) {
      final id = _ids[reminder.key]!;
      await notifications.cancel(id);
      if (!reminder.enabled || !permitted) continue;

      var target = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );
      if (!target.isAfter(now)) {
        target = target.add(const Duration(days: 1));
      }
      final text = _content(reminder.key);
      await notifications.schedule(
        LocalNotificationRequest(
          id: id,
          title: text.title,
          body: text.body,
          scheduledAt: target,
          timezone: timezone,
          payload: text.route,
          playSound: reminder.playSound,
          preferExact: false,
          repeatDaily: true,
        ),
      );
    }
  }

  Future<bool> setEnabled(String key, bool enabled) async {
    if (enabled && !await notifications.requestPermission()) return false;
    await store.setEnabled(key, enabled);
    await reconcile();
    return true;
  }

  Future<void> setTime(String key, TimeOfDay time) async {
    await store.setTime(key, time);
    await reconcile();
  }

  Future<void> setSound(String key, bool value) async {
    await store.setSound(key, value);
    await reconcile();
  }

  _ReminderContent _content(String key) {
    if (key == 'salawat') {
      return const _ReminderContent(
        'الصلاة على النبي ﷺ',
        'اللهم صل وسلم على نبينا محمد',
        '/adhkar',
      );
    }
    if (key == 'daily_wird') {
      return const _ReminderContent(
        'وردك اليومي',
        'حان وقت وردك من الذكر؛ افتح ترتيل وأكمل هدف اليوم.',
        '/adhkar',
      );
    }
    return const _ReminderContent(
      'ورد القرآن',
      'حان وقت وردك القرآني اليومي. اقرأ أو استمع لما تيسر.',
      '/quran',
    );
  }

  void _changed() {
    reconcile().catchError((Object error) {
      debugPrint('PERSONAL_REMINDER_RECONCILE_FAILED:$error');
    });
  }

  void dispose() {
    if (_started) {
      store.removeListener(_changed);
      prayerSettings.removeListener(_changed);
    }
  }
}

class PersonalRemindersPage extends StatefulWidget {
  const PersonalRemindersPage({
    super.key,
    required this.store,
    required this.controller,
  });

  final PersonalReminderStore store;
  final PersonalReminderController controller;

  @override
  State<PersonalRemindersPage> createState() => _PersonalRemindersPageState();
}

class _PersonalRemindersPageState extends State<PersonalRemindersPage> {
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    super.dispose();
  }

  String _title(String key) {
    if (key == 'salawat') return 'الصلاة على النبي ﷺ';
    if (key == 'daily_wird') return 'ورد الأذكار اليومي';
    return 'ورد القرآن اليومي';
  }

  IconData _icon(String key) {
    if (key == 'salawat') return Icons.favorite_outline;
    if (key == 'daily_wird') return Icons.auto_awesome_outlined;
    return Icons.menu_book_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تذكيراتي اليومية')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'هذه التذكيرات محلية على هاتفك، ولا تحتاج إلى Firebase أو إرسال من الإدارة أو اتصال بالإنترنت بعد جدولتها.',
              ),
            ),
          ),
          for (final reminder in widget.store.values)
            Card(
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    secondary: Icon(_icon(reminder.key)),
                    title: Text(_title(reminder.key)),
                    subtitle: Text(
                      TimeOfDay(
                        hour: reminder.hour,
                        minute: reminder.minute,
                      ).format(context),
                    ),
                    value: reminder.enabled,
                    onChanged: (value) async {
                      final accepted = await widget.controller.setEnabled(
                        reminder.key,
                        value,
                      );
                      if (!accepted && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يجب السماح بإشعارات ترتيل أولًا.'),
                          ),
                        );
                      }
                    },
                  ),
                  if (reminder.enabled) ...<Widget>[
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('وقت التذكير'),
                      trailing: Text(
                        TimeOfDay(
                          hour: reminder.hour,
                          minute: reminder.minute,
                        ).format(context),
                      ),
                      onTap: () async {
                        final chosen = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(
                            hour: reminder.hour,
                            minute: reminder.minute,
                          ),
                        );
                        if (chosen != null) {
                          await widget.controller.setTime(
                            reminder.key,
                            chosen,
                          );
                        }
                      },
                    ),
                    SwitchListTile(
                      title: const Text('صوت التنبيه'),
                      value: reminder.playSound,
                      onChanged: (value) => widget.controller.setSound(
                        reminder.key,
                        value,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
