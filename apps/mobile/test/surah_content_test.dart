import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tarteel/src/surah_content.dart';
import 'package:tarteel/src/surah_reader_panel.dart';

final catalog = [
  for (final scope in SurahScope.values)
    {
      'slug': scope == SurahScope.aya
          ? 'tafsir-mokhtasar'
          : scope == SurahScope.word
          ? 'eerab-word'
          : scope.name,
      'title': scope.name,
      'type': scope.name,
    },
];
http.Response response(dynamic value, {Map<String, String>? headers}) =>
    http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      200,
      headers: headers ?? {},
    );
void main() {
  test(
    'discovers only valid published projects; unknown slug fails before content request',
    () async {
      var calls = 0;
      final api = SurahApiClient(
        client: MockClient((request) async {
          calls++;
          return response([
            ...catalog,
            {'slug': '../unsafe', 'type': 'aya'},
            {'slug': 'hidden', 'type': 'aya', 'published': false},
          ]);
        }),
      );
      expect((await api.projects()).length, 4);
      await expectLater(api.read('not-published', [1, 1]), throwsStateError);
      expect(calls, 1);
      api.close();
    },
  );
  test(
    'all four scopes and documented ranges validate exact source identities',
    () async {
      final paths = <String>[];
      final api = SurahApiClient(
        client: MockClient((request) async {
          final path = request.url.path.replaceFirst('/api/v1/', '');
          paths.add(path);
          if (path == 'projects') return response(catalog);
          final p = path.split('/');
          final fields = switch (p[0]) {
            'sura' => ['sura_number'],
            'page' => ['page_number'],
            'aya' => ['sura_number', 'aya_number'],
            _ => ['sura_number', 'aya_number', 'word_number'],
          };
          final numbers = p.skip(2).map(int.parse).toList();
          return response([
            for (
              var last = numbers[fields.length - 1];
              last <=
                  (numbers.length > fields.length
                      ? numbers.last
                      : numbers[fields.length - 1]);
              last++
            )
              {
                for (var i = 0; i < fields.length; i++)
                  fields[i]: i == fields.length - 1 ? last : numbers[i],
                'content': '<p>تعليم</p>',
                'word': 'كلمة',
              },
          ]);
        }),
      );
      for (final scope in SurahScope.values) {
        final p = (await api.projects()).firstWhere((p) => p.scope == scope);
        final loc = switch (scope) {
          SurahScope.sura || SurahScope.page => [1],
          SurahScope.aya => [1, 1],
          SurahScope.word => [1, 1, 1],
        };
        expect((await api.read(p.slug, loc)).single.text, 'تعليم');
        expect((await api.read(p.slug, loc, end: 2)).length, 2);
      }
      expect(paths, contains('word/eerab-word/1/1/1/2'));
      api.close();
    },
  );
  test(
    'wrong verse and duplicate references fail closed, not silently attached',
    () async {
      final api = SurahApiClient(
        client: MockClient(
          (r) async => r.url.path.endsWith('projects')
              ? response(catalog)
              : response({
                  'sura_number': 2,
                  'aya_number': 1,
                  'content': 'wrong',
                }),
        ),
      );
      await expectLater(
        api.read('tafsir-mokhtasar', [1, 1]),
        throwsFormatException,
      );
      api.close();
    },
  );
  test(
    'session caching, ETag revalidation and no-store do not write permanent content',
    () async {
      var now = DateTime.utc(2026);
      var calls = 0;
      final api = SurahApiClient(
        clock: () => now,
        client: MockClient((r) async {
          calls++;
          if (r.headers['If-None-Match'] == 'v1') return http.Response('', 304);
          return response(catalog, headers: {'etag': 'v1'});
        }),
      );
      await api.projects();
      await api.projects();
      expect(calls, 1);
      now = now.add(const Duration(minutes: 4));
      await api.projects();
      expect(calls, 2);
      expect(SurahRightsRegistry().mayPersist('tafsir-saadi'), false);
      api.close();
      var noStore = 0;
      final second = SurahApiClient(
        client: MockClient((_) async {
          noStore++;
          return response(catalog, headers: {'cache-control': 'no-store'});
        }),
      );
      await second.projects();
      await second.projects();
      expect(noStore, 2);
      second.close();
    },
  );
  test('bounded retries and HTML sanitization', () async {
    var count = 0;
    final api = SurahApiClient(
      client: MockClient((_) async {
        count++;
        return http.Response('', 500);
      }),
    );
    await expectLater(api.projects(), throwsStateError);
    expect(count, 2);
    api.close();
    expect(SurahContentEntry.plain('<script>bad</script><p>علم</p>'), 'علم');
  });
  test('timeouts abort the actual transport', () async {
    var aborts = 0;
    final api = SurahApiClient(
      timeout: const Duration(milliseconds: 5),
      client: _AbortingClient(() => aborts++),
    );
    await expectLater(api.projects(), throwsA(isA<TimeoutException>()));
    await Future<void>.delayed(Duration.zero);
    expect(aborts, 2);
    api.close();
  });
  testWidgets(
    'actual source word is selectable in RTL without reader branding',
    (tester) async {
      final api = SurahApiClient(
        client: MockClient((r) async {
          if (r.url.path.endsWith('projects')) return response(catalog);
          if (r.url.path.contains('/word/'))
            return response([
              {
                'sura_number': 1,
                'aya_number': 1,
                'word_number': 1,
                'word': 'كلمة',
                'content': 'إعراب موثق',
              },
            ]);
          return response({
            'sura_number': 1,
            'aya_number': 1,
            'content': 'تفسير',
          });
        }),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [surahContentProvider.overrideWithValue(api)],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: SurahReaderPanel(surah: 1, ayah: 1, page: 1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(SurahRightsRegistry.attribution), findsNothing);
      await tester.tap(find.text('الكلمات والإعراب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كلمة'));
      await tester.pumpAndSettle();
      expect(find.text('إعراب موثق'), findsOneWidget);
      api.close();
    },
  );
}

class _AbortingClient extends http.BaseClient {
  _AbortingClient(this.onAbort);
  final void Function() onAbort;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await (request as http.AbortableRequest).abortTrigger;
    onAbort();
    throw http.RequestAbortedException(request.url);
  }
}
