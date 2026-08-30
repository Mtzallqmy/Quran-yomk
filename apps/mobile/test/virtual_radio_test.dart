import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/api.dart';
import 'package:tarteel/src/virtual_radio.dart';

Map<String, dynamic> resolutionJson({
  String stationId = '11111111-1111-4111-8111-111111111111',
}) => <String, dynamic>{
  'available': true,
  'channel': <String, dynamic>{
    'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    'slug': 'tarteel',
    'name_ar': 'إذاعة ترتيل',
    'timezone': 'Asia/Aden',
  },
  'program': <String, dynamic>{
    'id': 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    'title_ar': 'تلاوات مختارة',
    'category': 'QURAN_GENERAL',
    'started_at': '2026-08-30T21:00:00Z',
    'ends_at': '2026-08-31T01:00:00Z',
  },
  'station': <String, dynamic>{
    'id': stationId,
    'slug': 'real-station',
    'name_ar': 'إذاعة حقيقية',
    'station_source': 'EXTERNAL',
    'stream_type': 'SHOUTCAST',
    'playback_url': 'https://stream.example.test/live',
    'health_status': 'HEALTHY',
    'provider': 'provider',
  },
  'next_program': <String, dynamic>{'title_ar': 'الأذكار'},
  'next_change_at': '2026-08-31T01:00:00Z',
  'server_time': '2026-08-30T23:30:00Z',
  'resolution': <String, dynamic>{'selection_tier': 0},
};

void main() {
  test(
    'virtual resolution preserves logical channel and physical source identities',
    () {
      final value = VirtualRadioResolution.fromJson(resolutionJson());
      expect(value.channelSlug, 'tarteel');
      expect(value.channelNameAr, 'إذاعة ترتيل');
      expect(value.program?.category, 'QURAN_GENERAL');
      expect(value.station?.id, '11111111-1111-4111-8111-111111111111');
      expect(value.station?.isExternal, isTrue);
      expect(value.station?.isPlayable, isTrue);
      expect(value.nextProgramTitleAr, 'الأذكار');
    },
  );

  test('virtual API sends bounded failed station IDs to the resolver', () async {
    Uri? seen;
    final client = MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode(<String, dynamic>{
          'data': resolutionJson(
            stationId: '22222222-2222-4222-8222-222222222222',
          ),
        }),
        200,
      );
    });
    final api = TarteelApiClient(
      client: client,
      baseUrl: 'https://example.test/api/v1',
    );
    await api.virtualRadio(
      failedStationIds: const <String>[
        '11111111-1111-4111-8111-111111111111',
        '33333333-3333-4333-8333-333333333333',
      ],
    );
    expect(seen?.path, '/api/v1/virtual-radio/tarteel');
    expect(
      seen?.queryParameters['failed_station_ids'],
      '11111111-1111-4111-8111-111111111111,33333333-3333-4333-8333-333333333333',
    );
  });

  test('transcription remains independent of virtual radio contract', () {
    final value = VirtualRadioResolution.fromJson(resolutionJson());
    expect(value.available, isTrue);
    expect(value.station?.playbackUrl, startsWith('https://'));
  });
}
