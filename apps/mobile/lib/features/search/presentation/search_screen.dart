import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/repositories/quran_yutla_repository.dart';
import '../../../core/services/audio_playback_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(quranRepositoryProvider);
    final audioNotifier = ref.read(audioPlaybackProvider.notifier);

    final filteredStations = repo.stations
        .where((s) => s.nameAr.contains(_query) || s.currentTrack.contains(_query))
        .toList();

    final filteredReciters = repo.reciters
        .where((r) => r.nameAr.contains(_query) || r.riwaya.contains(_query))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'ابحث في السور، القراء، والمحطات...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _query = val.trim();
            });
          },
        ),
      ),
      body: _query.isEmpty
          ? const Center(
              child: Text(
                'اكتب اسم سورة أو قارئ أو إذاعة للبحث المباشر',
                style: TextStyle(color: Color(0xFF5B677A)),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (filteredStations.isNotEmpty) ...[
                  const Text('المحطات الإذاعية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...filteredStations.map(
                    (s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.radio, color: Color(0xFF2E9E9E)),
                        title: Text(s.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(s.currentTrack),
                        trailing: IconButton(
                          icon: const Icon(Icons.play_arrow, color: Color(0xFF243B6B)),
                          onPressed: () {
                            audioNotifier.playRadio(s.nameAr, s.currentTrack, s.streamUrl);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (filteredReciters.isNotEmpty) ...[
                  const Text('القراء', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...filteredReciters.map(
                    (r) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.person, color: Color(0xFF2E9E9E)),
                        title: Text(r.nameAr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(r.riwaya),
                      ),
                    ),
                  ),
                ],
                if (filteredStations.isEmpty && filteredReciters.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('لم يتم العثور على نتائج مطابقة للبحث'),
                    ),
                  ),
              ],
            ),
    );
  }
}
