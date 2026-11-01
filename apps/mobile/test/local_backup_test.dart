import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/local_backup.dart';
import 'package:tarteel/src/prayer_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'portable backup excludes credentials, paths and enabled alarms',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites:stations': ['old'],
        'settings:theme': 'dark',
        'cloud:token': 'must-not-export',
        'adhan:files:v1': '{"phone":"/private/audio"}',
        'settings:prayer:v1': jsonEncode(
          PrayerSettings.taiz()
              .copyWith(
                audioPaths: {PrayerKind.fajr: '/private/audio'},
                remindersEnabled: true,
                reminderModes: {PrayerKind.fajr: PrayerReminderMode.adhan},
              )
              .toJson(),
        ),
      });
      final backup = LocalDataBackup(
        await SharedPreferences.getInstance(),
      ).export();
      expect(backup, isNot(contains('must-not-export')));
      expect(backup, isNot(contains('/private/audio')));
      final prayer = PrayerSettings.fromJson(
        jsonDecode(backup)['prayer'] as Map<String, dynamic>,
      );
      expect(prayer.remindersEnabled, isFalse);
      expect(prayer.audioPaths, isEmpty);
    },
  );
  test(
    'restore merges existing favorites; settings require explicit opt-in',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites:stations': ['existing'],
        'settings:theme': 'light',
      });
      final prefs = await SharedPreferences.getInstance();
      final backup = LocalDataBackup(prefs);
      final body = jsonDecode(backup.export());
      body['favorites']['favorites:stations'] = ['existing', 'new', 'new'];
      body['settings']['settings:theme'] = 'dark';
      expect(await backup.restore(jsonEncode(body)), 1);
      expect(prefs.getStringList('favorites:stations'), ['existing', 'new']);
      expect(prefs.getString('settings:theme'), 'light');
      await backup.restore(jsonEncode(body), restoreSettings: true);
      expect(prefs.getString('settings:theme'), 'dark');
    },
  );
  test('invalid backup is rejected before changing any preference', () async {
    SharedPreferences.setMockInitialValues({
      'favorites:stations': ['existing'],
    });
    final prefs = await SharedPreferences.getInstance();
    final backup = LocalDataBackup(prefs);
    final body = jsonDecode(backup.export());
    body['favorites']['favorites:stations'] = ['new'];
    body['settings']['cloud:token'] = 'injected';
    await expectLater(
      backup.restore(jsonEncode(body), restoreSettings: true),
      throwsFormatException,
    );
    expect(prefs.getStringList('favorites:stations'), ['existing']);
    expect(prefs.getString('cloud:token'), isNull);
    await expectLater(
      backup.restore('x' * (256 * 1024 + 1)),
      throwsFormatException,
    );
  });
}
