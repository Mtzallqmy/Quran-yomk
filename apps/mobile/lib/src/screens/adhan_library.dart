import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adhan_audio.dart';
import '../adhan_library.dart';
import '../services.dart';

class AdhanLibraryPage extends ConsumerWidget {
  const AdhanLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final store = services.adhanLibrary;
    final player = services.adhanAudio;
    return AnimatedBuilder(
      animation: Listenable.merge([store, player]),
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('مكتبة الأذان والتنبيهات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.offline_pin_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'أذان مكة والمدينة وشالقار وأذان الفجر من مالمو متاح من أول تشغيل دون إنترنت، مع عينة قصيرة وتنبيه هادئ. يمكنك معاينة كل تسجيل وتخصيص صوت مختلف لكل صلاة. تسجيلات المساجد ميدانية وقد تتضمن صدى أو أصوات المكان.',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('أصوات مرفقة', style: Theme.of(context).textTheme.titleMedium),
            for (final sound in builtInAdhanSounds)
              Card(
                child: ListTile(
                  leading: Icon(
                    store.selectedId == sound.id ||
                            (store.selectedId == null &&
                                sound.id == 'built-in-adhan')
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(sound.nameAr),
                  subtitle: Text(
                    '${sound.descriptionAr}\n${sound.durationSeconds} ثانية • متاح دون إنترنت',
                  ),
                  trailing: _preview(context, player, sound.path),
                  onTap: () => sound.id == 'built-in-adhan'
                      ? store.selectBuiltIn()
                      : store.select(sound.id),
                ),
              ),
            const SizedBox(height: 16),
            Text('من هاتفك', style: Theme.of(context).textTheme.titleMedium),
            Card(
              child: ListTile(
                leading: const Icon(Icons.add_to_photos_outlined),
                title: const Text('استيراد ملف صوتي'),
                subtitle: const Text('تُحفظ نسخة خاصة داخل التطبيق'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  try {
                    await store.importPhoneAudio();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تعذر قراءة الملف الصوتي'),
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            for (final id in store.importedIds)
              Card(
                child: ListTile(
                  leading: Icon(
                    store.selectedId == id
                        ? Icons.radio_button_checked
                        : Icons.audio_file_outlined,
                  ),
                  title: Text(store.labelFor(id)),
                  onLongPress: () => _rename(context, store, id),
                  subtitle: const Text('محلي • اضغط مطولًا لتغيير الاسم'),
                  trailing: _preview(
                    context,
                    player,
                    store.availablePaths[id]!,
                  ),
                  onTap: () => store.select(id),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'تسجيلات إضافية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'تحتاج إلى تنزيل مرة واحدة، ثم تعمل دون إنترنت. اضغط على التسجيل لعرض مصدره وحقوقه.',
              ),
            ),
            if (store.error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'تعذر تنزيل الصوت. تحقق من الاتصال وحاول مجددًا.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            for (final recording in adhanRecordings)
              Card(
                child: ListTile(
                  leading: Icon(
                    store.selectedId == recording.id
                        ? Icons.radio_button_checked
                        : Icons.volume_up_outlined,
                  ),
                  title: Text(recording.nameAr),
                  subtitle: Text(
                    '${recording.placeAr}\n${recording.licenseLabel}',
                  ),
                  isThreeLine: true,
                  trailing: store.busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : store.isDownloaded(recording.id)
                      ? PopupMenuButton<String>(
                          tooltip: 'خيارات التسجيل',
                          onSelected: (action) async {
                            if (action == 'preview') {
                              await _playPreview(
                                context,
                                player,
                                store.availablePaths[recording.id]!,
                              );
                            } else {
                              await store.select(recording.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'preview',
                              child: Text('معاينة'),
                            ),
                            PopupMenuItem(
                              value: 'select',
                              child: Text('اختيار'),
                            ),
                          ],
                        )
                      : IconButton(
                          tooltip: 'تنزيل ${recording.nameAr}',
                          onPressed: () async {
                            final ok = await store.download(recording);
                            if (context.mounted && !ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('فشل تنزيل ملف الأذان'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.download_outlined),
                        ),
                  onTap: () => _showLicense(context, recording),
                ),
              ),
            if (player.lastError != null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'تعذر تشغيل الصوت. تحقق من الملف ومستوى الصوت ثم حاول مجددًا.',
                ),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'يمكن إبقاء الإشعار دون صوت أو إيقاف التنبيه لكل صلاة من إعدادات الصلاة. لا تؤدي المعاينة إلى تغيير الصوت المحدد.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    AdhanLibraryStore store,
    String id,
  ) async {
    var name = store.labelFor(id);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اسم الصوت المحلي'),
        content: TextFormField(
          initialValue: name,
          onChanged: (value) => name = value,
          maxLength: 80,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, name),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (value != null) await store.rename(id, value);
  }

  Widget _preview(
    BuildContext context,
    AdhanAudioService player,
    String path,
  ) => IconButton(
    tooltip: player.isPlaying ? 'إيقاف المعاينة' : 'معاينة الصوت',
    icon: Icon(
      player.isPlaying ? Icons.stop_circle_outlined : Icons.play_circle_outline,
    ),
    onPressed: () =>
        player.isPlaying ? player.stop() : _playPreview(context, player, path),
  );

  Future<void> _playPreview(
    BuildContext context,
    AdhanAudioService player,
    String path,
  ) async {
    await player.play(path: path);
  }

  void _showLicense(BuildContext context, AdhanRecording recording) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recording.nameAr),
        content: SingleChildScrollView(
          child: SelectableText(
            'المكان: ${recording.placeAr}\n\nالحقوق: ${recording.licenseLabel}\n\nالمصدر: ${recording.licenseUrl}',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
