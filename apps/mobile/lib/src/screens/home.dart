import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../branding.dart';
import '../common.dart';
import '../models.dart';
import '../repository.dart';
import '../services.dart';
import '../theme.dart';
import 'legacy_reciter_detail.dart';
import 'quran_offline.dart';
import 'radio.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _defaultSections = <String>[
    'featured',
    'stations',
    'reciters',
    'offline',
    'categories',
  ];
  static const _allowedSections = <String>{
    'featured',
    'stations',
    'reciters',
    'offline',
    'categories',
  };

  late Future<HomeData> future;
  String? pendingStationId;
  bool openingFeatured = false;

  @override
  void initState() {
    super.initState();
    future = ref.read(servicesProvider).repository.home();
  }

  Future<void> refresh() async {
    final services = ref.read(servicesProvider);
    setState(() => future = services.repository.home(refresh: true));
    await Future.wait<void>([
      future.then((_) {}),
      services.remoteConfig.refresh(),
    ]);
  }

  Future<void> _playStation(Station station) async {
    if (pendingStationId != null) return;
    final url = station.playbackUrl;
    if (!station.isPlayable ||
        url == null ||
        Uri.tryParse(url)?.scheme.toLowerCase() != 'https') {
      _playbackError(station);
      return;
    }
    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      debugPrint('Tarteel home playback error: $error');
      _playbackError(station);
    } finally {
      if (mounted && pendingStationId == station.id) {
        setState(() => pendingStationId = null);
      }
    }
  }

  Future<void> _playFeatured(FeaturedItem item) async {
    if (openingFeatured || item.slug == null) return;
    setState(() => openingFeatured = true);
    try {
      final station = await ref
          .read(servicesProvider)
          .repository
          .api
          .station(item.slug!);
      await _playStation(station);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح المحتوى المختار حاليًا.')),
        );
      }
    } finally {
      if (mounted) setState(() => openingFeatured = false);
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

  List<String> _sectionOrder() {
    final configured = ref
        .read(servicesProvider)
        .remoteConfig
        .stringListValue('home_sections', fallback: _defaultSections);
    final safe = <String>[];
    for (final value in configured) {
      if (_allowedSections.contains(value) && !safe.contains(value))
        safe.add(value);
    }
    for (final fallback in _defaultSections) {
      if (!safe.contains(fallback)) safe.add(fallback);
    }
    return safe;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HomeData>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const LoadingPane();
      }
      if (snapshot.hasError && !snapshot.hasData) {
        return ErrorPane(error: snapshot.error!, onRetry: refresh);
      }
      final data = snapshot.data;
      if (data == null) return const EmptyPane();
      final services = ref.watch(servicesProvider);
      return AnimatedBuilder(
        animation: services.remoteConfig,
        builder: (context, _) => RefreshIndicator(
          onRefresh: refresh,
          child: ListView(
            padding: const EdgeInsets.only(top: TarteelTokens.spaceSm),
            children: <Widget>[
              if (data.featured.isNotEmpty)
                _HomeHero(
                  item: data.featured.first,
                  loading: openingFeatured,
                  onPlay: () => _playFeatured(data.featured.first),
                ),
              for (final section in _sectionOrder())
                ..._section(section, data, services),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
    },
  );

  List<Widget> _section(String id, HomeData data, AppServices services) {
    switch (id) {
      case 'featured':
        final featured = data.featured.skip(1).toList(growable: false);
        if (featured.isEmpty) return const <Widget>[];
        return <Widget>[
          const SectionHeader('مختارات ترتيل'),
          SizedBox(
            height: 144,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = featured[index];
                return SizedBox(
                  width: 250,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: item.slug == null || openingFeatured
                          ? null
                          : () => _playFeatured(item),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            Artwork(url: item.logoUrl, size: 72),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item.nameAr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              Icons.play_circle_fill,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ];
      case 'stations':
        if (!services.remoteConfig.radioEnabled) return const <Widget>[];
        final playable = data.stations
            .where((station) {
              final url = station.playbackUrl;
              return station.isPlayable &&
                  url != null &&
                  Uri.tryParse(url)?.scheme.toLowerCase() == 'https';
            })
            .take(10)
            .toList(growable: false);
        return <Widget>[
          const SectionHeader('إذاعات القرآن'),
          SizedBox(
            height: 142,
            child: playable.isEmpty
                ? const EmptyPane(message: 'لا توجد إذاعات متاحة حاليًا')
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: playable.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final station = playable[index];
                      return SizedBox(
                        width: 220,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: <Widget>[
                                Artwork(url: station.logoUrl, size: 54),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    station.nameAr,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    AnimatedBuilder(
                                      animation: services.favorites,
                                      builder: (context, _) => IconButton(
                                        tooltip: 'المفضلة',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => services.favorites
                                            .toggleStation(station.id),
                                        icon: Icon(
                                          services.favorites.isStation(
                                                station.id,
                                              )
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                        ),
                                      ),
                                    ),
                                    pendingStationId == station.id
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton.filled(
                                            tooltip: 'تشغيل',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () =>
                                                _playStation(station),
                                            icon: const Icon(Icons.play_arrow),
                                          ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ];
      case 'reciters':
        return <Widget>[
          const SectionHeader('القراء'),
          if (data.reciters.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('لا توجد تلاوات قارئ مفهرسة حاليًا.'),
            )
          else
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: data.reciters.take(8).length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final reciter = data.reciters[index];
                  return SizedBox(
                    width: 210,
                    child: Card(
                      child: ListTile(
                        leading: Artwork(
                          url: reciter.imageUrl,
                          size: 46,
                          icon: Icons.person_outline,
                        ),
                        title: Text(
                          reciter.nameAr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: reciter.rewaya == null
                            ? null
                            : Text(reciter.rewaya!),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReciterDetailPage(reciter: reciter),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ];
      case 'offline':
        if (!services.remoteConfig.offlineDownloadsEnabled)
          return const <Widget>[];
        final tasks = services.quranDownloads.tasks;
        final completed = tasks
            .where((task) => task.state.name == 'completed')
            .length;
        return <Widget>[
          const SectionHeader('الاستماع بدون إنترنت'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.download_for_offline_outlined),
                ),
                title: const Text('التنزيلات'),
                subtitle: Text('$completed سورة جاهزة بدون إنترنت'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuranOfflinePage(),
                  ),
                ),
              ),
            ),
          ),
        ];
      case 'categories':
        if (!services.remoteConfig.radioEnabled) return const <Widget>[];
        return <Widget>[
          const SectionHeader('التصنيفات'),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.categories
                  .map(
                    (category) => ActionChip(
                      avatar: const Icon(Icons.grid_view_outlined, size: 18),
                      label: Text(category.nameAr),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RadioPage(initialCategory: category.slug),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ];
      default:
        return const <Widget>[];
    }
  }
}

class _HomeHero extends StatelessWidget {
  const _HomeHero({
    required this.item,
    required this.loading,
    required this.onPlay,
  });

  final FeaturedItem item;
  final bool loading;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'مختار ترتيل: ${item.nameAr}',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart,
            end: AlignmentDirectional.bottomEnd,
            colors: <Color>[
              scheme.primaryContainer,
              scheme.surfaceContainerLow,
            ],
          ),
          borderRadius: BorderRadius.circular(TarteelTokens.radiusLg),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: TarteelTheme.deepGreen.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Artwork(url: item.logoUrl, size: 76, icon: Icons.graphic_eq),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const TarteelBrandMark(size: 24, radio: true),
                      const SizedBox(width: 8),
                      Text(
                        'مختار لك',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.nameAr,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (item.nameEn != null)
                    Text(
                      item.nameEn!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: loading || item.slug == null ? null : onPlay,
                    icon: loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: const Text('استمع الآن'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
