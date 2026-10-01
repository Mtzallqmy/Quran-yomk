import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../common.dart';
import '../models.dart';
import '../radio_service.dart';
import '../services.dart';
import '../virtual_radio.dart';
import '../theme.dart';

const _categoryNames = <String, String>{
  'UI_HARAMAIN': 'الحرمين',
  'UI_QURAN': 'القرآن الكريم',
  'UI_OTHER': 'إذاعات متنوعة',
  'UI_FAVORITES': 'محطات مفضلة',
  'QURAN_GENERAL': 'القرآن العام',
  'RECITER': 'القراء',
  'TAFSEER': 'التفسير',
  'HADITH': 'الحديث',
  'SEERAH': 'السيرة',
  'SAHABAH': 'الصحابة',
  'ADHKAR': 'الأذكار',
  'RUQYAH': 'الرقية',
  'FATWA': 'الفتاوى',
  'QURAN_TRANSLATION': 'ترجمات القرآن',
  'QURAN_SURAH': 'سور مختارة',
  'LIVE_TV_AUDIO': 'البث المباشر',
  'OTHER': 'أخرى',
};

const _categoryOrder = <String>[
  'QURAN_GENERAL',
  'RECITER',
  'TAFSEER',
  'HADITH',
  'SEERAH',
  'SAHABAH',
  'ADHKAR',
  'RUQYAH',
  'FATWA',
  'QURAN_TRANSLATION',
  'QURAN_SURAH',
  'LIVE_TV_AUDIO',
  'OTHER',
];

const _categoryIcons = <String, IconData>{
  'QURAN_GENERAL': Icons.menu_book_outlined,
  'RECITER': Icons.record_voice_over_outlined,
  'TAFSEER': Icons.auto_stories_outlined,
  'HADITH': Icons.library_books_outlined,
  'SEERAH': Icons.route_outlined,
  'SAHABAH': Icons.groups_outlined,
  'ADHKAR': Icons.wb_sunny_outlined,
  'RUQYAH': Icons.health_and_safety_outlined,
  'FATWA': Icons.question_answer_outlined,
  'QURAN_TRANSLATION': Icons.translate_outlined,
  'QURAN_SURAH': Icons.bookmark_outline,
  'LIVE_TV_AUDIO': Icons.live_tv_outlined,
  'OTHER': Icons.grid_view_outlined,
};

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key, this.initialCategory});

  final String? initialCategory;

  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  final _search = TextEditingController();
  String? selectedCategory;
  String query = '';
  String? pendingStationId;

  @override
  void initState() {
    super.initState();
    selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _play(Station station) async {
    final url = station.playbackUrl;
    if (url == null || url.isEmpty || Uri.tryParse(url)?.scheme != 'https') {
      _showPlaybackError(station);
      return;
    }

    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      debugPrint('Tarteel station playback error: $error');
      _showPlaybackError(station);
    } finally {
      if (mounted && pendingStationId == station.id) {
        setState(() => pendingStationId = null);
      }
    }
  }

  void _showPlaybackError(Station station) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر تشغيل ${station.nameAr}.'),
        action: SnackBarAction(
          label: 'إعادة المحاولة',
          onPressed: () => _play(station),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(radioProvider);
    final virtual = ref.watch(virtualRadioProvider);
    final stations = catalog.asData?.value ?? const <Station>[];
    final external = stations
        .where((station) => station.isExternal)
        .toList(growable: false);

    return AnimatedBuilder(
      animation: ref.watch(servicesProvider).favorites,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () async {
          await Future.wait<void>([
            ref.read(radioProvider.notifier).refresh(),
            ref.read(virtualRadioProvider.notifier).refresh(),
          ]);
        },
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _NowOnAir(stations: external, onPlay: _play),
            ),
            SliverToBoxAdapter(child: _VirtualRadioCard(value: virtual)),
            SliverToBoxAdapter(
              child: _RadioExplorer(
                controller: _search,
                query: query,
                selectedCategory: selectedCategory,
                stations: external,
                onQuery: (value) => setState(() => query = value),
                onCategory: (value) => setState(() => selectedCategory = value),
                onClear: () {
                  _search.clear();
                  setState(() {
                    query = '';
                    selectedCategory = null;
                  });
                },
              ),
            ),
            ...catalog.when(
              loading: () => const <Widget>[
                SliverFillRemaining(hasScrollBody: false, child: LoadingPane()),
              ],
              error: (error, _) => <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorPane(
                    error: error,
                    onRetry: () => ref.read(radioProvider.notifier).refresh(),
                  ),
                ),
              ],
              data: (values) => _catalogSlivers(
                values
                    .where((station) => station.isExternal)
                    .toList(growable: false),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
          ],
        ),
      ),
    );
  }

  List<Widget> _catalogSlivers(List<Station> stations) {
    final filtered = _filteredStations(stations);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(TarteelTokens.spaceMd),
          child: Text(
            selectedCategory == null
                ? 'الإذاعات'
                : _categoryNames[selectedCategory] ?? selectedCategory!,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      ),
      if (filtered.isEmpty)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPane(message: 'لا توجد إذاعات متاحة في هذا القسم'),
        )
      else
        SliverList.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) => _stationTile(filtered[index]),
        ),
    ];
  }

  List<Station> _filteredStations(List<Station> stations) {
    final q = _normalizeSearch(query);
    final result = stations
        .where((station) {
          final matches = switch (selectedCategory) {
            'UI_HARAMAIN' => _isHaramain(station),
            'UI_QURAN' =>
              station.category == 'QURAN_GENERAL' ||
                  station.category == 'QURAN_SURAH',
            'UI_OTHER' =>
              !_isHaramain(station) &&
                  station.category != 'QURAN_GENERAL' &&
                  station.category != 'QURAN_SURAH',
            'UI_FAVORITES' =>
              ref.read(servicesProvider).favorites.isStation(station.id),
            null => true,
            _ => station.category == selectedCategory,
          };
          if (!matches) return false;
          if (q.isEmpty) return true;
          final haystack = _normalizeSearch(
            <String?>[
              station.nameAr,
              station.nameEn,
              station.providerName,
              station.provider,
              station.category,
              _categoryNames[station.category],
            ].whereType<String>().join(' '),
          );
          return haystack.contains(q);
        })
        .toList(growable: false);
    result.sort(_stationRanking);
    return result;
  }

  Widget _stationTile(Station station) => StreamBuilder<MediaItem?>(
    stream: ref.read(servicesProvider).playback.mediaItemStream,
    builder: (context, snapshot) {
      final media = snapshot.data;
      final active =
          media?.extras?['kind'] == 'station' &&
          media?.extras?['entity_id'] == station.id;
      return _StationCard(
        key: ValueKey(station.id),
        station: station,
        active: active,
        pending: pendingStationId == station.id,
        onPlay: () => _play(station),
      );
    },
  );
}

class _RadioExplorer extends StatelessWidget {
  const _RadioExplorer({
    required this.controller,
    required this.query,
    required this.selectedCategory,
    required this.stations,
    required this.onQuery,
    required this.onCategory,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final String? selectedCategory;
  final List<Station> stations;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCategory;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final station in stations) {
      final category = station.category ?? 'OTHER';
      counts[category] = (counts[category] ?? 0) + 1;
    }
    final available = [
      'UI_HARAMAIN',
      'UI_QURAN',
      'UI_OTHER',
      'UI_FAVORITES',
      ..._categoryOrder.where((category) => (counts[category] ?? 0) > 0),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث عن إذاعة، قارئ أو قسم',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: onQuery,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text('التصنيفات', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (selectedCategory != null)
                TextButton(
                  onPressed: () => onCategory(null),
                  child: const Text('كل الأقسام'),
                ),
            ],
          ),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(12) > 16 ? 72 : 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: available.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = available[index];
                return ChoiceChip(
                  avatar: Icon(
                    _categoryIcons[category] ?? Icons.radio_outlined,
                    size: 18,
                  ),
                  label: Text(_categoryNames[category] ?? category),
                  selected: selectedCategory == category,
                  onSelected: (_) => onCategory(
                    selectedCategory == category ? null : category,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VirtualRadioCard extends ConsumerWidget {
  const _VirtualRadioCard({required this.value});

  final AsyncValue<VirtualRadioResolution> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(servicesProvider).playback;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: value.when(
          loading: () => const SizedBox(
            height: 138,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TarteelBrandMark(size: 58, radio: true),
                title: Text('إذاعة ترتيل'),
                subtitle: Text('تعذر تشغيل الإذاعة الآن'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(virtualRadioProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
          data: (resolution) {
            final program = resolution.program;
            return StreamBuilder<MediaItem?>(
              stream: playback.mediaItemStream,
              builder: (context, mediaSnapshot) {
                final logicalActive =
                    mediaSnapshot.data?.extras?['kind'] == 'virtual_radio';
                return StreamBuilder<PlaybackState>(
                  stream: playback.playbackStateStream,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final playing = logicalActive && state?.playing == true;
                    final loading =
                        logicalActive &&
                        (state?.processingState ==
                                AudioProcessingState.loading ||
                            state?.processingState ==
                                AudioProcessingState.buffering);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const TarteelBrandMark(size: 72, radio: true),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          resolution.channelNameAr,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      const Chip(label: Text('مباشر')),
                                    ],
                                  ),
                                  Text(
                                    program?.titleAr ?? 'بث مختار',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (resolution.nextProgramTitleAr != null) ...<Widget>[
                          const SizedBox(height: 10),
                          Text(
                            'التالي: ${resolution.nextProgramTitleAr}${resolution.nextChangeAt == null ? '' : ' — ${_timeLabel(resolution.nextChangeAt!)}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: !resolution.isPlayable
                                    ? null
                                    : () async {
                                        if (loading) return;
                                        try {
                                          if (playing) {
                                            await playback.pause();
                                          } else if (logicalActive) {
                                            await playback.play();
                                          } else {
                                            await ref
                                                .read(
                                                  virtualRadioProvider.notifier,
                                                )
                                                .play();
                                          }
                                        } catch (_) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'تعذر تشغيل إذاعة ترتيل.',
                                              ),
                                              action: SnackBarAction(
                                                label: 'إعادة المحاولة',
                                                onPressed: () => ref
                                                    .read(
                                                      virtualRadioProvider
                                                          .notifier,
                                                    )
                                                    .retry(),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                icon: loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                label: Text(
                                  loading
                                      ? 'جارٍ التشغيل…'
                                      : playing
                                      ? 'إيقاف مؤقت'
                                      : 'تشغيل',
                                ),
                              ),
                            ),
                            if (logicalActive) ...<Widget>[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'إيقاف',
                                onPressed: () => ref
                                    .read(virtualRadioProvider.notifier)
                                    .stop(),
                                icon: const Icon(Icons.stop),
                              ),
                            ],
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({
    super.key,
    required this.station,
    required this.active,
    required this.pending,
    required this.onPlay,
  });
  final Station station;
  final bool active;
  final bool pending;
  final VoidCallback onPlay;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(TarteelTokens.spaceMs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Artwork(url: station.logoUrl, size: 48, icon: Icons.radio),
                const SizedBox(width: TarteelTokens.spaceMs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.nameAr,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        station.healthStatus == 'HEALTHY'
                            ? 'البث متاح'
                            : station.healthStatus == 'DEGRADED'
                            ? 'البث غير مستقر'
                            : 'حالة البث غير مؤكدة',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (station.description?.isNotEmpty == true)
                        Text(
                          station.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedBuilder(
                  animation: services.favorites,
                  builder: (context, _) => IconButton(
                    tooltip: services.favorites.isStation(station.id)
                        ? 'إزالة من المفضلة'
                        : 'إضافة إلى المفضلة',
                    onPressed: () =>
                        services.favorites.toggleStation(station.id),
                    icon: Icon(
                      services.favorites.isStation(station.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: services.playback.playbackStateStream,
                  builder: (context, snapshot) {
                    final playing = active && snapshot.data?.playing == true;
                    return FilledButton.tonalIcon(
                      onPressed: pending || !_isSecurePlayable(station)
                          ? null
                          : () => active
                                ? (playing
                                      ? services.playback.pause()
                                      : services.playback.play())
                                : onPlay(),
                      icon: pending
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(playing ? Icons.pause : Icons.play_arrow),
                      label: Text(
                        pending
                            ? 'جارٍ التحميل'
                            : playing
                            ? 'إيقاف مؤقت'
                            : 'تشغيل',
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NowOnAir extends ConsumerWidget {
  const _NowOnAir({required this.stations, required this.onPlay});
  final List<Station> stations;
  final ValueChanged<Station> onPlay;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      StreamBuilder<MediaItem?>(
        stream: ref.watch(servicesProvider).playback.mediaItemStream,
        builder: (context, snapshot) {
          final item = snapshot.data;
          final activeId = item?.extras?['kind'] == 'station'
              ? (item?.extras?['entity_id'])
              : null;
          final matching = stations.where((station) => station.id == activeId);
          final featured = stations.where(
            (station) => station.isFeatured && _isSecurePlayable(station),
          );
          final station = matching.isNotEmpty
              ? matching.first
              : featured.isNotEmpty
              ? featured.first
              : null;
          if (station == null) return const SizedBox.shrink();
          return _OnAirCard(
            key: ValueKey(station.id),
            station: station,
            item: matching.isEmpty ? null : item,
            onPlay: () => onPlay(station),
          );
        },
      );
}

class _OnAirCard extends ConsumerStatefulWidget {
  const _OnAirCard({
    super.key,
    required this.station,
    required this.item,
    required this.onPlay,
  });
  final Station station;
  final MediaItem? item;
  final VoidCallback onPlay;
  @override
  ConsumerState<_OnAirCard> createState() => _OnAirCardState();
}

class _OnAirCardState extends ConsumerState<_OnAirCard> {
  late Future<NowPlaying> _metadata;
  Timer? _refresh;
  bool _playing = false;
  Future<NowPlaying> _load() => Future.sync(
    () => ref.read(servicesProvider).repository.nowPlaying(widget.station.slug),
  );
  @override
  void initState() {
    super.initState();
    _metadata = _load();
    _refresh = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _playing && TickerMode.valuesOf(context).enabled)
        setState(() => _metadata = _load());
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final station = widget.station;
    return Card(
      margin: const EdgeInsets.all(TarteelTokens.spaceMd),
      child: Padding(
        padding: const EdgeInsets.all(TarteelTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'الآن على الهواء',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: TarteelTokens.spaceSm),
            Row(
              children: [
                Artwork(url: station.logoUrl, size: 48, icon: Icons.radio),
                const SizedBox(width: TarteelTokens.spaceMs),
                Expanded(
                  child: Text(
                    station.nameAr,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(width: TarteelTokens.spaceSm),
                const Chip(
                  label: Text('LIVE'),
                  avatar: Icon(Icons.sensors, size: 18),
                ),
              ],
            ),
            FutureBuilder<NowPlaying>(
              future: _metadata,
              builder: (context, snapshot) => Text(
                snapshot.data?.title ??
                    (widget.item?.title != station.nameAr
                        ? widget.item?.title
                        : null) ??
                    'معلومات البرنامج غير متاحة',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (widget.item?.extras?['bitrate_kbps'] case final num bitrate
                when bitrate > 0)
              Text('$bitrate kbps'),
            StreamBuilder<PlaybackState>(
              stream: services.playback.playbackStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                _playing = widget.item != null && state?.playing == true;
                final busy =
                    widget.item != null &&
                    (state?.processingState == AudioProcessingState.loading ||
                        state?.processingState ==
                            AudioProcessingState.buffering);
                return Row(
                  children: [
                    if (_playing) ...[
                      const _PlaybackWave(),
                      const SizedBox(width: TarteelTokens.spaceSm),
                      const Expanded(child: Text('جارٍ التشغيل')),
                    ] else
                      const Spacer(),
                    AnimatedBuilder(
                      animation: services.favorites,
                      builder: (context, _) => IconButton(
                        tooltip: services.favorites.isStation(station.id)
                            ? 'إزالة من المفضلة'
                            : 'إضافة إلى المفضلة',
                        onPressed: () =>
                            services.favorites.toggleStation(station.id),
                        icon: Icon(
                          services.favorites.isStation(station.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: busy
                          ? null
                          : () => widget.item == null
                                ? widget.onPlay()
                                : _playing
                                ? services.playback.pause()
                                : services.playback.play(),
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                      label: Text(
                        busy
                            ? 'جارٍ التحميل'
                            : _playing
                            ? 'إيقاف مؤقت'
                            : 'تشغيل',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Decorative playback activity only, not an invented audio amplitude meter.
class _PlaybackWave extends StatefulWidget {
  const _PlaybackWave();
  @override
  State<_PlaybackWave> createState() => _PlaybackWaveState();
}

class _PlaybackWaveState extends State<_PlaybackWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _animation.value = .5;
    } else if (!_animation.isAnimating) {
      _animation.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => SizedBox(
          width: 24,
          height: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < 4; index++)
                Container(
                  width: 3,
                  height:
                      6 +
                      16 *
                          (index.isEven
                              ? _animation.value
                              : 1 - _animation.value),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

bool _isHaramain(Station station) => RegExp(
  'الحرم|مكه|مكة|المدينه|المدينة',
).hasMatch(_normalizeSearch('${station.nameAr} ${station.description ?? ''}'));

bool _isSecurePlayable(Station station) {
  final url = station.playbackUrl;
  return station.isPlayable &&
      url != null &&
      Uri.tryParse(url)?.scheme.toLowerCase() == 'https';
}

int _stationRanking(Station a, Station b) {
  final healthA = _healthRank(a.healthStatus);
  final healthB = _healthRank(b.healthStatus);
  if (healthA != healthB) return healthA.compareTo(healthB);
  return a.nameAr.compareTo(b.nameAr);
}

int _healthRank(String? value) => switch ((value ?? '').toUpperCase()) {
  'HEALTHY' => 0,
  'DEGRADED' => 1,
  'UNKNOWN' => 2,
  _ => 3,
};

String _normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[\u064B-\u065F\u0670]'), '')
    .replaceAll('ـ', '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ؤ', 'و')
    .replaceAll('ئ', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
