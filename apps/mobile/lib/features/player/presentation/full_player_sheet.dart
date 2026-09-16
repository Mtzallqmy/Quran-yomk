import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/audio_playback_service.dart';

class FullPlayerSheet extends ConsumerWidget {
  const FullPlayerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(audioPlaybackProvider);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF162746), // Deep Indigo Dark
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Text(
                playback.mode == PlaybackMode.radio ? 'إذاعة مباشرة' : 'مشغل التلاوات',
                style: const TextStyle(color: Color(0xFF2E9E9E), fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Colors.white, size: 22),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ رابط التلاوة للمشاركة')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Album Art / Station Graphic
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFF243B6B),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                playback.mode == PlaybackMode.radio ? Icons.radio : Icons.menu_book,
                size: 72,
                color: const Color(0xFF2E9E9E),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Titles
          Text(
            playback.currentTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            playback.currentSubtitle,
            style: const TextStyle(
              color: Color(0xFF9DAEC6),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Progress bar (if not live radio)
          if (playback.mode != PlaybackMode.radio) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF2E9E9E),
                inactiveTrackColor: Colors.white24,
                thumbColor: const Color(0xFFC77955),
              ),
              child: Slider(
                value: 0.35,
                onChanged: (val) {},
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('07:12', style: TextStyle(color: Color(0xFF9DAEC6), fontSize: 12)),
                  Text('20:45', style: TextStyle(color: Color(0xFF9DAEC6), fontSize: 12)),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF2E9E9E).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'بث حي متواصل • 128 kbps • EBU R128 (-16 LUFS)',
                style: TextStyle(color: Color(0xFF2E9E9E), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.timer_outlined, color: Colors.white70, size: 26),
                onPressed: () {
                  _showSleepTimerDialog(context, audioNotifier);
                },
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () => audioNotifier.togglePlayPause(),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2E9E9E),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    playback.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white, size: 36),
                onPressed: () {},
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.bookmark_border, color: Colors.white70, size: 26),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إضافة التلاوة إلى المفضلة')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static void _showSleepTimerDialog(BuildContext context, QuranYutlaAudioNotifier notifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مؤقت النوم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('إيقاف بعد 15 دقيقة'),
              onTap: () {
                notifier.setSleepTimer(15);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('إيقاف بعد 30 دقيقة'),
              onTap: () {
                notifier.setSleepTimer(30);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('إيقاف بعد 60 دقيقة'),
              onTap: () {
                notifier.setSleepTimer(60);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              title: const Text('تعطيل المؤقت'),
              onTap: () {
                notifier.setSleepTimer(null);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
