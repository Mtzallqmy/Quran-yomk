import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'radio.dart';
import 'reciters.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});
  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesData {
  const _FavoritesData(this.stations, this.reciters);
  final List<Station> stations;
  final List<Reciter> reciters;
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  late Future<_FavoritesData> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_FavoritesData> load() async {
    final repo = ref.read(servicesProvider).repository;
    return _FavoritesData(await repo.stations(), await repo.reciters());
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
        const SnackBar(content: Text('تعذر تشغيل هذا البث الآن.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return AnimatedBuilder(
      animation: services.favorites,
      builder: (context, _) => FutureBuilder<_FavoritesData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done &&
              !snapshot.hasData) {
            return const LoadingPane();
          }
          if (snapshot.hasError && !snapshot.hasData) {
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => setState(() => future = load()),
            );
          }
          final data = snapshot.data;
          if (data == null) return const EmptyPane();
          final stations = data.stations
              .where((station) => services.favorites.isStation(station.id))
              .toList(growable: false);
          final reciters = data.reciters
              .where((reciter) => services.favorites.isReciter(reciter.id))
              .toList(growable: false);
          if (stations.isEmpty &&
              reciters.isEmpty &&
              services.favorites.trackIds.isEmpty) {
            return const EmptyPane(message: 'لم تضف أي عناصر إلى المفضلة بعد');
          }
          return ListView(
            children: <Widget>[
              if (stations.isNotEmpty) ...<Widget>[
                const SectionHeader('الإذاعات المفضلة'),
                for (final station in stations)
                  ListTile(
                    leading: Artwork(url: station.logoUrl),
                    title: Text(station.nameAr),
                    subtitle: Text(stationHealthLabel(station)),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => StationDetailPage(station: station),
                      ),
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: 'تشغيل',
                      onPressed: station.isPlayable
                          ? () => _play(station)
                          : null,
                      icon: const Icon(Icons.play_arrow),
                    ),
                  ),
              ],
              if (reciters.isNotEmpty) ...<Widget>[
                const SectionHeader('القراء المفضلون'),
                for (final reciter in reciters)
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
              if (services.favorites.trackIds.isNotEmpty) ...<Widget>[
                const SectionHeader('التلاوات المفضلة'),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'التلاوات محفوظة بالمعرّف. افتح صفحة القارئ لتشغيل رابط التلاوة الحالي من المصدر.',
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
