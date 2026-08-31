import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../offline_clip_service.dart';
import '../services.dart';

class SavedClipsPage extends ConsumerWidget {
  const SavedClipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final clips = services.offlineClips;
    return Scaffold(
      appBar: AppBar(title: const Text('المحفوظات')),
      body: AnimatedBuilder(
        animation: clips,
        builder: (context, _) {
          if (!clips.supported) {
            return const EmptyPane(
              message: 'الحفظ بدون إنترنت غير متاح على هذه المنصة.',
            );
          }
          final values = clips.clips;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              if (clips.activeStationId != null)
                Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    title: const Text('جارٍ حفظ مقطع…'),
                    subtitle: Text(
                      '${_duration(clips.activeElapsed)} • ${_bytes(clips.activeBytes)}',
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: 'إيقاف الحفظ',
                      onPressed: clips.stop,
                      icon: const Icon(Icons.stop),
                    ),
                  ),
                ),
              if (values.isEmpty && clips.activeStationId == null)
                const Padding(
                  padding: EdgeInsets.only(top: 96),
                  child: EmptyPane(message: 'لا توجد مقاطع محفوظة بعد'),
                )
              else
                for (final clip in values)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: ListTile(
                      leading: Artwork(url: clip.artworkUrl, size: 52),
                      title: Text(clip.stationNameAr),
                      subtitle: Text(
                        '${_date(clip.createdAt)} • ${_duration(clip.duration)} • ${_bytes(clip.sizeBytes)}${clip.partial ? ' • محفوظ جزئيًا' : ''}',
                      ),
                      onTap: () async {
                        if (!await clips.exists(clip)) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ملف المقطع غير موجود.')),
                          );
                          return;
                        }
                        try {
                          await services.playback.playOfflineClip(clip);
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تعذر تشغيل المقطع المحفوظ.'),
                            ),
                          );
                        }
                      },
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: 'تشغيل',
                            onPressed: () => services.playback.playOfflineClip(clip),
                            icon: const Icon(Icons.play_arrow),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _delete(context, clips, clip),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    OfflineClipService service,
    OfflineClip clip,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المقطع؟'),
        content: Text(clip.stationNameAr),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (yes == true) await service.delete(clip.id);
  }
}

String _duration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

String _bytes(int value) {
  if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
  return '$value B';
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
