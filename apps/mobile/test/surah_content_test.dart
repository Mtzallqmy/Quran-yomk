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
  testWidgets(
    'all educational scopes load lazily and refresh an open section on navigation',
    (tester) async {
      final paths = <String>[];
      final api = SurahApiClient(
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('projects'))
            return response([
              {'slug': 'tajweed-aya', 'title': 'أحكام التجويد', 'type': 'aya'},
              {'slug': 'maqased-sowar', 'title': 'مقاصد السور', 'type': 'sura'},
              {'slug': 'fawaed-page', 'title': 'فوائد', 'type': 'page'},
            ]);
          final p = r.url.pathSegments;
          return response({
            if (p[2] == 'page')
              'page_number': int.parse(p[4])
            else
              'sura_number': int.parse(p[4]),
            if (p[2] == 'aya') 'aya_number': int.parse(p[5]),
            'content': 'شرح ${p[3]} ${p.last}',
          });
        }),
      );
      Widget tree(int ayah) => ProviderScope(
        overrides: [surahContentProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SurahReaderPanel(surah: 1, ayah: ayah, page: ayah),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(1));
      await tester.pumpAndSettle();
      expect(paths, ['/api/v1/projects']);
      await tester.tap(find.text('أحكام التجويد'));
      await tester.pumpAndSettle();
      expect(find.text('شرح tajweed-aya 1'), findsOneWidget);
      await tester.pumpWidget(tree(2));
      await tester.pumpAndSettle();
      expect(find.text('شرح tajweed-aya 1'), findsNothing);
      expect(find.text('شرح tajweed-aya 2'), findsOneWidget);
      await tester.tap(find.text('مقاصد السور'));
      await tester.pumpAndSettle();
      expect(paths, contains('/api/v1/sura/maqased-sowar/1'));
      await tester.tap(find.text('فوائد الصفحة'));
      await tester.pumpAndSettle();
      expect(paths, contains('/api/v1/page/fawaed-page/2'));
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets('catalog and content recover using visible retry actions', (
    tester,
  ) async {
    var catalogFails = true;
    var contentFails = true;
    final api = SurahApiClient(
      client: MockClient((r) async {
        if (r.url.path.endsWith('projects'))
          return catalogFails ? http.Response('', 503) : response([catalog[2]]);
        return contentFails
            ? http.Response('', 503)
            : response({
                'sura_number': 1,
                'aya_number': 1,
                'content': 'تم استرجاع التفسير',
              });
      }),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [surahContentProvider.overrideWithValue(api)],
        child: const MaterialApp(
          home: Scaffold(body: SurahReaderPanel(surah: 1, ayah: 1, page: 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تعذر تحميل فهرس المحتوى'), findsOneWidget);
    catalogFails = false;
    await tester.tap(find.byTooltip('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(
      find.text('تعذر جلب المحتوى. تبقى القراءة والتلاوة متاحة.'),
      findsOneWidget,
    );
    contentFails = false;
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(find.text('تم استرجاع التفسير'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

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
    'live page-benefits shape supports string arrays and rejects unknown nested content',
    () async {
      var malformed = false;
      final api = SurahApiClient(
        policy: const SurahCachePolicy(ttl: Duration.zero),
        client: MockClient((r) async {
          if (r.url.path.endsWith('projects')) return response(catalog);
          return response({
            'page_number': 1,
            'content': malformed
                ? [
                    {'unexpected': 'not text'},
                  ]
                : ['<p>فائدة أولى</p>', 'فائدة ثانية'],
          });
        }),
      );
      expect(
        (await api.read('page', [1])).single.text,
        'فائدة أولى\n\nفائدة ثانية',
      );
      malformed = true;
      await expectLater(api.read('page', [1]), throwsFormatException);
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
    'word projects retain their own token identities and location updates refresh tafsir',
    (tester) async {
      final paths = <String>[];
      final api = SurahApiClient(
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('projects'))
            return response([
              ...catalog,
              {'slug': 'word-qeraat', 'title': 'بيان القراءات', 'type': 'word'},
            ]);
          final pieces = r.url.pathSegments;
          if (r.url.path.contains('/word/'))
            return response([
              {
                'sura_number': 1,
                'aya_number': int.parse(pieces[5]),
                'word_number': pieces[3] == 'word-qeraat' ? 9 : 1,
                'word': pieces[3] == 'word-qeraat'
                    ? 'كلمة المصدر المختلف'
                    : 'كلمة',
                'content': pieces[3] == 'word-qeraat'
                    ? 'قراءات موثقة'
                    : 'إعراب موثق',
              },
            ]);
          return response({
            'sura_number': 1,
            'aya_number': int.parse(pieces.last),
            'content': 'تفسير ${pieces.last}',
          });
        }),
      );
      Widget tree(int ayah) => ProviderScope(
        overrides: [surahContentProvider.overrideWithValue(api)],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SurahReaderPanel(surah: 1, ayah: ayah, page: 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(tree(1));
      await tester.pumpAndSettle();
      expect(find.text(SurahRightsRegistry.attribution), findsNothing);
      await tester.tap(find.text('الكلمات والإعراب'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('كلمة'));
      await tester.pumpAndSettle();
      expect(find.text('إعراب موثق'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('surah-word-project')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('بيان القراءات').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('كلمة المصدر المختلف'));
      await tester.pumpAndSettle();
      expect(find.text('قراءات موثقة'), findsOneWidget);
      expect(find.text('تفسير 1'), findsOneWidget);
      expect(paths, contains('/api/v1/word/word-qeraat/1/1/1/32'));
      await tester.pumpWidget(tree(2));
      await tester.pumpAndSettle();
      expect(find.text('تفسير 2'), findsOneWidget);
      expect(paths, contains('/api/v1/word/word-qeraat/1/2/1/32'));
      expect(find.text('تفسير 1'), findsNothing);
      expect(find.text('قراءات موثقة'), findsNothing);
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
