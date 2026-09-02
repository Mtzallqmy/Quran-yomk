import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../quran_audio.dart';
import '../quran_download_contract.dart';
import '../quran_playlist_store.dart';
import '../services.dart';

class QuranPlaylistsPage extends ConsumerWidget {
  const QuranPlaylistsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final english = Localizations.localeOf(context).languageCode == 'en';
    return Scaffold(
      appBar: AppBar(title: Text(english ? 'Quran playlists' : 'قوائم تشغيل القرآن')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context, services.quranPlaylists, english),
        icon: const Icon(Icons.playlist_add),
        label: Text(english ? 'New playlist' : 'قائمة جديدة'),
      ),
      body: AnimatedBuilder(
        animation: services.quranPlaylists,
        builder: (context, _) {
          final playlists = services.quranPlaylists.playlists;
          if (playlists.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  english
                      ? 'Create a playlist, then add downloaded surahs with their exact reciter identity.'
                      : 'أنشئ قائمة ثم أضف السور المحملة مع الحفاظ على هوية القارئ نفسه.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.queue_music)),
                  title: Text(playlist.name),
                  subtitle: Text(english ? '${playlist.entries.length} surahs' : '${playlist.entries.length} سورة'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => QuranPlaylistDetailPage(playlistId: playlist.id)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _create(BuildContext context, QuranPlaylistStore store, bool english) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(english ? 'New playlist' : 'قائمة تشغيل جديدة'),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: english ? 'Playlist name' : 'اسم القائمة')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: Text(english ? 'Cancel' : 'إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(english ? 'Create' : 'إنشاء')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await store.create(name);
  }
}

class QuranPlaylistDetailPage extends ConsumerWidget {
  const QuranPlaylistDetailPage({super.key, required this.playlistId});
  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final english = Localizations.localeOf(context).languageCode == 'en';
    return AnimatedBuilder(
      animation: services.quranPlaylists,
      builder: (context, _) {
        final values = services.quranPlaylists.playlists.where((e) => e.id == playlistId);
        if (values.isEmpty) return Scaffold(appBar: AppBar(), body: Center(child: Text(english ? 'Playlist not found' : 'القائمة غير موجودة')));
        final playlist = values.first;
        return Scaffold(
          appBar: AppBar(
            title: Text(playlist.name),
            actions: <Widget>[
              IconButton(
                tooltip: english ? 'Add from offline' : 'إضافة من التنزيلات',
                onPressed: () => _addFromOffline(context, ref, playlist, english),
                icon: const Icon(Icons.playlist_add),
              ),
              IconButton(
                tooltip: english ? 'Delete playlist' : 'حذف القائمة',
                onPressed: () async {
                  await services.quranPlaylists.delete(playlist.id);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          body: playlist.entries.isEmpty
              ? Center(child: Text(english ? 'Add downloaded surahs to start this playlist.' : 'أضف سورًا محملة لبدء قائمة التشغيل.'))
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: playlist.entries.length,
                  onReorder: (oldIndex, newIndex) => services.quranPlaylists.reorder(playlist.id, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final entry = playlist.entries[index];
                    final reciter = english && entry.reciter.nameEn.isNotEmpty ? entry.reciter.nameEn : entry.reciter.nameAr;
                    return ListTile(
                      key: ValueKey(entry.id),
                      leading: CircleAvatar(child: Text('${entry.surah.number}')),
                      title: Text(english && entry.surah.nameEn.isNotEmpty ? entry.surah.nameEn : entry.surah.nameAr),
                      subtitle: Text(reciter),
                      trailing: Wrap(children: <Widget>[
                        IconButton(tooltip: english ? 'Play from here' : 'تشغيل من هنا', onPressed: () => _playFrom(context, ref, playlist, index, english), icon: const Icon(Icons.play_circle_fill)),
                        IconButton(tooltip: english ? 'Remove' : 'إزالة', onPressed: () => services.quranPlaylists.remove(playlist.id, entry.id), icon: const Icon(Icons.remove_circle_outline)),
                      ]),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _addFromOffline(BuildContext context, WidgetRef ref, QuranPlaylist playlist, bool english) async {
    final services = ref.read(servicesProvider);
    final tasks = services.quranDownloads.tasks.where((e) => e.state == QuranDownloadState.completed).toList(growable: false)
      ..sort((a, b) {
        final r = a.media.reciter.nameAr.compareTo(b.media.reciter.nameAr);
        return r != 0 ? r : a.media.surah.number.compareTo(b.media.surah.number);
      });
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(english ? 'Download a surah first.' : 'حمّل سورة أولًا لإضافتها.')));
      return;
    }
    final selected = await showModalBottomSheet<QuranDownloadTask>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          builder: (context, controller) => ListView.builder(
            controller: controller,
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final reciter = task.media.reciter;
              return ListTile(
                leading: CircleAvatar(child: Text('${task.media.surah.number}')),
                title: Text(english && task.media.surah.nameEn.isNotEmpty ? task.media.surah.nameEn : task.media.surah.nameAr),
                subtitle: Text(english && reciter.nameEn.isNotEmpty ? reciter.nameEn : reciter.nameAr),
                onTap: () => Navigator.pop(context, task),
              );
            },
          ),
        ),
      ),
    );
    if (selected == null) return;
    final local = await services.quranDownloads.localMedia(selected.media);
    if (local == null || !local.reciter.sameIdentity(selected.media.reciter)) return;
    await services.quranPlaylists.add(playlist.id, local);
  }

  Future<void> _playFrom(BuildContext context, WidgetRef ref, QuranPlaylist playlist, int startIndex, bool english) async {
    final services = ref.read(servicesProvider);
    final media = <QuranAudioMedia>[];
    try {
      for (final entry in playlist.entries) {
        final resolved = await services.quranAudio.resolve(QuranAudioRequest(surah: entry.surah, reciter: entry.reciter, bitrateKbps: entry.bitrateKbps));
        if (!resolved.reciter.sameIdentity(entry.reciter)) throw StateError('QURAN_AUDIO_RECITER_MISMATCH');
        media.add(resolved);
      }
      await services.playback.playQuranAudio(media, startIndex);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(english ? 'A playlist item could not be resolved with the saved reciter.' : 'تعذر تشغيل عنصر لأن مصدره لا يطابق القارئ المحفوظ.')));
    }
  }
}
