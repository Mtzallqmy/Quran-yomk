import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'legacy_reciter_detail.dart';

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

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final english = Localizations.localeOf(context).languageCode == 'en';
    return AnimatedBuilder(
      animation: services.favorites,
      builder: (context, _) => AnimatedBuilder(
        animation: services.quranPlayback,
        builder: (context, _) => FutureBuilder<_FavoritesData>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) {
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
            final history = services.quranPlayback.history.take(12).toList(growable: false);
            if (stations.isEmpty &&
                reciters.isEmpty &&
                services.favorites.trackIds.isEmpty &&
                history.isEmpty) {
              return EmptyPane(
                message: english
                    ? 'No favorites or recent Quran listening yet.'
                    : 'لم تضف مفضلة ولم تستمع إلى تلاوات مؤخرًا',
              );
            }
            return ListView(
              children: <Widget>[
                if (history.isNotEmpty) ...<Widget>[
                  SectionHeader(english ? 'Recently listened' : 'استمعت مؤخرًا'),
                  for (final entry in history)
                    ListTile(
                      leading: CircleAvatar(child: Text('${entry.surahNumber}')),
                      title: Text(
                        english
                            ? 'Surah ${entry.surahNumber}'
                            : 'سورة رقم ${entry.surahNumber}',
                      ),
                      subtitle: Text(
                        <String>[
                          entry.reciterName,
                          if (entry.riwayah?.isNotEmpty == true) entry.riwayah!,
                          if (entry.position > Duration.zero) _duration(entry.position),
                        ].where((value) => value.isNotEmpty).join(' • '),
                      ),
                      trailing: const Icon(Icons.history),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextButton.icon(
                        onPressed: services.quranPlayback.clearHistory,
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: Text(english ? 'Clear history' : 'مسح السجل'),
                      ),
                    ),
                  ),
                ],
                if (stations.isNotEmpty) ...<Widget>[
                  SectionHeader(english ? 'Favorite stations' : 'الإذاعات المفضلة'),
                  for (final station in stations)
                    ListTile(
                      leading: Artwork(url: station.logoUrl),
                      title: Text(station.nameAr),
                      trailing: IconButton(
                        onPressed: station.isPlayable
                            ? () => services.playback.playStation(station)
                            : null,
                        icon: const Icon(Icons.play_circle_fill),
                      ),
                    ),
                ],
                if (reciters.isNotEmpty) ...<Widget>[
                  SectionHeader(english ? 'Favorite reciters' : 'القراء المفضلون'),
                  for (final reciter in reciters)
                    ListTile(
                      leading: Artwork(
                        url: reciter.imageUrl,
                        icon: Icons.person_outline,
                      ),
                      title: Text(reciter.nameAr),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ReciterDetailPage(reciter: reciter),
                        ),
                      ),
                    ),
                ],
                if (services.favorites.trackIds.isNotEmpty) ...<Widget>[
                  SectionHeader(english ? 'Favorite recitations' : 'التلاوات المفضلة'),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      english
                          ? 'Recitations are saved by stable identity. Open the reciter page to resolve the current authorized audio source.'
                          : 'تُحفظ التلاوات بالمعرّف الثابت. افتح صفحة القارئ لتشغيل النسخة الحالية من رابط التلاوة المصرّح به.',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  final seconds = value.inSeconds.remainder(60);
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
