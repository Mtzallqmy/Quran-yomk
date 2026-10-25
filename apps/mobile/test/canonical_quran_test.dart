import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/canonical_quran.dart';
import 'package:tarteel/src/islamic_content.dart';
import 'package:tarteel/src/mushaf_library.dart';
import 'package:tarteel/src/mushaf_store.dart';
import 'package:tarteel/src/quran_models.dart';
import 'package:tarteel/src/storage.dart';
import 'package:tarteel/src/thematic_quran.dart';
import 'package:tarteel/src/tajweed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'tajweed offsets fail without identical Unicode fingerprint and reviewed rights',
    () async {
      final text = (await TarteelCanonicalQuran.load())
          .ayah('1:1')!
          .textUthmani;
      const rule = TajweedRule(
        id: 'fixture',
        label: 'fixture',
        explanation: 'fixture',
        color: TajweedColor(0xff123456),
        reviewReference: 'fixture',
      );
      const annotation = TajweedAnnotation(
        0,
        1,
        rule,
        TajweedTextVersion(
          'different-source',
          '0000000000000000000000000000000000000000000000000000000000000000',
        ),
      );
      expect(
        annotation.matches(
          text,
          const TajweedSourceRights(
            'fixture',
            'https://example.org',
            mayUse: true,
            scholarlyReviewed: true,
          ),
        ),
        false,
      );
    },
  );
  test(
    'allfour modes preserve position and legacy settings keys across reload',
    () async {
      SharedPreferences.setMockInitialValues({
        'mushaf:last-position:v1':
            '{"mode":"page","number":604,"verse_key":"112:1","page_number":604}',
        'mushaf:bookmarks:v1': '[]',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = MushafStore(prefs)..load();
      for (final mode in UnifiedMushafMode.values) {
        await store.setUnifiedMode(mode);
        final restored = MushafStore(prefs)..load();
        expect(restored.unifiedMode, mode);
        expect(restored.lastPosition!.number, 604);
        expect(prefs.getString('mushaf:bookmarks:v1'), '[]');
      }
    },
  );
  test(
    'all114 official surahs and6236 identities match every visual SVG page',
    () async {
      final q = await TarteelCanonicalQuran.load();
      final visual = await MushafVisualPages.load();
      expect(q.surahs.length, 114);
      expect(q.ayahs.length, 6236);
      expect(q.ayahs.map((a) => a.canonicalId).toSet().length, 6236);
      expect(q.ayahs.map((a) => a.pageNumber).toSet().length, 604);
      expect(q.ayahs.map((a) => a.juzNumber).toSet().length, 30);
      for (final a in q.ayahs) {
        expect(visual[a.verseKey], a.pageNumber, reason: a.verseKey);
        expect(a.hasEmbeddedAyahNumber, true, reason: a.verseKey);
        expect(a.textTajweed, isNull);
      }
      for (final item in {1: 7, 2: 286, 101: 11, 112: 4}.entries) {
        expect(
          q.passage(QuranBrowseMode.surah, item.key).verses.length,
          item.value,
        );
      }
      expect(q.ayah('hafs:101:1'), same(q.ayah('101:1')));
    },
  );
  test(
    'a single changed codepoint fails checksum; official text cannot be normalized into acceptance',
    () {
      final bytes = gzip.decode(
        File('assets/canonical/hafs-v2.json.gz').readAsBytesSync(),
      );
      final text = utf8.decode(bytes);
      expect(
        () => TarteelCanonicalQuran.parse(utf8.encode('$text ')),
        throwsFormatException,
      );
    },
  );
  test(
    '2092 upgrade retires only passage caches, preserving all existing user settings',
    () async {
      final original = <String, Object>{
        'mushaf:last-position:v1':
            '{"mode":"page","number":599,"verse_key":"101:1"}',
        'mushaf:bookmarks:v1': '[]',
        'mushaf:font-scale': 1.4,
        'mushaf:show-tajweed': true,
        'mushaf:show-themes': false,
        'mushaf:presentation:v1': 'page',
        'mushaf:page-edition:v1': 'madinahHafsSvg',
        'favorites:stations': ['kept'],
        'prayer:method': 'kept',
        'cache:quran:audio-reciters:1': 'kept',
        'cache:quran:surah:1': 'OLD_TEXT',
        'cache:quran:surah:1:written': 1,
      };
      SharedPreferences.setMockInitialValues(original);
      final prefs = await SharedPreferences.getInstance();
      final store = MushafStore(prefs)..load();
      await store.backupBeforeLibraryUpgrade();
      await TarteelCanonicalQuran.load();
      await MetadataCache(prefs).retireLegacyQuranPassages();
      await MetadataCache(prefs).retireLegacyQuranPassages();
      expect(prefs.get('cache:quran:surah:1'), isNull);
      expect(prefs.get('cache:quran:surah:1:written'), isNull);
      for (final entry in original.entries.where(
        (e) => !e.key.startsWith('cache:quran:surah:'),
      )) {
        expect(prefs.get(entry.key), entry.value, reason: entry.key);
      }
      await store.setUnifiedMode(UnifiedMushafMode.thematic);
      expect(store.lastPosition!.number, 599);
      expect(store.unifiedMode, UnifiedMushafMode.thematic);
      await store.setThemeOpacity(0.5);
      expect(store.themeOpacity, 0.5);
      expect(prefs.getString('mushaf:bookmarks:v1'), '[]');
    },
  );
  test(
    'retired Arabic/tajweed/Muyassar paths cannot redownload even when called directly',
    () async {
      var requests = 0;
      final repo = IslamicContentRepository(
        client: MockClient((_) async {
          requests++;
          throw StateError('must not fetch');
        }),
      );
      for (final path in [
        'quran/chapters/ar/1.json',
        'quran/tajweed/1.json',
        'tafseer/muyassar.json',
      ]) {
        await expectLater(repo.readJson(path), throwsStateError);
      }
      expect(requests, 0);
      repo.dispose();
    },
  );
  test(
    'file retirement removes only exact old text paths and preserves English and audio',
    () async {
      final root = await Directory.systemTemp.createTemp('tarteel-migration-');
      try {
        for (final name in [
          'quran/chapters/ar/1.json',
          'quran/tajweed/1.json',
          'tafseer/muyassar.json',
          'quran/chapters/en/1.json',
          'audio/recitation.mp3',
        ]) {
          final f = File('${root.path}/$name');
          await f.parent.create(recursive: true);
          await f.writeAsString(name);
        }
        final removed = await retireLegacyQuranTextFiles(root);
        expect(removed.length, 3);
        expect(
          await File('${root.path}/quran/chapters/en/1.json').exists(),
          true,
        );
        expect(await File('${root.path}/audio/recitation.mp3').exists(), true);
        expect(await retireLegacyQuranTextFiles(root), isEmpty);
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'topical coverage uses real tags and leaves unknown ayahs uncolored',
    () async {
      final index = await MushafTopicIndex.load();
      final q = await TarteelCanonicalQuran.load();
      final result = ThematicCoverageValidator.validate(index, q);
      expect(result['topics'], 6100);
      expect(result['links'], 19117);
      expect(result['covered'], 3673);
      expect(result['uncovered'], 2563);
      final resolver = ThematicPassageResolver(index);
      final empty = q.ayahs.firstWhere(
        (a) => resolver.forAyah(a.verseKey).isEmpty,
      );
      expect(resolver.marks([empty.verseKey]), isEmpty);
    },
  );
}
