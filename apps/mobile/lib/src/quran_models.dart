import 'models.dart';

enum QuranBrowseMode { surah, juz, page }

class QuranVerse {
  const QuranVerse({
    required this.globalNumber,
    required this.surahNumber,
    required this.ayahNumber,
    required this.verseKey,
    required this.textUthmani,
    required this.juzNumber,
    required this.pageNumber,
    required this.rukuNumber,
    required this.surahNameAr,
    required this.surahNameEn,
    this.textTajweed,
    this.hizbQuarter,
    this.sajda = false,
  });

  final int globalNumber;
  final int surahNumber;
  final int ayahNumber;
  final String verseKey;
  final String textUthmani;
  final String? textTajweed;
  final int juzNumber;
  final int pageNumber;
  final int rukuNumber;
  final int? hizbQuarter;
  final bool sajda;
  final String surahNameAr;
  final String surahNameEn;

  factory QuranVerse.fromJson(JsonMap json) => QuranVerse(
        globalNumber: (json['global_number'] as num?)?.toInt() ?? 0,
        surahNumber: (json['surah_number'] as num?)?.toInt() ?? 0,
        ayahNumber: (json['ayah_number'] as num?)?.toInt() ?? 0,
        verseKey: json['verse_key'] as String? ?? '',
        textUthmani: json['text_uthmani'] as String? ?? '',
        textTajweed: json['text_tajweed'] as String?,
        juzNumber: (json['juz_number'] as num?)?.toInt() ?? 0,
        pageNumber: (json['page_number'] as num?)?.toInt() ?? 0,
        rukuNumber: (json['ruku_number'] as num?)?.toInt() ?? 0,
        hizbQuarter: (json['hizb_quarter'] as num?)?.toInt(),
        sajda: json['sajda'] == true,
        surahNameAr: json['surah_name_ar'] as String? ?? '',
        surahNameEn: json['surah_name_en'] as String? ?? '',
      );
}

class QuranThemeSection {
  const QuranThemeSection({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
    required this.titleAr,
    required this.titleEn,
    required this.colorKey,
    required this.rukuNumber,
  });

  final int surahNumber;
  final int fromAyah;
  final int toAyah;
  final String titleAr;
  final String titleEn;
  final String colorKey;
  final int rukuNumber;

  factory QuranThemeSection.fromJson(JsonMap json) => QuranThemeSection(
        surahNumber: (json['surah_number'] as num?)?.toInt() ?? 0,
        fromAyah: (json['from_ayah'] as num?)?.toInt() ?? 0,
        toAyah: (json['to_ayah'] as num?)?.toInt() ?? 0,
        titleAr: json['title_ar'] as String? ?? '',
        titleEn: json['title_en'] as String? ?? '',
        colorKey: json['color_key'] as String? ?? 'theme_0',
        rukuNumber: (json['ruku_number'] as num?)?.toInt() ?? 0,
      );

  bool contains(QuranVerse verse) =>
      verse.surahNumber == surahNumber &&
      verse.ayahNumber >= fromAyah &&
      verse.ayahNumber <= toAyah;
}

class QuranPassage {
  const QuranPassage({
    required this.mode,
    required this.number,
    required this.source,
    required this.verses,
    required this.themeSections,
    this.totalPages = 604,
    this.tajweedAvailable = false,
  });

  final QuranBrowseMode mode;
  final int number;
  final String source;
  final List<QuranVerse> verses;
  final List<QuranThemeSection> themeSections;
  final int totalPages;
  final bool tajweedAvailable;

  factory QuranPassage.fromJson(JsonMap json) => QuranPassage(
        mode: QuranBrowseMode.values.firstWhere(
          (value) => value.name == (json['mode'] as String? ?? 'surah'),
          orElse: () => QuranBrowseMode.surah,
        ),
        number: (json['number'] as num?)?.toInt() ?? 1,
        source: json['source'] as String? ?? 'UNKNOWN',
        verses: jsonList(json['verses'])
            .map((item) => QuranVerse.fromJson(jsonMap(item)))
            .toList(growable: false),
        themeSections: jsonList(json['theme_sections'])
            .map((item) => QuranThemeSection.fromJson(jsonMap(item)))
            .toList(growable: false),
        totalPages: (json['total_pages'] as num?)?.toInt() ?? 604,
        tajweedAvailable: json['tajweed_available'] == true,
      );
}

class QuranAudioReciter {
  const QuranAudioReciter({
    required this.id,
    required this.providerReciterId,
    required this.moshafId,
    required this.nameAr,
    required this.nameEn,
    required this.rewayaAr,
    required this.rewayaEn,
    required this.availableSurahs,
    this.imageUrl,
  });

  final String id;
  final int providerReciterId;
  final int moshafId;
  final String nameAr;
  final String nameEn;
  final String rewayaAr;
  final String rewayaEn;
  final Set<int> availableSurahs;
  final String? imageUrl;

  factory QuranAudioReciter.fromJson(JsonMap json) => QuranAudioReciter(
        id: json['id'] as String? ?? '',
        providerReciterId:
            (json['provider_reciter_id'] as num?)?.toInt() ?? 0,
        moshafId: (json['moshaf_id'] as num?)?.toInt() ?? 0,
        nameAr: json['name_ar'] as String? ?? '',
        nameEn: json['name_en'] as String? ?? '',
        rewayaAr: json['rewaya_ar'] as String? ?? '',
        rewayaEn: json['rewaya_en'] as String? ?? '',
        availableSurahs: jsonList(json['available_surahs'])
            .map((value) => (value as num).toInt())
            .toSet(),
        imageUrl: json['image_url'] as String?,
      );

  Reciter toReciter() => Reciter(
        id: id,
        slug: id,
        nameAr: nameAr,
        nameEn: nameEn,
        imageUrl: imageUrl,
        rewaya: rewayaAr,
      );
}

class QuranAudioTrack {
  const QuranAudioTrack({
    required this.surahNumber,
    required this.playbackUrl,
    required this.surah,
  });

  final int surahNumber;
  final String playbackUrl;
  final Surah surah;

  factory QuranAudioTrack.fromJson(JsonMap json) => QuranAudioTrack(
        surahNumber: (json['surah_number'] as num?)?.toInt() ?? 0,
        playbackUrl: json['playback_url'] as String? ?? '',
        surah: Surah.fromJson(jsonMap(json['surah'])),
      );

  ReciterTrack toTrack(String reciterId) => ReciterTrack(
        id: 'quran:$reciterId:$surahNumber',
        surah: surah,
        format: 'mp3',
        playbackUrl: playbackUrl,
      );
}
