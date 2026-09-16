import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(quranRepositoryProvider);
    final favorites = ref.watch(favoritesProvider);
    final favNotifier = ref.read(favoritesProvider.notifier);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);

    final favStations = repo.stations.where((s) => favorites.contains(s.id)).toList();
    final favReciters = repo.reciters.where((r) => favorites.contains(r.id)).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0, // Header is controlled by Shell AppBar
          bottom: const TabBar(
            tabs: [
              Tab(text: 'المحطات المفضلة'),
              Tab(text: 'القراء المفضلون'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Stations Tab
            favStations.isEmpty
                ? const Center(child: Text('لا توجد محطات في المفضلة حالياً'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favStations.length,
                    itemBuilder: (ctx, i) {
                      final s = favStations[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.radio, color: Color(0xFF2E9E9E)),
                          title: Text(s.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(s.currentTrack),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.star, color: Color(0xFFC77955)),
                                onPressed: () => favNotifier.toggleFavorite(s.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: Color(0xFF243B6B)),
                                onPressed: () {
                                  audioNotifier.playRadio(s.nameAr, s.currentTrack, s.streamUrl);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // Reciters Tab
            favReciters.isEmpty
                ? const Center(child: Text('لا يوجد قراء في المفضلة حالياً'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: favReciters.length,
                    itemBuilder: (ctx, i) {
                      final r = favReciters[i];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person, color: Color(0xFF2E9E9E)),
                          title: Text(r.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(r.riwaya),
                          trailing: IconButton(
                            icon: const Icon(Icons.star, color: Color(0xFFC77955)),
                            onPressed: () => favNotifier.toggleFavorite(r.id),
                          ),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
