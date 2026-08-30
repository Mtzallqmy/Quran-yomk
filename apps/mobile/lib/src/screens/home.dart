import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
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
      future =
          Future.wait<dynamic>(<Future<dynamic>>[
            repo.featured(refresh: true),
            repo.stations(refresh: true),
            repo.reciters(refresh: true),
            repo.categories(refresh: true),
            repo.appConfig(refresh: true),
          ]).then(
            (values) => HomeData(
              featured: values[0],
              stations: values[1],
              reciters: values[2],
              categories: values[3],
              config: values[4],
            ),
          );
    });
    await future;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<HomeData>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData)
        return const LoadingPane();
      if (snapshot.hasError && !snapshot.hasData)
        return ErrorPane(error: snapshot.error!, onRetry: refresh);
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
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = data.featured[index];
                    return SizedBox(
                      width: 240,
                      child: Card(
                        child: InkWell(
                          onTap: item.slug == null
                              ? null
                              : () async {
                                  final station = await services.repository.api
                                      .station(item.slug!);
                                  await services.playback.playStation(station);
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        item.nameAr,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 6),
                                      const Row(
                                        children: <Widget>[
                                          Icon(
                                            Icons.play_circle_outline,
                                            size: 18,
                                          ),
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
            const SectionHeader('الإذاعات'),
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: data.stations.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final station = data.stations[index];
                  return SizedBox(
                    width: 210,
                    child: Card(
                      child: ListTile(
                        leading: Artwork(url: station.logoUrl, size: 46),
                        title: Text(
                          station.nameAr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          station.isInternal ? 'ترتيل الداخلي' : 'محطة خارجية',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          onPressed: station.isPlayable
                              ? () => services.playback.playStation(station)
                              : null,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SectionHeader('القراء'),
            SizedBox(
              height: 112,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: data.reciters.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
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
