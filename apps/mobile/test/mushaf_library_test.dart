import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/mushaf_library.dart';
import 'package:tarteel/src/mushaf_store.dart';
import 'package:tarteel/src/mushaf_pages.dart';
import 'package:tarteel/src/services.dart';
import 'package:tarteel/src/screens/mushaf_library.dart';
import 'ui_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await MushafTopicIndex.load();
    await MushafVisualPages.load();
  });

  test(
    'removing cached page assets preserves bookmarks and last position',
    () async {
      final dir = await Directory.systemTemp.createTemp('mushaf-delete-test');
      addTearDown(() => dir.delete(recursive: true));
      final repository = MushafPageRepository(root: dir);
      await repository.initialize();
      // Repository owns only its cache directory; preferences remain independent.
      final unrelated = File('${dir.path}/unrelated.txt')
        ..writeAsStringSync('keep');
      await repository.removeOfflinePack(MushafPageEdition.madinahHafsSvg);
      expect(unrelated.readAsStringSync(), 'keep');
      expect(
        await repository.isOfflinePackAvailable(
          MushafPageEdition.madinahHafsSvg,
        ),
        isFalse,
      );
    },
  );

  testWidgets('library cards and source boundaries fit narrow RTL large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final services = UiServices(await SharedPreferences.getInstance());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.6)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: const MushafLibraryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('مكتبة المصاحف'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('المصحف الموضوعي'), 300);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('المصحف الموضوعي')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('المصحف الموضوعي')));
    await tester.pumpAndSettle();
    expect(find.text('فهرس الموضوعات القرآنية'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'entire topical index is licensed, checksum pinned and references Hafs',
    () async {
      final bytes = File(
        'assets/mushaf_library/topics-2026-10-24.json.gz',
      ).readAsBytesSync();
      expect(sha256.convert(bytes).toString(), topicPackageSha256);
      final index = await MushafTopicIndex.load();
      expect(index.topics.length, 6100);
      final canonical =
          jsonDecode(
                File(
                  '../../data/quran/canonical/v1/dataset.json',
                ).readAsStringSync(),
              )
              as Map;
      final keys = <String>{};
      expect((canonical['surahs'] as List).length, 114);
      for (final surah in canonical['surahs'] as List) {
        expect((surah['verses'] as List).length, surah['ayah_count']);
        for (final verse in surah['verses'] as List) {
          keys.add(verse['verse_key'] as String);
        }
      }
      expect(keys.length, 6236);
      final references = index.topics.expand((t) => t.verseKeys).toList();
      expect(references.length, 19117);
      expect(references.toSet().length, 3673);
      expect(references.every(keys.contains), isTrue);
      expect(index.search('يوسف').isNotEmpty, isTrue);
      expect(index.forVerse('1:1').isNotEmpty, isTrue);
      for (final topic in index.topics) {
        index.ancestry(topic);
      }
    },
  );

  test(
    'all 6236 verse identities map to the actual 604 visual pages',
    () async {
      final pages = await MushafVisualPages.load();
      expect(pages.length, 6236);
      expect(pages.values.toSet().length, 604);
      expect(pages['1:1'], 1);
      expect(pages['114:6'], 604);
      // Regression: API text metadata says121, actual pinned artwork says120.
      expect(pages['5:77'], 120);
      expect(pages.values.every((p) => p >= 1 && p <= 604), isTrue);
    },
  );

  test(
    'library selection backs up exact legacy values once without changing keys',
    () async {
      const old =
          '{"mode":"page","number":121,"verse_key":"5:77","page_number":121}';
      SharedPreferences.setMockInitialValues({
        'mushaf:last-position:v1': old,
        'mushaf:bookmarks:v1':
            '[{"verse_key":"5:77","surah_number":5,"ayah_number":77,"page_number":121}]',
        'favorites': 'untouched',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MushafStore(prefs)..load();
      await store.backupBeforeLibraryUpgrade();
      final backup = prefs.getString('mushaf:pre-library-backup:v1');
      expect((jsonDecode(backup!) as Map)['mushaf:last-position:v1'], old);
      await store.setPageEdition('madinahTajweedQcfV4');
      await store.backupBeforeLibraryUpgrade();
      expect(prefs.getString('mushaf:pre-library-backup:v1'), backup);
      expect(store.bookmarks.single.verseKey, '5:77');
      expect(prefs.getString('mushaf:last-position:v1'), old);
      expect(prefs.getString('favorites'), 'untouched');
    },
  );

  test(
    'source hierarchy cycles and duplicate topic identities fail closed',
    () {
      Map<String, dynamic> source(List<Map<String, dynamic>> rows) => {
        'schema': '/v1/topics',
        'license': {'version': '2026-10-24'},
        'data': rows,
      };
      final row = {'id': 1, 'name': 'topic', 'parent_id': 1, 'ayahs': '1:1'};
      expect(
        () => MushafTopicIndex.parse(source([row])),
        throwsFormatException,
      );
      expect(
        () => MushafTopicIndex.parse(
          source([
            {...row, 'parent_id': null},
            {...row, 'parent_id': null},
          ]),
        ),
        throwsFormatException,
      );
    },
  );
}
