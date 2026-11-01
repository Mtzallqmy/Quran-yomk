import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/cloud_backup.dart';
import 'package:tarteel/src/prayer_backup.dart';
import 'package:tarteel/src/prayer_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'portable preferences exclude location manual times and private paths',
    () {
      final local = PrayerSettings.taiz().copyWith(
        manualTimes: {PrayerKind.fajr: 300},
        audioPaths: {
          PrayerKind.fajr: '/data/private/audio.mp3',
          PrayerKind.isha: 'assets/audio/user_makkah.mp3',
        },
      );
      final payload = PrayerBackup.encode(local);
      expect(payload.keys, isNot(contains('latitude')));
      expect(payload.keys, isNot(contains('manual_times')));
      expect(payload['audio_assets'], {'isha': 'assets/audio/user_makkah.mp3'});
      final restored = PrayerBackup.decode({
        ...payload,
        'asr_method': 'hanafi',
      }, local);
      expect(restored.latitude, local.latitude);
      expect(restored.timezone, 'Asia/Aden');
      expect(restored.manualTimes[PrayerKind.fajr], 300);
      expect(restored.audioPaths[PrayerKind.fajr], '/data/private/audio.mp3');
      expect(restored.asrMethod, PrayerAsrMethod.hanafi);
    },
  );
  test(
    'invalid cloud data is rejected before local preferences change',
    () async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = PrayerSettingsStore(prefs)..load();
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'data': {
                'payload': {
                  ...PrayerBackup.encode(store.value),
                  'latitude': 44,
                },
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        client.restorePrayerPreferences(store),
        throwsFormatException,
      );
      expect(prefs.getString('settings:prayer:v1'), null);
      expect(store.value.latitude, 13.5795);
      client.close();
    },
  );
  test(
    'explicit backup uses separate endpoint consent and optimistic revision',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      var requests = 0;
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient((r) async {
          requests++;
          expect(r.url.path, '/v1/prayer-preferences');
          if (r.method == 'GET')
            return http.Response('{"data":{"revision":"3"}}', 200);
          final body = jsonDecode(r.body);
          expect(body['consent'], 'prayer-preferences-v1');
          expect(body['revision'], 3);
          expect((body['payload'] as Map).containsKey('latitude'), false);
          return http.Response('{"data":{"revision":"4"}}', 200);
        }),
      );
      expect(requests, 0);
      await client.uploadPrayerPreferences(PrayerSettings.taiz());
      expect(requests, 2);
      client.close();
    },
  );
  test(
    'restore notifies local scheduling and keeps an exact rollback copy',
    () async {
      final original = jsonEncode(PrayerSettings.taiz().toJson());
      SharedPreferences.setMockInitialValues({'settings:prayer:v1': original});
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = PrayerSettingsStore(prefs)..load();
      var changes = 0;
      store.addListener(() => changes++);
      final payload = PrayerBackup.encode(
        store.value.copyWith(
          reminderModes: {PrayerKind.fajr: PrayerReminderMode.adhan},
          beforeMinutes: {PrayerKind.fajr: 5},
        ),
      );
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient(
          (r) async => http.Response(
            jsonEncode({
              'data': {'payload': payload},
            }),
            200,
          ),
        ),
      );
      await client.restorePrayerPreferences(store);
      expect(changes, 1);
      expect(
        store.value.reminderModeFor(PrayerKind.fajr),
        PrayerReminderMode.adhan,
      );
      expect(store.value.latitude, 13.5795);
      expect(
        prefs.getString('settings:prayer:before-cloud-restore:v1'),
        original,
      );
      client.close();
    },
  );
}
