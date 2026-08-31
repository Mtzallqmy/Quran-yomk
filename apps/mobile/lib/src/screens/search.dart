import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'radio.dart';
import 'reciters.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final controller = TextEditingController();
  Timer? debounce;
  SearchBundle result = const SearchBundle(
    stations: <Station>[],
    reciters: <Reciter>[],
    surahs: <Surah>[],
  );
  List<Category> categoryResults = const <Category>[];
  bool loading = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialQuery?.trim() ?? '';
    if (initial.isNotEmpty) {
      controller.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => runSearch(initial));
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (!mounted) return;
      setState(() {
        result = const SearchBundle(
          stations: <Station>[],
          reciters: <Reciter>[],
          surahs: <Surah>[],
        );
        categoryResults = const <Category>[];
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final repo = ref.read(servicesProvider).repository;
      final values = await Future.wait<dynamic>([
        repo.search(trimmed),
        repo.categories(),
      ]);
      final next = values[0] as SearchBundle;
      final categories = values[1] as List<Category>;
      final normalized = _normalize(trimmed);
      final matchedCategories = categories.where((category) {
        final haystack = _normalize('${category.nameAr} ${category.nameEn ?? ''} ${category.slug}');
        return haystack.contains(normalized);
      }).toList(growable: false);
      if (mounted) {
        setState(() {
          result = next;
          categoryResults = matchedCategories;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _playStation(Station station) async {
    final url = station.playbackUrl;
    if (url == null || url.isEmpty) {
      _message('هذه المحطة غير متاحة للتشغيل حاليًا.');
      return;
    }
    if (Uri.tryParse(url)?.scheme != 'https') {
      _message('هذه المحطة تستخدم رابط HTTP غير آمن ولا يمكن تشغيلها في نسخة Android الحالية.');
      return;
    }
    try {
      await ref.read(servicesProvider).playback.playStation(station);
      if (mounted) _message('جارٍ تشغيل ${station.nameAr}');
    } catch (_) {
      _message('تعذر تشغيل ${station.nameAr}. حاول مرة أخرى.');
    }
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final total = result.stations.length +
        result.reciters.length +
        result.surahs.length +
        categoryResults.length;
    return Scaffold(
      appBar: AppBar(title: const Text('البحث في ترتيل')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              autofocus: widget.initialQuery == null,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح',
                            onPressed: () {
                              controller.clear();
                              runSearch('');
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                hintText: 'محطة، قارئ، سورة، تفسير، أذكار…',
              ),
              onChanged: (value) {
                setState(() {});
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => runSearch(value),
                );
              },
              onSubmitted: runSearch,
            ),
          ),
          if (error != null)
            Expanded(
              child: ErrorPane(
                error: error!,
                onRetry: () => runSearch(controller.text),
              ),
            )
          else if (controller.text.trim().length < 2)
            const Expanded(
              child: EmptyPane(message: 'اكتب حرفين على الأقل للبحث'),
            )
          else if (!loading && total == 0)
            const Expanded(child: EmptyPane(message: 'لا توجد نتائج'))
          else
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  if (categoryResults.isNotEmpty) ...<Widget>[
                    const SectionHeader('الأقسام'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categoryResults
                            .map(
                              (category) => ActionChip(
                                avatar: const Icon(Icons.grid_view_outlined, size: 18),
                                label: Text(category.nameAr),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RadioPage(initialCategory: category.slug),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                  if (result.stations.isNotEmpty) ...<Widget>[
                    const SectionHeader('الإذاعات'),
                    for (final station in result.stations)
                      ListTile(
                        leading: Artwork(url: station.logoUrl),
                        title: Text(station.nameAr),
                        subtitle: Text(
                          <String?>[
                            station.providerName ?? station.provider,
                            station.category,
                            station.healthStatus,
                          ].whereType<String>().join(' • '),
                        ),
                        onTap: station.isPlayable ? () => _playStation(station) : null,
                        trailing: IconButton.filledTonal(
                          tooltip: station.isPlayable ? 'تشغيل' : 'غير متاح',
                          onPressed: station.isPlayable ? () => _playStation(station) : null,
                          icon: const Icon(Icons.play_arrow),
                        ),
                      ),
                  ],
                  if (result.reciters.isNotEmpty) ...<Widget>[
                    const SectionHeader('القراء'),
                    for (final reciter in result.reciters)
                      ListTile(
                        leading: Artwork(
                          url: reciter.imageUrl,
                          icon: Icons.person_outline,
                        ),
                        title: Text(reciter.nameAr),
                        subtitle: reciter.rewaya == null ? null : Text(reciter.rewaya!),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReciterDetailPage(reciter: reciter),
                          ),
                        ),
                      ),
                  ],
                  if (result.surahs.isNotEmpty) ...<Widget>[
                    const SectionHeader('السور'),
                    for (final surah in result.surahs)
                      ListTile(
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text(surah.nameAr),
                        subtitle: Text('${surah.nameEn} • ${surah.ayahCount} آية'),
                        trailing: const Icon(Icons.search),
                        onTap: () {
                          controller.text = surah.nameAr;
                          controller.selection = TextSelection.collapsed(offset: controller.text.length);
                          runSearch(surah.nameAr);
                        },
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
    .replaceAll('ـ', '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
