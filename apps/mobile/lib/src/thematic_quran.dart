import 'package:flutter/material.dart';
import 'canonical_quran.dart';
import 'mushaf_library.dart';
import 'surah_content.dart';

class ThematicSourceRegistry {
  static const source = 'Quranpedia';
  static const url = 'https://quranpedia.net/dumps';
  static const version = '2026-10-24';
  static const kind = 'overlapping_ayah_tags';
  static const notice =
      'وسوم موضوعية مرتبطة بالآيات؛ ليست تقسيمًا متصلًا لكل القرآن.';
}

class ThematicMark {
  const ThematicMark(this.topic, this.colorValue);
  final MushafTopic topic;
  final int colorValue;
}

class ThematicColorMapper {
  static const palette = [
    0xffe1ece8,
    0xfff2e5cf,
    0xffdce7f1,
    0xffeae1ed,
    0xffd8eceb,
    0xfff0dfd7,
  ];
  int color(int identity) => palette[identity.abs() % palette.length];
}

class ThematicPassageResolver {
  ThematicPassageResolver(this.index);
  final MushafTopicIndex index;
  List<MushafTopic> forAyah(String id) =>
      index.forVerse(id.startsWith('hafs:') ? id.substring(5) : id);
  Map<String, ThematicMark> marks(Iterable<String> keys) {
    final map = <String, ThematicMark>{};
    final colors = ThematicColorMapper();
    for (final key in keys) {
      final topics = forAyah(key);
      if (topics.isEmpty) continue;
      final topic = topics.first;
      var root = topic;
      while (root.parentId != null) {
        root = index.byId[root.parentId!]!;
      }
      map[key] = ThematicMark(topic, colors.color(root.id));
    }
    return map;
  }
}

class ThematicCoverageValidator {
  static Map<String, num> validate(
    MushafTopicIndex index,
    TarteelCanonicalQuran quran,
  ) {
    final valid = quran.ayahs.map((a) => a.verseKey).toSet();
    final counts = <String, int>{};
    var links = 0;
    for (final t in index.topics) {
      for (final key in t.verseKeys) {
        if (!valid.contains(key))
          throw const FormatException('THEMATIC_UNKNOWN_AYAH');
        counts[key] = (counts[key] ?? 0) + 1;
        links++;
      }
    }
    return {
      'topics': index.topics.length,
      'links': links,
      'covered': counts.length,
      'uncovered': valid.length - counts.length,
      'overlapping': counts.values.where((v) => v > 1).length,
      'coverage_percent': 100 * counts.length / valid.length,
    };
  }
}

class ThematicTafsirResolver {
  ThematicTafsirResolver(this.api);
  final SurahApiClient api;
  Future<List<SurahContentEntry>> forAyah(
    String project,
    int surah,
    int ayah,
  ) => api.read(project, [surah, ayah]);
}

class ThematicAyahPanel extends StatelessWidget {
  const ThematicAyahPanel({super.key, required this.verseKey});
  final String verseKey;
  @override
  Widget build(BuildContext context) => FutureBuilder<MushafTopicIndex>(
    future: MushafTopicIndex.load(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox.shrink();
      final topics = ThematicPassageResolver(snapshot.data!).forAyah(verseKey);
      return ExpansionTile(
        title: const Text('التفسير الموضوعي'),
        subtitle: Text(
          topics.isEmpty
              ? 'لا يوجد تصنيف موثق لهذه الآية'
              : '${topics.length} موضوعًا مرتبطًا بالآية',
        ),
        children: [
          const ListTile(
            title: Text(ThematicSourceRegistry.notice),
            subtitle: Text('Quranpedia • تغطية3673 من6236آية (58.9%)'),
          ),
          for (final t in topics)
            ListTile(
              title: Text(t.title),
              subtitle: Text(
                '${snapshot.data!.ancestry(t)}\nوسم مرتبط بـ${t.verseKeys.length} آية؛ لا يُفترض اتصالها.',
              ),
            ),
          const ListTile(subtitle: SelectableText(ThematicSourceRegistry.url)),
        ],
      );
    },
  );
}
