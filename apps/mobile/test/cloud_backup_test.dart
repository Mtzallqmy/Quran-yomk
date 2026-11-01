import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/cloud_backup.dart';
import 'package:tarteel/src/storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test(
    'does no network work before explicit consent and stores scoped credential',
    () async {
      var requests = 0;
      final token = 'a' * 43;
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient((request) async {
          requests++;
          expect(request.url.path, '/v1/devices');
          expect(jsonDecode(request.body)['consent'], 'favorites-backup-v1');
          return http.Response(jsonEncode({'token': token}), 201);
        }),
      );
      expect(await client.enabled(), false);
      expect(requests, 0);
      await client.connectWithConsent();
      expect(await client.enabled(), true);
      await client.connectWithConsent();
      expect(requests, 1);
      client.close();
    },
  );

  test(
    'restore merges without removing existing favorites and does not touch prayer settings',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites:stations': ['local'],
        'settings:prayer:v1': 'preserve',
      });
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      final prefs = await SharedPreferences.getInstance();
      final favorites = FavoritesStore(prefs)..load();
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer ${'a' * 43}');
          return http.Response(
            jsonEncode({
              'data': {
                'revision': '1',
                'payload': {
                  'stations': ['remote'],
                  'reciters': ['reciter'],
                  'tracks': <String>[],
                },
              },
            }),
            200,
          );
        }),
      );
      await client.restore(favorites);
      expect(favorites.stationIds, {'local', 'remote'});
      expect(favorites.reciterIds, {'reciter'});
      expect(prefs.getString('settings:prayer:v1'), 'preserve');
      client.close();
    },
  );

  test(
    'invalid restore is rejected atomically before modifying local favorites',
    () async {
      SharedPreferences.setMockInitialValues({
        'favorites:stations': ['local'],
      });
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      final prefs = await SharedPreferences.getInstance();
      final favorites = FavoritesStore(prefs)..load();
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': {
                'payload': {
                  'stations': ['remote'],
                  'reciters': [123],
                  'tracks': <String>[],
                },
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(client.restore(favorites), throwsFormatException);
      expect(favorites.stationIds, {'local'});
      client.close();
    },
  );

  test(
    'upload sends favorites only and forwards optimistic revision',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'tarteel:cloud:device-token:v1': 'a' * 43,
      });
      final prefs = await SharedPreferences.getInstance();
      final favorites = FavoritesStore(prefs)..load();
      await favorites.toggleTrack('track');
      final client = CloudBackupClient(
        baseUrl: 'https://cloud.example',
        client: MockClient((request) async {
          if (request.method == 'GET')
            return http.Response('{"data":{"revision":"7"}}', 200);
          final body = jsonDecode(request.body);
          expect(body['revision'], 7);
          expect((body['payload'] as Map).keys.toSet(), {
            'stations',
            'reciters',
            'tracks',
          });
          expect(body['payload']['tracks'], ['track']);
          return http.Response('{"data":{"revision":"8"}}', 200);
        }),
      );
      await client.upload(favorites);
      client.close();
    },
  );
}
