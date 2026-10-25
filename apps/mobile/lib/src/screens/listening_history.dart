import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common.dart';
import '../playback_ui.dart';
import '../quran_playback_store.dart';
import '../services.dart';

class ListeningHistoryPage extends ConsumerStatefulWidget {
  const ListeningHistoryPage({super.key});
  @override
  ConsumerState<ListeningHistoryPage> createState() =>
      _ListeningHistoryPageState();
}

class _ListeningHistoryPageState extends ConsumerState<ListeningHistoryPage> {
  String? _pending;
  Future<void> _resume(QuranPlaybackSnapshot session) async {
    if (_pending != null) return;
    setState(() => _pending = session.identityKey);
    try {
      await resumeQuranListening(ref.read(servicesProvider), session);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('التلاوة غير متاحة حاليًا')),
        );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(servicesProvider).quranPlayback;
    return Scaffold(
      appBar: AppBar(title: const Text('سجل الاستماع')),
      body: AnimatedBuilder(
        animation: store,
        builder: (_, _) {
          final history = store.history;
          if (history.isEmpty)
            return const EmptyPane(
              message: 'التلاوات التي تستمع إليها ستظهر هنا',
            );
          return ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final session = history[index];
              return ListTile(
                key: ValueKey(session.identityKey),
                leading: const Icon(Icons.history),
                title: Text('السورة ${session.surahNumber}'),
                subtitle: Text(
                  '${session.reciterName} • ${session.position.inMinutes} دقيقة',
                ),
                trailing: IconButton(
                  tooltip: 'استكمال الاستماع',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _pending == null ? () => _resume(session) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
