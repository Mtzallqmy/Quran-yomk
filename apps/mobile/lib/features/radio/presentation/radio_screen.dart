import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';
import '../../../core/widgets/brand_mark.dart';

class RadioScreen extends ConsumerWidget {
  const RadioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(quranRepositoryProvider);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    final playback = ref.watch(audioPlaybackProvider);
    final favorites = ref.watch(favoritesProvider);
    final favNotifier = ref.read(favoritesProvider.notifier);

    final featuredStation = repo.stations.first;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Live Station Hero Card
          Card(
            color: const Color(0xFF162746),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const QuranYutlaBrandMark(size: 68, isRadio: true),
                  const SizedBox(height: 16),
                  Text(
                    featuredStation.nameAr,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'الآن: ${featuredStation.currentTrack}',
                    style: const TextStyle(color: Color(0xFF2E9E9E), fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          audioNotifier.playRadio(
                            featuredStation.nameAr,
                            featuredStation.currentTrack,
                            featuredStation.streamUrl,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E9E9E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        icon: Icon(
                          playback.isPlaying && playback.currentTitle == featuredStation.nameAr
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                        label: Text(
                          playback.isPlaying && playback.currentTitle == featuredStation.nameAr
                              ? 'إيقاف البث'
                              : 'استمع الآن (128 kbps)',
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: Icon(
                          favorites.contains(featuredStation.id) ? Icons.star : Icons.star_border,
                          color: const Color(0xFFC77955),
                          size: 28,
                        ),
                        onPressed: () => favNotifier.toggleFavorite(featuredStation.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('محطات إذاعية أخرى مدارة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          ...repo.stations.skip(1).map((station) {
            final isFav = favorites.contains(station.id);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.radio, color: Color(0xFF2E9E9E)),
                title: Text(station.nameAr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(station.currentTrack, style: const TextStyle(fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(isFav ? Icons.star : Icons.star_border, color: const Color(0xFFC77955), size: 20),
                      onPressed: () => favNotifier.toggleFavorite(station.id),
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFF243B6B), size: 28),
                      onPressed: () {
                        audioNotifier.playRadio(station.nameAr, station.currentTrack, station.streamUrl);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  audioNotifier.playRadio(station.nameAr, station.currentTrack, station.streamUrl);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
