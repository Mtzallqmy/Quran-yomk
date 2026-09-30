import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../navigation.dart';
import '../quran_models.dart';
import '../services.dart';

class QuranIndexPage extends ConsumerStatefulWidget {
  const QuranIndexPage({super.key});
  @override
  ConsumerState<QuranIndexPage> createState() => _QuranIndexPageState();
}

class _QuranIndexPageState extends ConsumerState<QuranIndexPage> {
  late Future<List<Surah>> _surahs;
  int _section = 0;
  String _query = '';
  bool _opening = false;
  @override
  void initState() {
    super.initState();
    _surahs = ref.read(servicesProvider).repository.surahs();
  }

  Future<void> _open(QuranBrowseMode mode, int number) async {
    if (_opening) return;
    if (mode == QuranBrowseMode.page) {
      await Navigator.pushNamed(
        context,
        MobileRoutes.reader,
        arguments: number,
      );
      return;
    }
    setState(() => _opening = true);
    try {
      final passage = await ref
          .read(servicesProvider)
          .repository
          .quranPassage(mode, number);
      if (!mounted) return;
      if (passage.verses.isEmpty) throw StateError('لا توجد صفحات متاحة');
      await Navigator.pushNamed(
        context,
        MobileRoutes.reader,
        arguments: passage.verses.first.pageNumber,
      );
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الصفحة. حاول مرة أخرى.')),
        );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(servicesProvider).mushaf;
    return AnimatedBuilder(
      animation: store,
      builder: (_, _) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث عن سورة أو رقم',
              ),
              onChanged: (value) =>
                  setState(() => _query = normalizeQuranQuery(value)),
            ),
          ),
          if (store.lastPosition case final position?)
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('متابعة القراءة'),
              subtitle: Text(
                'السورة ${position.surahNumber ?? position.number}${position.pageNumber == null ? '' : ' • الصفحة ${position.pageNumber}'}',
              ),
              onTap: () => _open(
                position.pageNumber == null
                    ? position.mode
                    : QuranBrowseMode.page,
                position.pageNumber ?? position.number,
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final (index, label) in [
                    'السور',
                    'الأجزاء',
                    'الصفحات',
                    'العلامات',
                  ].indexed)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _section == index,
                        onSelected: (_) => setState(() => _section = index),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_opening) const LinearProgressIndicator(),
          Expanded(
            child: switch (_section) {
              0 => FutureBuilder<List<Surah>>(
                future: _surahs,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return ErrorPane(
                      error: snapshot.error!,
                      onRetry: () => setState(() {
                        _surahs = ref
                            .read(servicesProvider)
                            .repository
                            .surahs(refresh: true);
                      }),
                    );
                  if (!snapshot.hasData) return const LoadingPane();
                  final values = snapshot.data!
                      .where(
                        (s) => normalizeQuranQuery(
                          '${s.nameAr} ${s.nameEn} ${s.number}',
                        ).contains(_query),
                      )
                      .toList();
                  if (values.isEmpty)
                    return const EmptyPane(message: 'لا توجد سور مطابقة');
                  return ListView.builder(
                    key: const PageStorageKey('quran-surahs'),
                    itemCount: values.length,
                    itemBuilder: (context, index) {
                      final surah = values[index];
                      return ListTile(
                        key: ValueKey('surah-${surah.number}'),
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text(surah.nameAr),
                        subtitle: Text('${surah.ayahCount} آية'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: _opening
                            ? null
                            : () => _open(QuranBrowseMode.surah, surah.number),
                      );
                    },
                  );
                },
              ),
              1 => _numbers(30, QuranBrowseMode.juz, 'الجزء'),
              2 => _numbers(604, QuranBrowseMode.page, 'الصفحة'),
              _ =>
                store.bookmarks.isEmpty
                    ? const EmptyPane(message: 'لا توجد علامات مرجعية بعد')
                    : ListView.builder(
                        key: const PageStorageKey('quran-bookmarks'),
                        itemCount: store.bookmarks.length,
                        itemBuilder: (context, index) {
                          final mark = store.bookmarks[index];
                          return ListTile(
                            key: ValueKey(mark.verseKey),
                            leading: const Icon(Icons.bookmark),
                            title: Text(
                              'السورة ${mark.surahNumber} • الآية ${mark.ayahNumber}',
                            ),
                            subtitle: Text('الصفحة ${mark.pageNumber}'),
                            onTap: () =>
                                _open(QuranBrowseMode.page, mark.pageNumber),
                          );
                        },
                      ),
            },
          ),
        ],
      ),
    );
  }

  Widget _numbers(int count, QuranBrowseMode mode, String label) {
    final values = List.generate(
      count,
      (index) => index + 1,
    ).where((number) => '$number'.contains(_query)).toList();
    return ListView.builder(
      key: PageStorageKey(mode.name),
      itemCount: values.length,
      itemBuilder: (context, index) => ListTile(
        key: ValueKey('${mode.name}-${values[index]}'),
        title: Text('$label ${values[index]}'),
        trailing: const Icon(Icons.chevron_left),
        onTap: _opening ? null : () => _open(mode, values[index]),
      ),
    );
  }
}

String normalizeQuranQuery(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp('[\\u064B-\\u065F\\u0670\\u0640]'), '')
    .replaceAllMapped(
      RegExp('[٠-٩]'),
      (match) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(match[0]!)}',
    );
