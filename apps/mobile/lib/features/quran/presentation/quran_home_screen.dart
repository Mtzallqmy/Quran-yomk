import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';
import 'mushaf_reader_screen.dart';

class QuranHomeScreen extends ConsumerWidget {
  const QuranHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);
    final downloadsNotifier = ref.read(downloadsProvider.notifier);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Hero / Last Read Card
            Card(
              color: const Color(0xFF243B6B),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const MushafReaderScreen(initialPage: 293),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'متابعة الورد اليومي',
                            style: TextStyle(color: Color(0xFF2E9E9E), fontWeight: FontWeight.bold),
                          ),
                          Icon(Icons.bookmark, color: Color(0xFFC77955)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'سورة الكهف — صفحة 293',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'آخر قراءة: الآية 10 • الجزء الخامس عشر',
                        style: TextStyle(color: Color(0xFF9DAEC6), fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: const [
                          Text('فتح المصحف', style: TextStyle(color: Color(0xFF2E9E9E), fontWeight: FontWeight.bold)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, color: Color(0xFF2E9E9E), size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Prayer Times Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Row(
                          children: [
                            Icon(Icons.access_time_filled, color: Color(0xFF2E9E9E), size: 20),
                            SizedBox(width: 8),
                            Text('مواقيت الصلاة — الرياض', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text('المغرب بعد 01:12:45', style: TextStyle(color: Color(0xFFC77955), fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _PrayerTimeItem('الفجر', '04:32'),
                        _PrayerTimeItem('الظهر', '11:58'),
                        _PrayerTimeItem('العصر', '15:24'),
                        _PrayerTimeItem('المغرب', '18:05', isNext: true),
                        _PrayerTimeItem('العشاء', '19:35'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. Memorization Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E9E9E).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, color: Color(0xFF2E9E9E)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('خطة حفظ جزء عمّ', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('سورة النبأ (الآية 25 من 40) • 62%', style: TextStyle(color: Color(0xFF5B677A), fontSize: 12)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('متابعة'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 4. Surah Index Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'فهرس السور القرآنية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('114 سورة', style: TextStyle(color: Color(0xFF5B677A), fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),

            _buildSurahTile(context, audioNotifier, downloadsNotifier, 1, 'سورة الفاتحة', '7 آيات • مكية', 1),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 2, 'سورة البقرة', '286 آية • مدنية', 2),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 3, 'سورة آل عمران', '200 آية • مدنية', 50),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 18, 'سورة الكهف', '110 آيات • مكية', 293),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 36, 'سورة يس', '83 آية • مكية', 440),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 55, 'سورة الرحمن', '78 آية • مدنية', 531),
            _buildSurahTile(context, audioNotifier, downloadsNotifier, 67, 'سورة الملك', '30 آية • مكية', 562),
          ],
        ),
      ),
    );
  }

  static Widget _buildSurahTile(
    BuildContext context,
    QuranYutlaAudioNotifier audioNotifier,
    DownloadsNotifier downloadsNotifier,
    int number,
    String name,
    String subtitle,
    int page,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF243B6B).withOpacity(0.1),
          foregroundColor: const Color(0xFF243B6B),
          child: Text('$number', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_outline, color: Color(0xFF2E9E9E)),
              tooltip: 'استماع للتلاوة',
              onPressed: () {
                audioNotifier.playQuranTrack(
                  name,
                  'الشيخ عبد الباسط عبد الصمد',
                  'https://audio.quranyutla.app/${number.toString().padLeft(3, '0')}.mp3',
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined, color: Color(0xFFC77955), size: 20),
              tooltip: 'تنزيل للاستماع دون اتصال',
              onPressed: () {
                downloadsNotifier.addDownload(number, name, 'الشيخ عبد الباسط عبد الصمد');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('بدأ تنزيل $name دون اتصال')),
                );
              },
            ),
            Text('ص $page', style: const TextStyle(color: Color(0xFFC77955), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => MushafReaderScreen(initialPage: page),
            ),
          );
        },
      ),
    );
  }
}

class _PrayerTimeItem extends StatelessWidget {
  final String name;
  final String time;
  final bool isNext;

  const _PrayerTimeItem(this.name, this.time, {this.isNext = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            color: isNext ? const Color(0xFF2E9E9E) : const Color(0xFF5B677A),
            fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isNext ? const Color(0xFF2E9E9E).withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isNext ? const Color(0xFF2E9E9E) : const Color(0xFF141C2B),
            ),
          ),
        ),
      ],
    );
  }
}
