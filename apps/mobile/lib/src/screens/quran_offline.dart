import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quran_audio.dart';
import '../quran_download_contract.dart';
import '../services.dart';

class QuranOfflinePage extends ConsumerWidget {
  const QuranOfflinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(
        title: Text(english ? 'Offline Quran' : 'الاستماع بدون إنترنت'),
      ),
      body: AnimatedBuilder(
        animation: services.quranDownloads,
        builder: (context, _) {
          final groups = <String, List<QuranDownloadTask>>{};
          for (final task in services.quranDownloads.tasks) {
            groups
                .putIfAbsent(
                  task.media.reciter.identityKey,
                  () => <QuranDownloadTask>[],
                )
                .add(task);
          }
          final values = groups.values.toList(growable: false)
            ..sort(
              (a, b) => a.first.media.reciter.nameAr.compareTo(
                b.first.media.reciter.nameAr,
              ),
            );
          if (values.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.download_for_offline_outlined, size: 54),
                    const SizedBox(height: 12),
                    Text(
                      english
                          ? 'Downloaded surahs will appear here grouped by the exact reciter.'
                          : 'ستظهر السور المحملة هنا مرتبة حسب القارئ نفسه.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
            itemCount: values.length,
            itemBuilder: (context, index) => _ReciterDownloadGroup(
              tasks: values[index],
              english: english,
            ),
          );
        },
      ),
    );
  }
}

class _ReciterDownloadGroup extends ConsumerWidget {
  const _ReciterDownloadGroup({required this.tasks, required this.english});

  final List<QuranDownloadTask> tasks;
  final bool english;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciter = tasks.first.media.reciter;
    final sorted = [...tasks]
      ..sort((a, b) => a.media.surah.number.compareTo(b.media.surah.number));
    final completed = sorted
        .where((task) => task.state == QuranDownloadState.completed)
        .length;
    final totalBytes = sorted
        .where((task) => task.state == QuranDownloadState.completed)
        .fold<int>(
          0,
          (sum, task) => sum + (task.totalBytes ?? task.downloadedBytes),
        );
    final title = english && reciter.nameEn.isNotEmpty
        ? reciter.nameEn
        : reciter.nameAr;
    return Card(
      child: ExpansionTile(
        leading: const CircleAvatar(child: Icon(Icons.record_voice_over)),
        title: Text(title),
        subtitle: Text(
          <String>[
            if (reciter.riwayah?.isNotEmpty == true) reciter.riwayah!,
            english ? '$completed offline' : '$completed سورة بدون إنترنت',
            _formatBytes(totalBytes),
          ].join(' • '),
        ),
        children: sorted
            .map(
              (task) => _OfflineSurahTile(task: task, english: english),
            )
            .toList(growable: false),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(bytes > 100 * 1024 * 1024 ? 0 : 1)} MB';
  }
}

class _OfflineSurahTile extends ConsumerWidget {
  const _OfflineSurahTile({required this.task, required this.english});

  final QuranDownloadTask task;
  final bool english;

  Future<void> _play(BuildContext context, WidgetRef ref) async {
    final services = ref.read(servicesProvider);
    final local = await services.quranDownloads.localMedia(task.media);
    if (!context.mounted) return;
    if (local == null || !local.reciter.sameIdentity(task.media.reciter)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            english
                ? 'The local file is unavailable or failed integrity verification.'
                : 'الملف المحلي غير متاح أو لم يجتز فحص السلامة.',
          ),
        ),
      );
      return;
    }
    await services.playback.playQuranAudio(<QuranAudioMedia>[local], 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final progress = task.progress;
    final status = switch (task.state) {
      QuranDownloadState.queued => english ? 'Queued' : 'في قائمة التنزيل',
      QuranDownloadState.downloading => progress == null
          ? (english ? 'Downloading' : 'جارٍ التنزيل')
          : '${(progress * 100).round()}%',
      QuranDownloadState.paused => english ? 'Paused' : 'متوقف مؤقتًا',
      QuranDownloadState.completed => english ? 'Offline' : 'محملة',
      QuranDownloadState.failed => english ? 'Failed' : 'فشل التنزيل',
      QuranDownloadState.cancelled => english ? 'Cancelled' : 'ملغاة',
    };
    final surah = task.media.surah;
    final title = english && surah.nameEn.isNotEmpty
        ? surah.nameEn
        : surah.nameAr;
    return ListTile(
      leading: CircleAvatar(child: Text('${surah.number}')),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(status),
          if (task.state == QuranDownloadState.downloading && progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: LinearProgressIndicator(value: progress),
            ),
        ],
      ),
      trailing: Wrap(
        spacing: 0,
        children: <Widget>[
          if (task.state == QuranDownloadState.completed)
            IconButton(
              tooltip: english ? 'Play offline' : 'تشغيل بدون إنترنت',
              onPressed: () => _play(context, ref),
              icon: const Icon(Icons.play_circle_fill),
            )
          else if (task.state == QuranDownloadState.paused ||
              task.state == QuranDownloadState.failed)
            IconButton(
              tooltip: english ? 'Resume' : 'استكمال',
              onPressed: () => services.quranDownloads.resume(task.id),
              icon: const Icon(Icons.play_arrow),
            )
          else if (task.state == QuranDownloadState.downloading ||
              task.state == QuranDownloadState.queued)
            IconButton(
              tooltip: english ? 'Pause' : 'إيقاف مؤقت',
              onPressed: () => services.quranDownloads.pause(task.id),
              icon: const Icon(Icons.pause),
            ),
          IconButton(
            tooltip: english ? 'Delete' : 'حذف',
            onPressed: () => services.quranDownloads.delete(task.id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }
}
