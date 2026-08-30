import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../repository.dart';
import '../services.dart';
import 'reciters.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late Future<HomeData> future;

  @override
  void initState() {
    super.initState();
    future = ref.read(servicesProvider).repository.home();
  }

  Future<void> refresh() async {
    final repo = ref.read(servicesProvider).repository;
    setState(() {
      future = repo.home(refresh: true);
    });
    await future;
  }

  Future<void> _playStation(Station station) async {
    if (!station.isPlayable) return;
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تشغيل ${station.nameAr}: $error')),
      );
    }
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
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView(
              children: <Widget>[
                if (data.featured.isNotEmpty) ...<Widget>[
                  const SectionHeader('مختارات ترتيل'),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemCount: data.featured.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = data.featured[index];
                        return SizedBox(
                          width: 250,
                          child: Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: item.slug == null
                                  ? null
                                  : () async {
                                      final station = await services.repository.api
                                          .station(item.slug!);
                                      await _playStation(station);
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: <Widget>[
                                    Artwork(url: item.logoUrl, size: 72),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.nameAr,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 8),
                                          const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Icon(Icons.play_circle_outline, size: 18),
                                              SizedBox(width: 4),
                                              Text('تشغيل'),
                                            ],
                                          ),
                                        ],
                                      ),
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
                ],
                const SectionHeader('إذاعات القرآن'),
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    itemCount: data.stations.where((station) => station.isPlayable).take(10).length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final playable = data.stations
                          .where((station) => station.isPlayable)
                          .take(10)
                          .toList(growable: false);
                      final station = playable[index];
                      return SizedBox(
                        width: 270,
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _playStation(station),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: <Widget>[
                                  Artwork(url: station.logoUrl, size: 58),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          station.nameAr,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          station.isInternal
                                              ? 'ترتيل الداخلي'
                                              : station.providerName ?? 'محطة خارجية',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            const Icon(Icons.play_arrow, size: 18),
                                            const SizedBox(width: 4),
                                            Text(
                                              station.streamType,
                                              style: Theme.of(context).textTheme.labelSmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
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
                const SectionHeader('التصنيفات'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.categories
                        .take(12)
                        .map((category) => Chip(label: Text(category.nameAr)))
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          );
        },
      );
}
