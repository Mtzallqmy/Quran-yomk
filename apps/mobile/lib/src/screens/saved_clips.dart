import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../l10n.dart';
import '../offline_clip_service.dart';
import '../services.dart';

class SavedClipsPage extends ConsumerWidget {
  const SavedClipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final services = ref.watch(servicesProvider);
    final clips = services.offlineClips;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedClips)),
      body: AnimatedBuilder(
        animation: clips,
        builder: (context, _) {
          if (!clips.supported) {
            return EmptyPane(message: l10n.savedClipsUnsupported);
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
                    title: Text(l10n.savingClip),
                    subtitle: Text(
                      '${_duration(clips.activeElapsed)} • ${_bytes(clips.activeBytes)}',
                    ),
                    trailing: IconButton.filledTonal(
                      tooltip: l10n.stopSaving,
                      onPressed: () async {
                        await clips.stop();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.clipSavingStopped)),
                        );
                      },
                      icon: const Icon(Icons.stop),
                    ),
                  ),
                ),
              if (values.isEmpty && clips.activeStationId == null)
                Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: EmptyPane(message: l10n.noSavedClips),
                )
              else
                for (final clip in values)
                  Card(
                    margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: ListTile(
                      leading: Artwork(url: clip.artworkUrl, size: 52),
                      title: Text(clip.stationNameAr),
                      subtitle: Text(
                        '${_date(clip.createdAt)} • ${_duration(clip.duration)} • ${_bytes(clip.sizeBytes)}${clip.partial ? ' • ${l10n.savedPartially}' : ''}',
                      ),
                      onTap: () => _play(context, services, clip),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            tooltip: l10n.play,
                            onPressed: () => _play(context, services, clip),
                            icon: const Icon(Icons.play_arrow),
                          ),
                          IconButton(
                            tooltip: l10n.delete,
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

  Future<void> _play(
    BuildContext context,
    AppServices services,
    OfflineClip clip,
  ) async {
    final l10n = context.l10n;
    if (!await services.offlineClips.exists(clip)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fileMissing)),
      );
      return;
    }
    try {
      await services.playback.playOfflineClip(clip);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.unablePlaySavedClip)),
      );
    }
  }

  Future<void> _delete(
    BuildContext context,
    OfflineClipService service,
    OfflineClip clip,
  ) async {
    final l10n = context.l10n;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteClipQuestion),
        content: Text(clip.stationNameAr),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
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
  if (value >= 1024 * 1024) {
    return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (value >= 1024) return '${(value / 1024).toStringAsFixed(0)} KB';
  return '$value B';
}

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
