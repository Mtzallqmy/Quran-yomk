import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/surah_api_client.dart';

void main() {
  test('discovers actual projects from nested response, without assumed slugs', () async {
    final client = SurahApiClient(client: MockClient((request) async {
      expect(request.url.path, '/api/v1/projects');
      return http.Response.bytes(utf8.encode(jsonEncode({
        'data': [
          {'slug': 'tafsir-demo', 'name_ar': 'تفسير تجريبي', 'type': 'aya'},
          {'slug': 'word-demo', 'title': 'Words', 'type': 'word'}
        ]
      })), 200);
    }));
    addTearDown(client.close);
    final projects = await client.projects();
    expect(projects.map((p) => p.slug), ['tafsir-demo', 'word-demo']);
    expect(projects.first.title, 'تفسير تجريبي');
  });

  test('uses documented single-ayah and word paths', () async {
    final visited = <String>[];
    final client = SurahApiClient(client: MockClient((request) async {
      visited.add(request.url.path);
      return http.Response('{"data":{"text":"sample"}}', 200);
    }));
    addTearDown(client.close);
    await client.aya('tafsir-demo', 101, 1);
    await client.word('word-demo', 101, 1, 2);
    expect(visited, [
      '/api/v1/aya/tafsir-demo/101/1',
      '/api/v1/word/word-demo/101/1/2',
    ]);
  });

  test('rejects malformed project slugs and invalid Quran references', () async {
    final client = SurahApiClient(client: MockClient((_) async {
      fail('Invalid parameters must not cause network requests');
    }));
    addTearDown(client.close);
    expect(() => client.project('../etc'), throwsArgumentError);
    expect(() => client.sura('valid', 115), throwsRangeError);
    expect(() => client.page('valid', 605), throwsRangeError);
  });

  test('does not silently accept upstream failures', () async {
    final client = SurahApiClient(client: MockClient((_) async => http.Response('{}', 429)));
    addTearDown(client.close);
    await expectLater(client.projects(), throwsA(isA<SurahApiException>()));
  });

  test('rejects HTTP or mutable insecure endpoints', () async {
    final client = SurahApiClient(
      baseUri: Uri.parse('http://example.org/api/v1'),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    addTearDown(client.close);
    await expectLater(client.projects(), throwsA(isA<StateError>()));
  });
}
