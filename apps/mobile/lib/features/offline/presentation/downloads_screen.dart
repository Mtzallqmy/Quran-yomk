import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';
import '../../../core/models/app_models.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadsProvider);
    final downloadsNotifier = ref.read(downloadsProvider.notifier);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنزيلات والاستماع دون اتصال'),
      ),
      body: downloads.isEmpty
          ? const Center(child: Text('لا توجد ملفات محملة حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.length,
              itemBuilder: (ctx, i) {
                final d = downloads[i];
                final isCompleted = d.status == DownloadStatus.completed;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              d.surahNameAr,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? const Color(0xFF2E9E9E).withOpacity(0.15)
                                    : const Color(0xFFC77955).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isCompleted ? 'مكتمل وموثق (SHA-256)' : 'جارٍ التحميل (${d.progressPercent}%)',
                                style: TextStyle(
                                  color: isCompleted ? const Color(0xFF2E9E9E) : const Color(0xFFC77955),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.reciterNameAr,
                          style: const TextStyle(color: Color(0xFF5B677A), fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        if (!isCompleted) ...[
                          LinearProgressIndicator(
                            value: d.progressPercent / 100.0,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            color: const Color(0xFF2E9E9E),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${(d.downloadedBytes / 1000000).toStringAsFixed(1)} MB / ${(d.totalBytes / 1000000).toStringAsFixed(1)} MB',
                                style: const TextStyle(color: Color(0xFF5B677A), fontSize: 12),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      d.status == DownloadStatus.downloading
                                          ? Icons.pause_circle_outline
                                          : Icons.play_circle_outline,
                                      color: const Color(0xFF243B6B),
                                    ),
                                    onPressed: () => downloadsNotifier.togglePauseResume(d.id),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => downloadsNotifier.deleteDownload(d.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'الحجم: ${(d.totalBytes / 1000000).toStringAsFixed(1)} MB • تخزين محلي',
                                style: const TextStyle(color: Color(0xFF5B677A), fontSize: 12),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, color: Color(0xFF2E9E9E), size: 28),
                                    tooltip: 'تشغيل من الملف المحلي',
                                    onPressed: () {
                                      audioNotifier.playOfflineTrack(
                                        d.surahNameAr,
                                        d.reciterNameAr,
                                        d.localPath ?? '',
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    tooltip: 'حذف من الجهاز',
                                    onPressed: () => downloadsNotifier.deleteDownload(d.id),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
