import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../l10n.dart';
import '../models.dart';
import '../mushaf_store.dart';
import '../quran_audio.dart';
import '../quran_models.dart';
import '../services.dart';
import '../tajweed.dart';

class MushafPage extends ConsumerStatefulWidget {
  const MushafPage({super.key});

  @override
  ConsumerState<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<MushafPage> {
  QuranBrowseMode _mode = QuranBrowseMode.surah;
  int _number = 1;
  late Future<List<Surah>> _surahsFuture;
  late Future<QuranPassage> _passageFuture;
  QuranAudioCatalogReciter? _selectedReciter;
  int _bitrateKbps = 128;
  bool _audioBusy = false;

  @override
  void initState() {
    super.initState();
    final services = ref.read(servicesProvider);
    final last = services.mushaf.lastPosition;
    if (last != null) {
      _mode = last.mode;
      _number = _clampNumber(last.mode, last.number);
    }
    _surahsFuture = services.repository.surahs();
    _passageFuture = services.repository.quranPassage(_mode, _number);
  }

  int _maxFor(QuranBrowseMode mode) => switch (mode) {
    QuranBrowseMode.surah => 114,
    QuranBrowseMode.juz => 30,
    QuranBrowseMode.page => 604,
  };

  int _clampNumber(QuranBrowseMode mode, int value) =>
      value.clamp(1, _maxFor(mode));

  Future<void> _load(
    QuranBrowseMode mode,
    int number, {
    bool refresh = false,
  }) async {
    final next = _clampNumber(mode, number);
    setState(() {
      _mode = mode;
      _number = next;
      _selectedReciter = null;
      _passageFuture = ref
          .read(servicesProvider)
          .repository
          .quranPassage(mode, next, refresh: refresh);
    });
    final passage = await _passageFuture;
    if (!mounted || passage.verses.isEmpty) return;
    await _remember(passage.verses.first);
  }

  Future<void> _remember(QuranVerse verse) => ref
      .read(servicesProvider)
      .mushaf
      .setLastPosition(
        MushafPosition(
          mode: _mode,
          number: _number,
          verseKey: verse.verseKey,
          surahNumber: verse.surahNumber,
          ayahNumber: verse.ayahNumber,
          pageNumber: verse.pageNumber,
        ),
      );

  Future<void> _chooseReciter(int surahNumber) async {
    final l10n = context.l10n;
    final future = ref
        .read(servicesProvider)
        .quranAudio
        .reciters(surahNumber: surahNumber);
    final selected = await showModalBottomSheet<QuranAudioCatalogReciter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: FutureBuilder<List<QuranAudioCatalogReciter>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 260,
                child: ErrorPane(
                  error: snapshot.error!,
                  onRetry: () => Navigator.pop(context),
                ),
              );
            }
            final values = snapshot.data ?? const <QuranAudioCatalogReciter>[];
            if (values.isEmpty) {
              return SizedBox(
                height: 260,
                child: EmptyPane(message: l10n.noReciters),
              );
            }
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.72,
              minChildSize: 0.45,
              maxChildSize: 0.92,
              builder: (context, controller) => ListView.builder(
                controller: controller,
                itemCount: values.length,
                itemBuilder: (context, index) {
                  final reciter = values[index];
                  final english =
                      Localizations.localeOf(context).languageCode == 'en';
                  return ListTile(
                    leading: const Icon(Icons.record_voice_over_outlined),
                    title: Text(
                      english && reciter.nameEn.isNotEmpty
                          ? reciter.nameEn
                          : reciter.nameAr,
                    ),
                    subtitle: Text(
                      <String>[
                        if (reciter.riwayah != null) reciter.riwayah!,
                        reciter.provider == QuranAudioProviderKind.alQuranCloud
                            ? 'AlQuran Cloud'
                            : 'MP3Quran',
                      ].join(' • '),
                    ),
                    trailing: const Icon(Icons.chevron_left),
                    onTap: () => Navigator.pop(context, reciter),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    if (selected != null && mounted)
      setState(() => _selectedReciter = selected);
  }

  Future<void> _playSurah(int surahNumber) async {
    final l10n = context.l10n;
    var reciter = _selectedReciter;
    if (reciter == null || !reciter.availableSurahs.contains(surahNumber)) {
      await _chooseReciter(surahNumber);
      reciter = _selectedReciter;
    }
    if (reciter == null) return;
    setState(() => _audioBusy = true);
    try {
      final services = ref.read(servicesProvider);
      final surah = await _surah(surahNumber);
      final media = await services.quranAudio.resolve(
        QuranAudioRequest(
          surah: surah,
          reciter: reciter,
          bitrateKbps: _bitrateKbps,
        ),
      );
      await services.playback.playQuranAudio(<QuranAudioMedia>[media], 0);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noAudioForSurah)));
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<Surah> _surah(int number) async {
    final values = await _surahsFuture;
    return values.firstWhere((value) => value.number == number);
  }

  Future<void> _playAyah(QuranVerse verse) async {
    final services = ref.read(servicesProvider);
    var reciter = _selectedReciter;
    if (reciter == null || !reciter.supportsAyahAudio) {
      await _chooseReciter(verse.surahNumber);
      reciter = _selectedReciter;
    }
    if (reciter == null) return;
    setState(() => _audioBusy = true);
    try {
      final media = await services.quranAudio.resolve(
        QuranAudioRequest(
          surah: await _surah(verse.surahNumber),
          reciter: reciter,
          bitrateKbps: _bitrateKbps,
          ayahGlobalNumber: verse.globalNumber,
          ayahInSurah: verse.ayahNumber,
        ),
      );
      await services.playback.playQuranAudio(<QuranAudioMedia>[media], 0);
      await _remember(verse);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.noAudioForSurah)));
    } finally {
      if (mounted) setState(() => _audioBusy = false);
    }
  }

  Future<void> _downloadSurah(int surahNumber) async {
    final services = ref.read(servicesProvider);
    var reciter = _selectedReciter;
    if (reciter == null) {
      await _chooseReciter(surahNumber);
      reciter = _selectedReciter;
    }
    if (reciter == null) return;
    try {
      final media = await services.quranAudio.resolve(
        QuranAudioRequest(
          surah: await _surah(surahNumber),
          reciter: reciter,
          bitrateKbps: _bitrateKbps,
        ),
      );
      await services.quranDownloads.download(media);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بدأ تنزيل السورة للتشغيل بدون إنترنت')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر بدء تنزيل السورة')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final services = ref.watch(servicesProvider);
    final mushaf = services.mushaf;
    return AnimatedBuilder(
      animation: mushaf,
      builder: (context, _) => FutureBuilder<List<Surah>>(
        future: _surahsFuture,
        builder: (context, surahSnapshot) {
          final surahs = surahSnapshot.data ?? const <Surah>[];
          return RefreshIndicator(
            onRefresh: () => _load(_mode, _number, refresh: true),
            child: CustomScrollView(
              slivers: <Widget>[
                SliverToBoxAdapter(
                  child: _ReaderHeader(
                    mode: _mode,
                    number: _number,
                    surahs: surahs,
                    onMode: (mode) => _load(mode, 1),
                    onNumber: (number) => _load(_mode, number),
                  ),
                ),
                if (mushaf.lastPosition != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(l10n.lastReadingPosition),
                          subtitle: Text(
                            '${mushaf.lastPosition!.verseKey ?? ''} • ${l10n.page} ${mushaf.lastPosition!.pageNumber ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: () {
                              final last = mushaf.lastPosition!;
                              _load(last.mode, last.number);
                            },
                            child: Text(l10n.continueReading),
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: FutureBuilder<QuranPassage>(
                    future: _passageFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 80),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 56),
                          child: ErrorPane(
                            error: snapshot.error ?? l10n.quranLoadError,
                            onRetry: () => _load(_mode, _number, refresh: true),
                          ),
                        );
                      }
                      final passage = snapshot.data!;
                      final surahNumber = passage.verses.isEmpty
                          ? (_mode == QuranBrowseMode.surah ? _number : 1)
                          : passage.verses.first.surahNumber;
                      return Column(
                        children: <Widget>[
                          _AudioAndReadingControls(
                            passage: passage,
                            selectedReciter: _selectedReciter,
                            audioBusy: _audioBusy,
                            bitrateKbps: _bitrateKbps,
                            onChooseReciter: () => _chooseReciter(surahNumber),
                            onPlay: () => _playSurah(surahNumber),
                            onBitrate: (value) =>
                                setState(() => _bitrateKbps = value),
                            onDownload: () => _downloadSurah(surahNumber),
                          ),
                          _QuranText(
                            passage: passage,
                            store: mushaf,
                            onRemember: _remember,
                            onPlayAyah: _playAyah,
                          ),
                          _NavigationControls(
                            mode: _mode,
                            number: _number,
                            max: _maxFor(_mode),
                            onPrevious: _number > 1
                                ? () => _load(_mode, _number - 1)
                                : null,
                            onNext: _number < _maxFor(_mode)
                                ? () => _load(_mode, _number + 1)
                                : null,
                          ),
                          const SizedBox(height: 120),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReaderHeader extends StatelessWidget {
  const _ReaderHeader({
    required this.mode,
    required this.number,
    required this.surahs,
    required this.onMode,
    required this.onNumber,
  });

  final QuranBrowseMode mode;
  final int number;
  final List<Surah> surahs;
  final ValueChanged<QuranBrowseMode> onMode;
  final ValueChanged<int> onNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SegmentedButton<QuranBrowseMode>(
            segments: <ButtonSegment<QuranBrowseMode>>[
              ButtonSegment(
                value: QuranBrowseMode.surah,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.readerModeSurah),
              ),
              ButtonSegment(
                value: QuranBrowseMode.juz,
                icon: const Icon(Icons.view_agenda_outlined),
                label: Text(l10n.readerModeJuz),
              ),
              ButtonSegment(
                value: QuranBrowseMode.page,
                icon: const Icon(Icons.auto_stories_outlined),
                label: Text(l10n.readerModePage),
              ),
            ],
            selected: <QuranBrowseMode>{mode},
            onSelectionChanged: (value) => onMode(value.first),
          ),
          const SizedBox(height: 10),
          if (mode == QuranBrowseMode.surah && surahs.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: number,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.selectSurah,
                prefixIcon: const Icon(Icons.menu_book),
              ),
              items: surahs
                  .map(
                    (surah) => DropdownMenuItem<int>(
                      value: surah.number,
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'en'
                            ? '${surah.number}. ${surah.nameEn}'
                            : '${surah.number}. ${surah.nameAr}',
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) onNumber(value);
              },
            )
          else
            Row(
              children: <Widget>[
                IconButton.filledTonal(
                  onPressed: number > 1 ? () => onNumber(number - 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      mode == QuranBrowseMode.page
                          ? l10n.pageOf604(number)
                          : '${l10n.juz} $number / 30',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: number < (mode == QuranBrowseMode.page ? 604 : 30)
                      ? () => onNumber(number + 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AudioAndReadingControls extends ConsumerWidget {
  const _AudioAndReadingControls({
    required this.passage,
    required this.selectedReciter,
    required this.audioBusy,
    required this.bitrateKbps,
    required this.onChooseReciter,
    required this.onPlay,
    required this.onBitrate,
    required this.onDownload,
  });

  final QuranPassage passage;
  final QuranAudioCatalogReciter? selectedReciter;
  final bool audioBusy;
  final int bitrateKbps;
  final VoidCallback onChooseReciter;
  final VoidCallback onPlay;
  final ValueChanged<int> onBitrate;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final store = ref.watch(servicesProvider).mushaf;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onChooseReciter,
                      icon: const Icon(Icons.record_voice_over_outlined),
                      label: Text(
                        selectedReciter == null
                            ? l10n.chooseReciter
                            : english && selectedReciter!.nameEn.isNotEmpty
                            ? selectedReciter!.nameEn
                            : selectedReciter!.nameAr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: audioBusy ? null : onPlay,
                    icon: audioBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(l10n.playSurah),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: bitrateKbps,
                      decoration: const InputDecoration(
                        labelText: 'جودة التلاوة',
                        prefixIcon: Icon(Icons.high_quality_outlined),
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 64, child: Text('64 kbps')),
                        DropdownMenuItem(value: 128, child: Text('128 kbps')),
                        DropdownMenuItem(value: 192, child: Text('192 kbps')),
                      ],
                      onChanged: (value) {
                        if (value != null) onBitrate(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'تنزيل السورة',
                    onPressed: selectedReciter == null ? null : onDownload,
                    icon: const Icon(Icons.download_for_offline_outlined),
                  ),
                ],
              ),
              if (ref.watch(servicesProvider).quranDownloads.supported)
                AnimatedBuilder(
                  animation: ref.watch(servicesProvider).quranDownloads,
                  builder: (context, _) {
                    final downloads = ref
                        .read(servicesProvider)
                        .quranDownloads
                        .tasks;
                    final active = downloads
                        .where(
                          (task) =>
                              task.state.name == 'downloading' ||
                              task.state.name == 'queued',
                        )
                        .firstOrNull;
                    if (active == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: active.progress),
                    );
                  },
                ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(Icons.text_fields),
                  Expanded(
                    child: Slider(
                      value: store.fontScale,
                      min: 0.75,
                      max: 1.8,
                      divisions: 21,
                      label: '${(store.fontScale * 100).round()}%',
                      onChanged: store.setFontScale,
                    ),
                  ),
                  Text('${(store.fontScale * 100).round()}%'),
                ],
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: store.showTajweed && passage.tajweedAvailable,
                onChanged: passage.tajweedAvailable
                    ? store.setShowTajweed
                    : null,
                title: Text(l10n.showTajweed),
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: store.showThemes,
                onChanged: store.setShowThemes,
                title: Text(l10n.showThemes),
                subtitle: Text(l10n.thematicRukuNote),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuranText extends StatelessWidget {
  const _QuranText({
    required this.passage,
    required this.store,
    required this.onRemember,
    required this.onPlayAyah,
  });

  final QuranPassage passage;
  final MushafStore store;
  final ValueChanged<QuranVerse> onRemember;
  final ValueChanged<QuranVerse> onPlayAyah;

  @override
  Widget build(BuildContext context) {
    final base =
        Theme.of(context).textTheme.headlineSmall?.copyWith(
          height: 2.05,
          fontSize: 25 * store.fontScale,
          fontFamily: 'serif',
        ) ??
        TextStyle(fontSize: 25 * store.fontScale, height: 2.05);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: passage.verses
              .map((verse) {
                final section = passage.themeSections
                    .where((item) => item.contains(verse))
                    .firstOrNull;
                final color = store.showThemes && section != null
                    ? _themeColor(context, section.rukuNumber)
                    : Colors.transparent;
                final tajweed =
                    store.showTajweed &&
                    passage.tajweedAvailable &&
                    verse.textTajweed != null &&
                    verse.textTajweed!.isNotEmpty;
                final spans = tajweed
                    ? TajweedMarkup.spans(
                        verse.textTajweed!,
                        base,
                        Theme.of(context).colorScheme,
                      )
                    : <InlineSpan>[
                        TextSpan(text: verse.textUthmani, style: base),
                      ];
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => onRemember(verse),
                          child: RichText(
                            textAlign: TextAlign.justify,
                            textDirection: TextDirection.rtl,
                            text: TextSpan(
                              children: <InlineSpan>[
                                ...spans,
                                TextSpan(
                                  text:
                                      '  ﴿${arabicIndicNumber(verse.ayahNumber)}﴾',
                                  style: base.copyWith(
                                    fontSize: 20 * store.fontScale,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: <Widget>[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: context.l10n.play,
                            onPressed: () => onPlayAyah(verse),
                            icon: const Icon(Icons.play_circle_outline),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: store.isBookmarked(verse.verseKey)
                                ? context.l10n.removeBookmark
                                : context.l10n.bookmark,
                            onPressed: () => store.toggleBookmark(verse),
                            icon: Icon(
                              store.isBookmarked(verse.verseKey)
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Color _themeColor(BuildContext context, int ruku) {
    final scheme = Theme.of(context).colorScheme;
    return switch (ruku % 6) {
      0 => scheme.primaryContainer.withValues(alpha: 0.26),
      1 => scheme.secondaryContainer.withValues(alpha: 0.26),
      2 => scheme.tertiaryContainer.withValues(alpha: 0.26),
      3 => scheme.surfaceContainerHighest.withValues(alpha: 0.7),
      4 => scheme.primaryContainer.withValues(alpha: 0.16),
      _ => scheme.secondaryContainer.withValues(alpha: 0.16),
    };
  }
}

class _NavigationControls extends StatelessWidget {
  const _NavigationControls({
    required this.mode,
    required this.number,
    required this.max,
    required this.onPrevious,
    required this.onNext,
  });

  final QuranBrowseMode mode;
  final int number;
  final int max;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_right),
              label: Text(
                mode == QuranBrowseMode.page
                    ? l10n.previousPage
                    : mode == QuranBrowseMode.surah
                    ? l10n.previousSurah
                    : l10n.previous,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$number / $max'),
          ),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onNext,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_left),
              label: Text(
                mode == QuranBrowseMode.page
                    ? l10n.nextPage
                    : mode == QuranBrowseMode.surah
                    ? l10n.nextSurah
                    : l10n.next,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
