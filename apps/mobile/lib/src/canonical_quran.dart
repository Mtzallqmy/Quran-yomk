import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'quran_models.dart';

class QuranSourceRights {
  static const publisher = 'مجمع الملك فهد لطباعة المصحف الشريف';
  static const permissionUrl = 'https://qurancomplex.gov.sa/quran-dev/';
  static const notice =
      'الحزمة الرسمية المقدمة لتطوير التطبيقات والبرمجيات؛ جميع الحقوق محفوظة للمصدر. لم يُعدّل النص.';
}

class QuranTextVersion {
  static const id = 'kfgqpc-hafs-v30-canonical-v2';
  static const datasetSha256 =
      '132090d1264257ce816dfe1245014c422e3cd4c491f2397c78447efbe161ee8f';
  static const bundleSha256 =
      'd5b4d84c28b67c69e4bf22a7ee67964caee0dd85207a435650f5c89b0021414e';
}

class QuranEdition {
  const QuranEdition();
  String get riwayah => 'hafs';
  String get version => QuranTextVersion.id;
  String get publisher => QuranSourceRights.publisher;
}

typedef QuranSurah = Surah;
typedef QuranAyah = QuranVerse;

class QuranPageReference {
  const QuranPageReference(this.canonicalId, this.page, this.juz);
  final String canonicalId;
  final int page, juz;
}

/// Word IDs are source-specific; absent official word coordinates are not guessed.
class QuranWord {
  const QuranWord(this.canonicalAyahId, this.source, this.sourceWordNumber);
  final String canonicalAyahId, source;
  final int sourceWordNumber;
}

class TarteelCanonicalQuran {
  TarteelCanonicalQuran._(this.surahs, this.ayahs);
  final List<Surah> surahs;
  final List<QuranVerse> ayahs;
  static Future<TarteelCanonicalQuran>? _bundled;
  static Future<TarteelCanonicalQuran> load() =>
      _bundled ??= _load().catchError((Object error) {
        _bundled = null;
        throw error;
      });
  static Future<TarteelCanonicalQuran> _load() async {
    final data = await rootBundle.load('assets/canonical/hafs-v2.json.gz');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (sha256.convert(bytes).toString() != QuranTextVersion.bundleSha256)
      throw const FormatException('QURAN_BUNDLE_CHECKSUM_MISMATCH');
    return parse(gzip.decode(bytes));
  }

  static TarteelCanonicalQuran parse(List<int> bytes) {
    if (sha256.convert(bytes).toString() != QuranTextVersion.datasetSha256)
      throw const FormatException('QURAN_SOURCE_CHECKSUM_MISMATCH');
    final data = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (data['version'] != '2' ||
        (data['source'] as Map)['provider'] != 'KFGQPC')
      throw const FormatException('QURAN_SOURCE_MISMATCH');
    final surahs = <Surah>[], ayahs = <QuranVerse>[];
    final keys = <String>{};
    var global = 0;
    for (final row in data['surahs'] as List) {
      final number = row['number'] as int;
      if (number != surahs.length + 1)
        throw const FormatException('QURAN_SURAH_ORDER');
      final surah = Surah.fromJson({
        ...Map<String, dynamic>.from(row as Map),
        'id': number,
      });
      surahs.add(surah);
      final verses = row['verses'] as List;
      if (verses.length != surah.ayahCount)
        throw const FormatException('QURAN_AYAH_COUNT');
      for (var i = 0; i < verses.length; i++) {
        final v = Map<String, dynamic>.from(verses[i] as Map);
        final key = '$number:${i + 1}';
        global++;
        if (v['verse_key'] != key ||
            v['canonical_id'] != 'hafs:$key' ||
            v['global_number'] != global ||
            !keys.add(key))
          throw const FormatException('QURAN_IDENTITY');
        ayahs.add(
          QuranVerse.fromJson({
            ...v,
            'surah_number': number,
            'surah_name_ar': surah.nameAr,
            'surah_name_en': surah.nameEn,
          }),
        );
      }
    }
    if (surahs.length != 114 || ayahs.length != 6236)
      throw const FormatException('QURAN_CARDINALITY');
    return TarteelCanonicalQuran._(
      List.unmodifiable(surahs),
      List.unmodifiable(ayahs),
    );
  }

  QuranVerse? ayah(String id) {
    final key = id.startsWith('hafs:') ? id.substring(5) : id;
    return ayahs.where((v) => v.verseKey == key).firstOrNull;
  }

  QuranPassage passage(QuranBrowseMode mode, int number) {
    final max = switch (mode) {
      QuranBrowseMode.surah => 114,
      QuranBrowseMode.page => 604,
      QuranBrowseMode.juz => 30,
    };
    if (number < 1 || number > max) throw RangeError.range(number, 1, max);
    final verses = ayahs
        .where(
          (v) => switch (mode) {
            QuranBrowseMode.surah => v.surahNumber == number,
            QuranBrowseMode.page => v.pageNumber == number,
            QuranBrowseMode.juz => v.juzNumber == number,
          },
        )
        .toList();
    return QuranPassage(
      mode: mode,
      number: number,
      source: 'KFGQPC:${QuranTextVersion.id}',
      verses: verses,
      themeSections: const [],
      tajweedAvailable: false,
    );
  }
}

extension CanonicalAyahIdentity on QuranVerse {
  String get canonicalId => 'hafs:$verseKey';
  bool get hasEmbeddedAyahNumber =>
      RegExp(r'\u06dd[٠-٩0-9]+\s*$').hasMatch(textUthmani);
}
