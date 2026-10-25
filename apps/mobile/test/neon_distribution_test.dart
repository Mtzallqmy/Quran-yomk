import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/content_catalog.dart';
import 'package:tarteel/src/remote_config.dart';
import 'package:tarteel/src/repository.dart';
import 'package:tarteel/src/surah_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final row = {
    'slug': 'tafsir-mokhtasar',
    'title': 'المختصر',
    'scope': 'aya',
    'source_url': 'https://dev.surahapp.com/api/v1/project/tafsir-mokhtasar',
    'permanent_storage_allowed': false,
    'redistribution_allowed': false,
    'policy': 'direct_session_only',
  };
  test(
    'Neon supplies project identities while verse bodies remain official',
    () async {
      final paths = <Uri>[];
      final api = SurahApiClient(
        projectCatalog: () async => [row],
        client: MockClient((r) async {
          paths.add(r.url);
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'sura_number': 1,
                'aya_number': 1,
                'content': 'تفسير',
              }),
            ),
            200,
          );
        }),
      );
      expect((await api.read('tafsir-mokhtasar', [1, 1])).single.text, 'تفسير');
      expect(paths.single.host, 'dev.surahapp.com');
      expect(SurahRightsRegistry().mayPersist('tafsir-mokhtasar'), false);
      api.close();
    },
  );
  test(
    'Neon outage or invalid registry falls back to published official catalog',
    () async {
      var broken = true, calls = 0;
      final api = SurahApiClient(
        projectCatalog: () async {
          if (broken) throw StateError('OFFLINE');
          return [
            {...row, 'source_url': 'https://untrusted.example/content'},
          ];
        },
        policy: const SurahCachePolicy(ttl: Duration.zero),
        client: MockClient((r) async {
          calls++;
          expect(r.url.path, '/api/v1/projects');
          return http.Response(
            jsonEncode([
              {'slug': 'official', 'type': 'aya'},
            ]),
            200,
          );
        }),
      );
      expect((await api.projects()).single.slug, 'official');
      broken = false;
      expect((await api.projects()).single.slug, 'official');
      expect(calls, 2);
      api.close();
    },
  );
  test(
    'distribution only accepts verified package certificate and release origin',
    () async {
      final release = {
        'application_id': 'app.tarteel.tarteel',
        'architecture': 'arm64-v8a',
        'channel': 'preview',
        'version_code': 2094,
        'version_name': '0.9.2-beta.2',
        'minimum_sdk': 26,
        'apk_sha256': 'a' * 64,
        'certificate_sha256':
            '5e2a2a7412c93c8a0e9e28917195534b726c9c1ae3a35232e9fd0aeb5fa718b8',
        'apk_url':
            'https://github.com/Mtzallqmy/Quran-yomk/releases/download/test/app.apk',
      };
      final api = ContentCatalogApi(
        baseUrl: 'https://content.example',
        client: MockClient(
          (r) async =>
              http.Response(jsonEncode({'schema': 1, 'release': release}), 200),
        ),
      );
      expect(
        (await api.distributionConfig())['latest_android_version_code'],
        2094,
      );
      release['apk_url'] = 'https://github.com.evil.example/app.apk';
      await expectLater(api.distributionConfig(), throwsFormatException);
      release['apk_url'] =
          'https://github.com/Mtzallqmy/Quran-yomk/releases/download/test/app.apk';
      release['certificate_sha256'] = 'b' * 64;
      await expectLater(api.distributionConfig(), throwsFormatException);
      api.dispose();
    },
  );
  test(
    'Neon update metadata survives old API outage without changing local feature flags',
    () async {
      SharedPreferences.setMockInitialValues({
        'tarteel_remote_config:v1':
            '{"radio_enabled":false,"prayer_features_enabled":true}',
      });
      final config = TarteelRemoteConfig(
        _OfflineRepository(),
        await SharedPreferences.getInstance(),
        distribution: _Distribution(),
      )..load();
      await config.refresh();
      expect(config.latestAndroidVersion, '0.9.2-beta.2');
      expect(config.radioEnabled, false);
      expect(config.prayerFeaturesEnabled, true);
      config.dispose();
    },
  );
}

class _OfflineRepository implements TarteelRepository {
  @override
  Future<Map<String, dynamic>> appConfig({bool refresh = false}) async =>
      throw StateError('OFFLINE');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Distribution extends ContentCatalogApi {
  @override
  Future<Map<String, dynamic>> distributionConfig() async => {
    'latest_android_version': '0.9.2-beta.2',
  };
}
