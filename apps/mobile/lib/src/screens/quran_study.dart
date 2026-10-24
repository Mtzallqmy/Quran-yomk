import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common.dart';
import '../learning.dart';
import '../models.dart';
import '../navigation.dart';
import '../quran_models.dart';
import '../services.dart';
import 'learning.dart';
import 'quran_translations.dart';
import 'quran_index.dart' show normalizeQuranQuery;

/// Reads the existing repository/cache; never rewrites Quran text.
class QuranStudyPage extends ConsumerStatefulWidget {
  const QuranStudyPage({super.key});
  @override
  ConsumerState<QuranStudyPage> createState() => _QuranStudyPageState();
}

class _QuranStudyPageState extends ConsumerState<QuranStudyPage> {
  late Future<List<Surah>> _surahs;
  Future<QuranPassage>? _passage;
  Surah? _selected;
  int _start = 1, _end = 1;
  String _query = '';
  @override
  void initState() {
    super.initState();
    _surahs = ref.read(servicesProvider).repository.surahs();
  }

  void _select(Surah s) => setState(() {
    _selected = s;
    _start = 1;
    _end = s.ayahCount.clamp(1, 10);
    _passage = ref
        .read(servicesProvider)
        .repository
        .quranPassage(QuranBrowseMode.surah, s.number);
  });
  Widget _number(bool start, Surah s) => Expanded(
    child: DropdownButtonFormField<int>(
      key: ValueKey('${s.number}-$start-$_start-$_end'),
      initialValue: start ? _start : _end,
      decoration: InputDecoration(labelText: start ? 'من الآية' : 'إلى الآية'),
      items: [
        for (var i = start ? 1 : _start; i <= s.ayahCount; i++)
          DropdownMenuItem(value: i, child: Text('$i')),
      ],
      onChanged: (v) => setState(() {
        if (start) {
          _start = v!;
          if (_end < _start) _end = _start;
        } else {
          _end = v!;
        }
      }),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('القراءة والحفظ والبحث في الآيات')),
    body: FutureBuilder<List<Surah>>(
      future: _surahs,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return ErrorPane(
            error: snapshot.error!,
            onRetry: () => setState(
              () => _surahs = ref.read(servicesProvider).repository.surahs(),
            ),
          );
        if (!snapshot.hasData) return const LoadingPane();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'اختر أي سورة ومقطع للحفظ. البحث يتجاهل التشكيل واختلاف الهمزات داخل السورة المختارة. السورة المحفوظة في الجهاز متاحة دون اتصال.',
            ),
            DropdownButtonFormField<Surah>(
              initialValue: _selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'السورة'),
              items: [
                for (final s in snapshot.data!)
                  DropdownMenuItem(
                    value: s,
                    child: Text('${s.number}. ${s.nameAr}'),
                  ),
              ],
              onChanged: (s) {
                if (s != null) _select(s);
              },
            ),
            if (_selected case final Surah s) ...[
              QuranTranslationsPane(surah: s.number),
              Row(
                children: [
                  _number(true, s),
                  const SizedBox(width: 12),
                  _number(false, s),
                ],
              ),
              FilledButton.icon(
                icon: const Icon(Icons.school_outlined),
                label: const Text('ابدأ حفظ المقطع'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => MemorizationSessionPage(
                      segment: ThematicSegment(
                        surah: s.number,
                        startAyah: _start,
                        endAyah: _end,
                        topicTitleAr: '${s.nameAr} — $_start إلى $_end',
                        topicSummaryAr: 'مقطع اختاره المستخدم',
                        colorToken: 'blue',
                        source: 'اختيار شخصي؛ النص من المصدر الحالي',
                        reviewStatus: 'user_selection',
                      ),
                    ),
                  ),
                ),
              ),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'بحث في آيات السورة',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              FutureBuilder<QuranPassage>(
                future: _passage,
                builder: (context, p) {
                  if (p.hasError)
                    return ErrorPane(
                      error: p.error!,
                      onRetry: () => _select(s),
                    );
                  if (p.connectionState != ConnectionState.done || !p.hasData)
                    return const LoadingPane();
                  final query = normalizeQuranQuery(_query);
                  final verses = p.data!.verses
                      .where(
                        (v) => query.isEmpty
                            ? v.ayahNumber >= _start && v.ayahNumber <= _end
                            : normalizeQuranQuery(
                                v.textUthmani,
                              ).contains(query),
                      )
                      .toList();
                  return Column(
                    children: [
                      Text('${verses.length} آيات'),
                      for (final v in verses)
                        Card(
                          child: ListTile(
                            title: Text(
                              v.textUthmani,
                              textDirection: TextDirection.rtl,
                            ),
                            subtitle: Text(
                              '${v.surahNameAr} • ${v.ayahNumber} • صفحة ${v.pageNumber}',
                            ),
                            trailing: IconButton(
                              tooltip: 'الإشارة المرجعية',
                              icon: Icon(
                                ref
                                        .read(servicesProvider)
                                        .mushaf
                                        .isBookmarked(v.verseKey)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                              ),
                              onPressed: () async {
                                await ref
                                    .read(servicesProvider)
                                    .mushaf
                                    .toggleBookmark(v);
                                if (mounted) setState(() {});
                              },
                            ),
                            onTap: () => Navigator.pushNamed(
                              context,
                              MobileRoutes.reader,
                              arguments: v.pageNumber,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    ),
  );
}
