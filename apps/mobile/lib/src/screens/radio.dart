import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../radio_service.dart';
import '../services.dart';

const _categoryNames = <String, String>{
  'QURAN_GENERAL': 'إذاعات القرآن',
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

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key});

  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  final _search = TextEditingController();
  String filter = 'ALL';
  String? category;
  String? provider;
  String query = '';
  String? pendingStationId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _play(Station station) async {
    if (!station.isPlayable) {
      _showError('هذه المحطة لا تملك رابط تشغيل متاحًا حاليًا.');
      return;
    }
    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      final suffix = kIsWeb
          ? ' قد يمنع مزود البث التشغيل داخل المتصفح بسبب CORS.'
          : '';
      _showError('تعذر تشغيل ${station.nameAr}. $error$suffix');
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
    return catalog.when(
      loading: () => const LoadingPane(),
      error: (error, _) => ErrorPane(
        error: error,
        onRetry: () => ref.read(radioProvider.notifier).refresh(),
      ),
      data: (stations) => _buildCatalog(context, stations),
    );
  }

  Widget _buildCatalog(BuildContext context, List<Station> all) {
    final services = ref.watch(servicesProvider);
    final categories = all
        .where((station) => station.isExternal)
        .map((station) => station.category)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort();
    final providerMap = <String, String>{};
    for (final station in all.where((station) => station.isExternal)) {
      final key = station.provider;
      if (key != null && key.isNotEmpty) {
        providerMap[key] = station.providerName ?? key;
      }
    }
    final providerEntries = providerMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final normalizedQuery = query.trim().toLowerCase();
    final filtered = all.where((station) {
      if (filter != 'ALL' && station.source != filter) return false;
      if (category != null && station.category != category) return false;
      if (provider != null && station.provider != provider) return false;
      if (normalizedQuery.isEmpty) return true;
      return station.nameAr.contains(query.trim()) ||
          (station.nameEn ?? '').toLowerCase().contains(normalizedQuery) ||
          (station.providerName ?? '').toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);

    final groups = <String, List<Station>>{};
    for (final station in filtered) {
      final key = station.isInternal ? 'INTERNAL' : station.category ?? 'OTHER';
      groups.putIfAbsent(key, () => <Station>[]).add(station);
    }

    return StreamBuilder<MediaItem?>(
      stream: services.playback.mediaItemStream,
      builder: (context, mediaSnapshot) {
        final media = mediaSnapshot.data;
        final activeId = media?.extras?['kind'] == 'station'
            ? media?.extras?['entity_id'] as String?
            : null;
        return RefreshIndicator(
          onRefresh: () => ref.read(radioProvider.notifier).refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 20),
            children: <Widget>[
              if (media?.isLive == true)
                _NowPlayingRadioCard(
                  media: media!,
                  playback: services.playback,
                ),
              StreamBuilder<String>(
                stream: services.playback.errorStream,
                builder: (context, snapshot) {
                  final message = snapshot.data;
                  if (message == null || message.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.error_outline,
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(message)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث عن إذاعة أو قارئ أو مصدر',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _search.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() => query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SegmentedButton<String>(
                  segments: const <ButtonSegment<String>>[
                    ButtonSegment(value: 'ALL', label: Text('الكل')),
                    ButtonSegment(value: 'INTERNAL', label: Text('ترتيل')),
                    ButtonSegment(value: 'EXTERNAL', label: Text('خارجي')),
                  ],
                  selected: <String>{filter},
                  onSelectionChanged: (values) => setState(() {
                    filter = values.first;
                    if (filter == 'INTERNAL') {
                      category = null;
                      provider = null;
                    }
                  }),
                ),
              ),
              if (filter != 'INTERNAL' && providerEntries.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: const Text('كل المصادر'),
                          selected: provider == null,
                          onSelected: (_) => setState(() => provider = null),
                        ),
                      ),
                      ...providerEntries.map(
                        (entry) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: provider == entry.key,
                            onSelected: (_) => setState(() => provider = entry.key),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (filter != 'INTERNAL') ...<Widget>[
                const SizedBox(height: 4),
                SizedBox(
                  height: 42,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 6),
                        child: ChoiceChip(
                          label: const Text('كل التصنيفات'),
                          selected: category == null,
                          onSelected: (_) => setState(() => category = null),
                        ),
                      ),
                      ...categories.map(
                        (value) => Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: ChoiceChip(
                            label: Text(_categoryNames[value] ?? value),
                            selected: category == value,
                            onSelected: (_) => setState(() => category = value),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(
                  '${filtered.length} محطة متاحة',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (filtered.isEmpty)
                const EmptyPane(message: 'لا توجد محطات تطابق الاختيار الحالي')
              else
                ...groups.entries.expand((entry) {
                  final title = entry.key == 'INTERNAL'
                      ? 'إذاعة ترتيل'
                      : _categoryNames[entry.key] ?? entry.key;
                  return <Widget>[
                    SectionHeader(title),
                    ...entry.value.map(
                      (station) => _StationCard(
                        station: station,
                        active: activeId == station.id,
                        pending: pendingStationId == station.id,
                        onPlay: () => _play(station),
                      ),
                    ),
                  ];
                }),
            ],
          ),
        );
      },
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
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: station.isPlayable ? onPlay : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Artwork(url: station.logoUrl, size: 64),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                station.nameAr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            if (active)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(start: 8),
                                child: Icon(
                                  Icons.graphic_eq,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          station.isInternal
                              ? 'بث ترتيل الداخلي'
                              : station.providerName ?? station.provider ?? 'مصدر خارجي',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            _MetaChip(station.streamType),
                            if (station.healthStatus != null)
                              _MetaChip(_healthLabel(station.healthStatus!)),
                            if (station.category != null)
                              _MetaChip(_categoryNames[station.category] ?? station.category!),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  if (!station.isPlayable)
                    Expanded(
                      child: Text(
                        'غير متاح للتشغيل حاليًا',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    )
                  else
                    const Spacer(),
                  AnimatedBuilder(
                    animation: services.favorites,
                    builder: (context, _) => IconButton(
                      tooltip: 'المفضلة',
                      onPressed: () => services.favorites.toggleStation(station.id),
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
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: station.isPlayable ? onPlay : null,
                      icon: Icon(active ? Icons.replay : Icons.play_arrow),
                      label: Text(active ? 'إعادة التشغيل' : 'تشغيل'),
                    ),
                ],
              ),
              if (station.attribution != null && station.attribution!.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      station.attribution!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowPlayingRadioCard extends StatelessWidget {
  const _NowPlayingRadioCard({required this.media, required this.playback});

  final MediaItem media;
  final dynamic playback;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Artwork(url: media.artUri?.toString(), size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('يعمل الآن', style: Theme.of(context).textTheme.labelMedium),
                      Text(
                        media.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                StreamBuilder<PlaybackState>(
                  stream: playback.playbackStateStream as Stream<PlaybackState>,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final loading = state?.processingState == AudioProcessingState.loading ||
                        state?.processingState == AudioProcessingState.buffering;
                    if (loading) {
                      return const SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: EdgeInsets.all(9),
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      );
                    }
                    final playing = state?.playing == true;
                    return IconButton.filledTonal(
                      tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                      onPressed: playing ? playback.pause : playback.play,
                      icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    );
                  },
                ),
                IconButton(
                  tooltip: 'إيقاف',
                  onPressed: playback.stop,
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<double>(
              stream: playback.volumeStream as Stream<double>,
              initialData: 1.0,
              builder: (context, snapshot) {
                final value = (snapshot.data ?? 1.0).clamp(0.0, 1.0);
                return Row(
                  children: <Widget>[
                    const Icon(Icons.volume_down),
                    Expanded(
                      child: Slider(
                        value: value,
                        onChanged: (next) => playback.setVolume(next),
                      ),
                    ),
                    const Icon(Icons.volume_up),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall),
      );
}

String _healthLabel(String value) => switch (value) {
      'HEALTHY' => 'سليم',
      'DEGRADED' => 'قابل للتشغيل',
      'UNREACHABLE' => 'غير متاح',
      'INVALID' => 'غير مدعوم',
      _ => 'غير مفحوص',
    };
