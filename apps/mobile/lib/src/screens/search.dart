import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../navigation.dart';
import '../feature_manager.dart';
import '../quran_models.dart';
import 'reciters.dart';
import '../quran_audio.dart';
import '../services.dart';
import 'legacy_reciter_detail.dart';
import 'radio.dart';

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
  List<QuranAudioCatalogReciter> audioReciters =
      const <QuranAudioCatalogReciter>[];
  List<Surah> localSurahs = const <Surah>[];
  int _request = 0;
  int _filter = 0;
  bool loading = false;
  Object? error;
  String? pendingStationId;

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
    final request = ++_request;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        result = const SearchBundle(
          stations: <Station>[],
          reciters: <Reciter>[],
          surahs: <Surah>[],
        );
        categoryResults = const <Category>[];
        audioReciters = const <QuranAudioCatalogReciter>[];
        localSurahs = const <Surah>[];
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
      final services = ref.read(servicesProvider);
      final repo = services.repository;
      final values = await Future.wait<dynamic>([
        repo.search(trimmed),
        repo.categories(),
        repo.surahs(),
        services.quranAudio.reciters(),
      ]);
      final next = values[0] as SearchBundle;
      final categories = values[1] as List<Category>;
      final surahs = values[2] as List<Surah>;
      final catalog = values[3] as List<QuranAudioCatalogReciter>;
      final normalized = _normalize(trimmed);
      final matchedCategories = categories
          .where((category) {
            final haystack = _normalize(
              '${category.nameAr} ${category.nameEn ?? ''} ${category.slug}',
            );
            return haystack.contains(normalized);
          })
          .toList(growable: false);
      final matchedSurahs = surahs
          .where((surah) {
            return _normalize('${surah.nameAr} ${surah.nameEn} ${surah.number}')
                .contains(normalized);
          })
          .toList(growable: false);
      final byIdentity = <String, QuranAudioCatalogReciter>{};
      for (final reciter in catalog) {
        final haystack = _normalize(
          '${reciter.nameAr} ${reciter.nameEn} ${reciter.riwayah ?? ''}',
        );
        if (haystack.contains(normalized)) {
          byIdentity.putIfAbsent(reciter.identityKey, () => reciter);
        }
      }
      if (mounted && request == _request) {
        setState(() {
          result = next;
          categoryResults = matchedCategories;
          audioReciters = byIdentity.values.take(30).toList(growable: false);
          localSurahs = matchedSurahs;
        });
      }
    } catch (e) {
      if (mounted && request == _request) setState(() => error = e);
    } finally {
      if (mounted && request == _request) setState(() => loading = false);
    }
  }

  Future<void> _playStation(Station station) async {
    if (!_canPlay(station)) {
      _playbackError(station);
      return;
    }
    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (e) {
      debugPrint('Tarteel search playback error: $e');
      _playbackError(station);
    } finally {
      if (mounted && pendingStationId == station.id) {
        setState(() => pendingStationId = null);
      }
    }
  }

  void _playbackError(Station station) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر تشغيل ${station.nameAr}.'),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          onPressed: () => _playStation(station),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final total =
        result.stations.length +
        result.reciters.length +
        result.surahs.length +
        categoryResults.length +
        audioReciters.length +
        localSurahs.length;

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
                hintText: 'سورة، قارئ، إذاعة…',
              ),
              onChanged: (value) {
                _request++; // Invalidate old results as soon as input changes.
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (index, label) in [
                  'الكل',
                  'القرآن',
                  'القراء',
                  'الإذاعات',
                ].indexed)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == index,
                      onSelected: (_) => setState(() => _filter = index),
                    ),
                  ),
              ],
            ),
          ),
          if (error != null)
            Expanded(
              child: ErrorPane(
                error: error!,
                onRetry: () => runSearch(controller.text),
              ),
            )
          else if (controller.text.trim().isEmpty)
            const Expanded(
              child: EmptyPane(message: 'ابحث عن سورة أو قارئ أو إذاعة'),
            )
          else if (!loading && total == 0)
            const Expanded(child: EmptyPane(message: 'لا توجد نتائج'))
          else
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: <Widget>[
                  if ((_filter == 0 || _filter == 3) &&
                      services.features.enabled(TarteelFeature.radio) &&
                      categoryResults.isNotEmpty) ...<Widget>[
                    const SectionHeader('الأقسام'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categoryResults
                            .map(
                              (category) => ActionChip(
                                avatar: const Icon(
                                  Icons.grid_view_outlined,
                                  size: 18,
                                ),
                                label: Text(category.nameAr),
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => RadioPage(
                                      initialCategory: category.slug,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                  ],
                  if ((_filter == 0 || _filter == 3) &&
                      services.features.enabled(TarteelFeature.radio) &&
                      result.stations.isNotEmpty) ...<Widget>[
                    const SectionHeader('الإذاعات'),
                    for (final station in result.stations)
                      AnimatedBuilder(
                        animation: services.favorites,
                        builder: (context, _) => ListTile(
                          leading: Artwork(url: station.logoUrl),
                          title: Text(
                            station.nameAr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              IconButton(
                                tooltip: 'المفضلة',
                                onPressed: () => services.favorites
                                    .toggleStation(station.id),
                                icon: Icon(
                                  services.favorites.isStation(station.id)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                ),
                              ),
                              if (pendingStationId == station.id)
                                const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                IconButton.filledTonal(
                                  tooltip: 'تشغيل',
                                  onPressed: _canPlay(station)
                                      ? () => _playStation(station)
                                      : null,
                                  icon: const Icon(Icons.play_arrow),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                  if ((_filter == 0 || _filter == 2) &&
                      audioReciters.isNotEmpty) ...<Widget>[
                    const SectionHeader('قراء التلاوات'),
                    for (final reciter in audioReciters)
                      ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.record_voice_over_outlined),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                QuranAudioReciterDetailPage(reciter: reciter),
                          ),
                        ),
                        title: Text(reciter.nameAr),
                        subtitle: Text(
                          <String>[
                            if (reciter.nameEn.isNotEmpty) reciter.nameEn,
                            if (reciter.riwayah?.isNotEmpty == true)
                              reciter.riwayah!,
                          ].join(' • '),
                        ),
                        trailing: Text(
                          '${reciter.availableSurahs.length} سورة',
                        ),
                      ),
                  ],
                  if ((_filter == 0 || _filter == 2) &&
                      result.reciters.isNotEmpty) ...<Widget>[
                    const SectionHeader('القراء المفهرسون'),
                    for (final reciter in result.reciters)
                      ListTile(
                        leading: Artwork(
                          url: reciter.imageUrl,
                          icon: Icons.person_outline,
                        ),
                        title: Text(reciter.nameAr),
                        subtitle: reciter.rewaya == null
                            ? null
                            : Text(reciter.rewaya!),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReciterDetailPage(reciter: reciter),
                          ),
                        ),
                      ),
                  ],
                  if ((_filter == 0 || _filter == 1) &&
                      {
                        ...result.surahs,
                        ...localSurahs,
                      }.isNotEmpty) ...<Widget>[
                    const SectionHeader('السور'),
                    for (final surah in <int, Surah>{
                      for (final value in [...result.surahs, ...localSurahs])
                        value.number: value,
                    }.values)
                      ListTile(
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text(surah.nameAr),
                        subtitle: Text(
                          '${surah.nameEn} • ${surah.ayahCount} آية',
                        ),
                        trailing: const Icon(Icons.menu_book_outlined),
                        onTap: () async {
                          try {
                            final passage = await services.repository
                                .quranPassage(
                                  QuranBrowseMode.surah,
                                  surah.number,
                                );
                            if (!context.mounted || passage.verses.isEmpty)
                              return;
                            await Navigator.pushNamed(
                              context,
                              MobileRoutes.reader,
                              arguments: passage.verses.first.pageNumber,
                            );
                          } catch (_) {
                            if (context.mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر فتح السورة'),
                                ),
                              );
                          }
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

bool _canPlay(Station station) {
  final url = station.playbackUrl;
  return station.isPlayable &&
      url != null &&
      Uri.tryParse(url)?.scheme.toLowerCase() == 'https';
}

String _normalize(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
    .replaceAll('ـ', '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
