import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/audio_playback_service.dart';
import '../../player/presentation/full_player_sheet.dart';

class MiniAudioPlayerBar extends ConsumerWidget {
  const MiniAudioPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioPlaybackProvider);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => const FullPlayerSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF162746),
          border: Border(
            top: BorderSide(color: const Color(0xFF2E9E9E).withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(
              playback.mode == PlaybackMode.radio ? Icons.radio : Icons.menu_book,
              color: const Color(0xFF2E9E9E),
              size: 26,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playback.currentTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    playback.currentSubtitle,
                    style: const TextStyle(
                      color: Color(0xFF9DAEC6),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                playback.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: const Color(0xFF2E9E9E),
                size: 34,
              ),
              onPressed: () => audioNotifier.togglePlayPause(),
            ),
          ],
        ),
      ),
    );
  }
}
