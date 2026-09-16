import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_models.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';

class RecitationsScreen extends ConsumerWidget {
  const RecitationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(quranRepositoryProvider);
    final favorites = ref.watch(favoritesProvider);
    final favNotifier = ref.read(favoritesProvider.notifier);

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: repo.reciters.length,
        itemBuilder: (context, index) {
          final reciter = repo.reciters[index];
          final isFav = favorites.contains(reciter.id);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => ReciterDetailScreen(reciter: reciter),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFF2E9E9E).withOpacity(0.15),
                      child: const Icon(Icons.person, color: Color(0xFF2E9E9E), size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reciter.nameAr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reciter.riwaya,
                            style: const TextStyle(color: Color(0xFF5B677A), fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${reciter.surahsCount} سورة • ${reciter.audioQuality}',
                            style: const TextStyle(color: Color(0xFFC77955), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav ? Icons.star : Icons.star_border,
                        color: const Color(0xFFC77955),
                      ),
                      onPressed: () => favNotifier.toggleFavorite(reciter.id),
                    ),
                    const Icon(Icons.chevron_left, color: Color(0xFF5B677A)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ReciterDetailScreen extends ConsumerWidget {
  final ReciterModel reciter;

  const ReciterDetailScreen({super.key, required this.reciter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    final downloadsNotifier = ref.read(downloadsProvider.notifier);

    final sampleSurahs = [
      {'num': 1, 'name': 'سورة الفاتحة', 'page': 1},
      {'num': 2, 'name': 'سورة البقرة', 'page': 2},
      {'num': 18, 'name': 'سورة الكهف', 'page': 293},
      {'num': 36, 'name': 'سورة يس', 'page': 440},
      {'num': 55, 'name': 'سورة الرحمن', 'page': 531},
      {'num': 67, 'name': 'سورة الملك', 'page': 562},
      {'num': 114, 'name': 'سورة الناس', 'page': 604},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(reciter.nameAr),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF243B6B),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF2E9E9E).withOpacity(0.25),
                    child: const Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    reciter.nameAr,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    reciter.riwaya,
                    style: const TextStyle(color: Color(0xFF2E9E9E), fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reciter.bio,
                    style: const TextStyle(color: Color(0xFF9DAEC6), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'المصدر المعتمد: ${reciter.provider}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('التلاوات القرآنية المتاحة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          ...sampleSurahs.map((s) {
            final sNum = s['num'] as int;
            final sName = s['name'] as String;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF2E9E9E).withOpacity(0.12),
                  child: Text('$sNum', style: const TextStyle(color: Color(0xFF243B6B), fontWeight: FontWeight.bold)),
                ),
                title: Text(sName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('المصحف المرتل • 192 kbps'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_for_offline_outlined, color: Color(0xFFC77955)),
                      tooltip: 'تنزيل التلاوة',
                      onPressed: () {
                        downloadsNotifier.addDownload(sNum, sName, reciter.nameAr);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('بدأ تنزيل $sName بصوت ${reciter.nameAr}')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_circle_outline, color: Color(0xFF2E9E9E), size: 30),
                      tooltip: 'تشغيل',
                      onPressed: () {
                        audioNotifier.playQuranTrack(
                          sName,
                          reciter.nameAr,
                          'https://audio.quranyutla.app/${sNum.toString().padLeft(3, '0')}.mp3',
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
