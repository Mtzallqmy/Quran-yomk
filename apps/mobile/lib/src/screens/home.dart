import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../repository.dart';
import '../services.dart';
import 'radio.dart';
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

  Future<void> _play(Station station) async {
    try {
      await ref.read(servicesProvider).playback.playStation(station);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم الآن تشغيل ${station.nameAr}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر بدء البث. جرّب محطة أخرى أو أعد المحاولة.'),
        ),
      );
    }
  }

  void _openCategory(Category category) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => RadioBrowsePage(
        initialCategory: category.slug,
        initialSource: 'EXTERNAL',
        title: category.nameAr,
      ),
    ),
  );

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
      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            if (data.stations.isNotEmpty) ...<Widget>[
              const SectionHeader('استمع الآن'),
              SizedBox(
                height: 166,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.stations.take(8).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final station = data.stations[index];
                    return SizedBox(
                      width: 270,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  StationDetailPage(station: station),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Artwork(url: station.logoUrl, size: 54),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        station.nameAr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        stationHealthLabel(station),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton.filledTonal(
                                      tooltip: 'تشغيل',
                                      onPressed: station.isPlayable
                                          ? () => _play(station)
                                          : null,
                                      icon: const Icon(Icons.play_arrow),
                                    ),
                                  ],
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
            if (data.reciters.isNotEmpty) ...<Widget>[
              const SectionHeader('القراء'),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: data.reciters.take(10).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final reciter = data.reciters[index];
                    return SizedBox(
                      width: 220,
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  ReciterDetailPage(reciter: reciter),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: <Widget>[
                                Artwork(
                                  url: reciter.imageUrl,
                                  size: 50,
                                  icon: Icons.record_voice_over_outlined,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        reciter.nameAr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleSmall,
                                      ),
                                      if (reciter.rewaya != null)
                                        Text(
                                          reciter.rewaya!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_left),
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
            const SectionHeader('التصنيفات'),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.categories
                    .map(
                      (category) => ActionChip(
                        avatar: const Icon(
                          Icons.folder_open_outlined,
                          size: 18,
                        ),
                        label: Text(category.nameAr),
                        onPressed: () => _openCategory(category),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
        ),
      );
    },
  );
}
