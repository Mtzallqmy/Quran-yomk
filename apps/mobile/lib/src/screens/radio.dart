import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../common.dart';
import '../models.dart';
import '../radio_service.dart';
import '../services.dart';
import '../virtual_radio.dart';

const _categoryNames = <String, String>{
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
    if (url == null || url.isEmpty) {
      _showError('هذه المحطة غير متاحة للتشغيل حاليًا.');
      return;
    }
    if (Uri.tryParse(url)?.scheme != 'https') {
      _showError(
        'هذه المحطة تستخدم اتصال HTTP غير آمن، لذلك لا تُشغّل في نسخة Android الحالية.',
      );
      return;
    }
    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      final webNote = kIsWeb
          ? ' وقد يمنع المتصفح بعض المصادر بسبب سياسات CORS.'
          : '';
      _showError('تعذر تشغيل ${station.nameAr}. حاول مرة أخرى.$webNote');
      debugPrint('Tarteel station playback error: $error');
    } finally {
      if (mounted && pendingStationId == station.id) {
        setState(() => pendingStationId = null);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'إغلاق', onPressed: () {}),
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

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          ref.read(radioProvider.notifier).refresh(),
          ref.read(virtualRadioProvider.notifier).refresh(),
        ]);
      },
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
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
    );
  }

  List<Widget> _catalogSlivers(List<Station> stations) {
    final filtered = _filteredStations(stations);
    if (query.trim().isNotEmpty) {
      if (filtered.isEmpty) {
        return const <Widget>[
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(message: 'لا توجد إذاعات تطابق البحث'),
          ),
        ];
      }
      return <Widget>[
        _SectionTitleSliver(
          title: 'نتائج البحث',
          subtitle: '${filtered.length} محطة',
        ),
        SliverList.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) => _stationTile(filtered[index]),
        ),
      ];
    }

    if (selectedCategory != null) {
      final values = filtered;
      return <Widget>[
        _SectionTitleSliver(
          title: _categoryNames[selectedCategory] ?? selectedCategory!,
          subtitle: '${values.length} محطة',
          onBack: () => setState(() => selectedCategory = null),
        ),
        if (values.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyPane(
              message: 'لا توجد محطات متاحة في هذا القسم حاليًا',
            ),
          )
        else
          SliverList.builder(
            itemCount: values.length,
            itemBuilder: (context, index) => _stationTile(values[index]),
          ),
      ];
    }

    final sections = <Widget>[];
    for (final category in _categoryOrder) {
      final values = stations
          .where((station) => station.category == category)
          .toList(growable: false);
      if (values.isEmpty) continue;
      values.sort(_stationRanking);
      sections.add(
        SliverToBoxAdapter(
          child: _StationSection(
            title: _categoryNames[category] ?? category,
            icon: _categoryIcons[category] ?? Icons.radio_outlined,
            count: values.length,
            stations: values.take(4).toList(growable: false),
            pendingStationId: pendingStationId,
            onShowAll: () => setState(() => selectedCategory = category),
            onPlay: _play,
          ),
        ),
      );
    }
    if (sections.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPane(message: 'لا توجد إذاعات متاحة حاليًا'),
        ),
      ];
    }
    return sections;
  }

  List<Station> _filteredStations(List<Station> stations) {
    final q = _normalizeSearch(query);
    final result = stations
        .where((station) {
          if (selectedCategory != null && station.category != selectedCategory)
            return false;
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
              hintText: 'ابحث عن إذاعة، قارئ، تفسير أو مصدر',
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
                TextButton.icon(
                  onPressed: () => onCategory(null),
                  icon: const Icon(Icons.grid_view_outlined, size: 18),
                  label: const Text('كل الأقسام'),
                ),
            ],
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categoryOrder
                  .where((category) => (counts[category] ?? 0) > 0)
                  .length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final available = _categoryOrder
                    .where((category) => (counts[category] ?? 0) > 0)
                    .toList(growable: false);
                final category = available[index];
                final count = counts[category] ?? 0;
                return ChoiceChip(
                  avatar: Icon(
                    _categoryIcons[category] ?? Icons.radio_outlined,
                    size: 18,
                  ),
                  label: Text(
                    '${_categoryNames[category] ?? category}  $count',
                  ),
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

class _StationSection extends ConsumerWidget {
  const _StationSection({
    required this.title,
    required this.icon,
    required this.count,
    required this.stations,
    required this.pendingStationId,
    required this.onShowAll,
    required this.onPlay,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<Station> stations;
  final String? pendingStationId;
  final VoidCallback onShowAll;
  final ValueChanged<Station> onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('$count', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(width: 6),
              TextButton(onPressed: onShowAll, child: const Text('عرض الكل')),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: stations.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final station = stations[index];
              return StreamBuilder<MediaItem?>(
                stream: ref.read(servicesProvider).playback.mediaItemStream,
                builder: (context, snapshot) {
                  final media = snapshot.data;
                  final active =
                      media?.extras?['kind'] == 'station' &&
                      media?.extras?['entity_id'] == station.id;
                  return _CompactStationCard(
                    station: station,
                    active: active,
                    pending: pendingStationId == station.id,
                    onPlay: () => onPlay(station),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _SectionTitleSliver extends StatelessWidget {
  const _SectionTitleSliver({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Row(
        children: <Widget>[
          if (onBack != null) ...<Widget>[
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_forward),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
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
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TarteelBrandMark(size: 58, radio: true),
                title: Text('إذاعة ترتيل'),
                subtitle: Text('تعذر تحديد مصدر البث الحالي'),
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
            final station = resolution.station;
            final program = resolution.program;
            return StreamBuilder<MediaItem?>(
              stream: playback.mediaItemStream,
              builder: (context, mediaSnapshot) {
                final media = mediaSnapshot.data;
                final logicalActive = media?.extras?['kind'] == 'virtual_radio';
                return StreamBuilder<PlaybackState>(
                  stream: playback.playbackStateStream,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final playing = logicalActive && state?.playing == true;
                    final buffering =
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
                                    program?.titleAr ??
                                        'بث مختار من إذاعات القرآن',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (program?.subtitleAr != null)
                                    Text(
                                      program!.subtitleAr!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            if (program != null)
                              _MetaChip(
                                _categoryNames[program.category] ??
                                    program.category,
                              ),
                            if (resolution.isManaged)
                              _MetaChip(
                                'المزود: ${resolution.managedProvider == 'RADIO_CO' ? 'Radio.co' : resolution.managedProvider ?? 'Managed Radio'}',
                              ),
                            if (station != null)
                              _MetaChip('المصدر الحالي: ${station.nameAr}'),
                            if (resolution.isManaged &&
                                resolution.managedStatus != null)
                              _MetaChip(
                                _managedStatusLabel(resolution.managedStatus!),
                              )
                            else if (station?.healthStatus != null)
                              _MetaChip(_healthLabel(station!.healthStatus!)),
                          ],
                        ),
                        if (resolution.nextProgramTitleAr != null) ...<Widget>[
                          const SizedBox(height: 8),
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
                                        if (buffering) return;
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
                                      },
                                icon: buffering
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
                                  buffering
                                      ? 'جارٍ الاتصال…'
                                      : playing
                                      ? 'إيقاف مؤقت'
                                      : 'تشغيل إذاعة ترتيل',
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

class _CompactStationCard extends ConsumerWidget {
  const _CompactStationCard({
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
    final favorites = ref.watch(servicesProvider).favorites;
    final secure = Uri.tryParse(station.playbackUrl ?? '')?.scheme == 'https';
    final playable = station.isPlayable && secure;
    return SizedBox(
      width: 270,
      child: Card(
        margin: EdgeInsets.zero,
        child: InkWell(
          onTap: playable ? onPlay : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Artwork(url: station.logoUrl, size: 48, icon: Icons.radio),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        station.nameAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: favorites,
                      builder: (context, _) => IconButton(
                        tooltip: 'المفضلة',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => favorites.toggleStation(station.id),
                        icon: Icon(
                          favorites.isStation(station.id)
                              ? Icons.favorite
                              : Icons.favorite_border,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  station.providerName ?? station.provider ?? 'مصدر خارجي',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _MetaChip(
                      station.healthStatus == null
                          ? 'غير مفحوص'
                          : _healthLabel(station.healthStatus!),
                    ),
                    const Spacer(),
                    if (pending)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton.filled(
                        visualDensity: VisualDensity.compact,
                        onPressed: playable ? onPlay : null,
                        icon: Icon(
                          active ? Icons.graphic_eq : Icons.play_arrow,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({
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
    final secure = Uri.tryParse(station.playbackUrl ?? '')?.scheme == 'https';
    final playable = station.isPlayable && secure;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: InkWell(
        onTap: playable ? onPlay : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Artwork(url: station.logoUrl, size: 62, icon: Icons.radio),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      station.nameAr,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      station.providerName ?? station.provider ?? 'مصدر خارجي',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: <Widget>[
                        if (station.category != null)
                          _MetaChip(
                            _categoryNames[station.category] ??
                                station.category!,
                          ),
                        _MetaChip(station.streamType),
                        if (station.healthStatus != null)
                          _MetaChip(_healthLabel(station.healthStatus!)),
                      ],
                    ),
                    if (!secure && station.playbackUrl != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'HTTP غير آمن — غير متاح في Android',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: <Widget>[
                  AnimatedBuilder(
                    animation: services.favorites,
                    builder: (context, _) => IconButton(
                      tooltip: 'المفضلة',
                      onPressed: () =>
                          services.favorites.toggleStation(station.id),
                      icon: Icon(
                        services.favorites.isStation(station.id)
                            ? Icons.favorite
                            : Icons.favorite_border,
                      ),
                    ),
                  ),
                  if (pending)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton.filled(
                      tooltip: playable
                          ? (active ? 'إعادة التشغيل' : 'تشغيل')
                          : 'غير متاح',
                      onPressed: playable ? onPlay : null,
                      icon: Icon(active ? Icons.graphic_eq : Icons.play_arrow),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
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

String _healthLabel(String value) => switch (value.toUpperCase()) {
  'HEALTHY' => 'متاح',
  'DEGRADED' => 'قد يتأخر',
  'UNAVAILABLE' || 'UNREACHABLE' => 'غير متاح',
  'UNSUPPORTED' => 'غير مدعوم',
  _ => 'غير مفحوص',
};

String _managedStatusLabel(String value) => switch (value.toLowerCase()) {
  'onair' => 'Radio.co: على الهواء',
  'offair' => 'Radio.co: خارج الهواء',
  _ => 'Radio.co: ${value.toLowerCase()}',
};

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
