import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/mushaf_store.dart';
import 'package:tarteel/src/quran_models.dart';
import 'package:tarteel/src/tajweed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const verse = QuranVerse(
    globalNumber: 1,
    surahNumber: 1,
    ayahNumber: 1,
    verseKey: '1:1',
    textUthmani: 'بِسۡمِ ٱللَّهِ',
    textTajweed: '[h[بِسۡمِ] [n[ٱللَّهِ]',
    juzNumber: 1,
    pageNumber: 1,
    rukuNumber: 1,
    surahNameAr: 'الفاتحة',
    surahNameEn: 'Al-Fatihah',
  );

  test('Quran passage preserves page, tajweed, and verse identity', () {
    final passage = QuranPassage.fromJson(<String, dynamic>{
      'mode': 'page',
      'number': 1,
      'source': 'TEST',
      'total_pages': 604,
      'tajweed_available': true,
      'verses': <Map<String, dynamic>>[
        <String, dynamic>{
          'global_number': 1,
          'surah_number': 1,
          'ayah_number': 1,
          'verse_key': '1:1',
          'text_uthmani': verse.textUthmani,
          'text_tajweed': verse.textTajweed,
          'juz_number': 1,
          'page_number': 1,
          'ruku_number': 1,
          'surah_name_ar': 'الفاتحة',
          'surah_name_en': 'Al-Fatihah',
        },
      ],
      'theme_sections': <Map<String, dynamic>>[],
    });

    expect(passage.mode, QuranBrowseMode.page);
    expect(passage.number, 1);
    expect(passage.totalPages, 604);
    expect(passage.tajweedAvailable, isTrue);
    expect(passage.verses.single.verseKey, '1:1');
    expect(passage.verses.single.textTajweed, isNotEmpty);
  });

  test(
    'last position, bookmarks, and reader settings survive restart',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = MushafStore(preferences)..load();

      await store.setLastPosition(
        const MushafPosition(
          mode: QuranBrowseMode.page,
          number: 1,
          verseKey: '1:1',
          surahNumber: 1,
          ayahNumber: 1,
          pageNumber: 1,
        ),
      );
      await store.toggleBookmark(verse);
      await store.setFontScale(1.4);
      await store.setShowTajweed(false);
      await store.setShowThemes(true);

      final restored = MushafStore(preferences)..load();
      expect(restored.lastPosition?.mode, QuranBrowseMode.page);
      expect(restored.lastPosition?.verseKey, '1:1');
      expect(restored.isBookmarked('1:1'), isTrue);
      expect(restored.fontScale, 1.4);
      expect(restored.showTajweed, isFalse);
      expect(restored.showThemes, isTrue);
    },
  );

  test('tajweed rendering never changes the Quran text', () {
    final plain = TajweedMarkup.plainText(verse.textTajweed!);
    final spans = TajweedMarkup.spans(
      verse.textTajweed!,
      const TextStyle(),
      const ColorScheme.light(),
    );
    final rendered = spans
        .whereType<TextSpan>()
        .map((span) => span.text ?? '')
        .join();

    expect(plain, verse.textUthmani);
    expect(rendered, verse.textUthmani);
    expect(arabicIndicNumber(604), '٦٠٤');
  });
}
