import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/models.dart';
import 'package:tarteel/src/radio_catalog.dart';

Station station(String id, String name, String url, {String? slug}) => Station(
  id: id,
  slug: slug ?? id,
  nameAr: name,
  playbackUrl: url,
  source: 'EXTERNAL',
  streamType: 'SHOUTCAST',
);

void main() {
  test(
    'existing IDs win over backup mirrors, Arabic spelling and provider IDs',
    () {
      final existing = station(
        'favorite-id',
        'أحمد العجمي',
        'https://qurango.net/radio/ahmad',
        slug: 'mp3quran-radio-3',
      );
      final additions = [
        station(
          'mirror',
          'Different name',
          'https://backup.qurango.net/radio/ahmad/',
        ),
        station('spelling', 'اَحمد العجمي', 'https://other.example/live'),
        station(
          'provider',
          'Third name',
          'https://other.example/changed',
          slug: 'neon-mp3quran-3',
        ),
        station(
          'new',
          'الشمائل المحمدية',
          'https://backup.qurango.net/radio/shmaeel',
        ),
        station('dupe-new', 'الشمائل المحمدية', 'https://else.example/live'),
      ];
      final result = mergeRadioCatalogs([existing], additions);
      expect(result.map((s) => s.id), ['favorite-id', 'new']);
      expect(identical(result.first, existing), isTrue);
    },
  );
  test('different paths and query station selectors remain different', () {
    expect(
      canonicalRadioUrl('https://example.com:443/live?id=1'),
      'example.com/live?id=1',
    );
    final rows = mergeRadioCatalogs([], [
      station('1', 'واحد', 'https://example.com/live?id=1'),
      station('2', 'اثنان', 'https://example.com/live?id=2'),
      station('3', 'غير آمن', 'http://example.com/live'),
    ]);
    expect(rows.length, 2);
  });
  test(
    'optional Neon API fetches public metadata without backup credential',
    () async {
      final api = SupplementalRadioApi(
        baseUrl: 'https://cloud.example/',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/radio/stations');
          expect(request.headers.containsKey('authorization'), isFalse);
          return http.Response(
            jsonEncode({
              'data': [
                station('new', 'محطة', 'https://example.com/live').toJson(),
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect((await api.stations()).single.nameAr, 'محطة');
    },
  );
  test(
    'malformed response and server failure do not replace cached catalog',
    () async {
      for (final response in [
        http.Response('{"data":{}}', 200),
        http.Response('down', 503),
      ]) {
        final api = SupplementalRadioApi(
          baseUrl: 'https://cloud.example',
          client: MockClient((_) async => response),
        );
        await expectLater(api.stations(), throwsFormatException);
      }
    },
  );
}
