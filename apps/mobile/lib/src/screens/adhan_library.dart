import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../adhan_library.dart';
import '../services.dart';

class AdhanLibraryPage extends ConsumerWidget {
  const AdhanLibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(servicesProvider).adhanLibrary;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('صوت الأذان')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'اختر تسجيلًا مسموحًا للاستخدام ثم نزّله مرة واحدة. بعد اكتمال التنزيل يعمل الأذان محليًا دون إنترنت عند تفعيل نمط «إشعار وأذان». لا يتم تشغيل أي ملف قبل اكتمال تنزيله والتحقق من حجمه.',
                ),
              ),
            ),
            if (store.error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('تعذر تنزيل الأذان: ${store.error}'),
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
                  subtitle: Text('${recording.placeAr}\n${recording.licenseLabel}'),
                  isThreeLine: true,
                  trailing: store.busy
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : store.isDownloaded(recording.id)
                      ? FilledButton(
                          onPressed: () => store.select(recording.id),
                          child: Text(
                            store.selectedId == recording.id ? 'محدد' : 'اختيار',
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () async {
                            final ok = await store.download(recording);
                            if (context.mounted && !ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('فشل تنزيل ملف الأذان')),
                              );
                            }
                          },
                          child: const Text('تنزيل'),
                        ),
                  onTap: () => _showLicense(context, recording),
                ),
              ),
            if (store.selected != null)
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: const Text('الأذان النشط'),
                subtitle: Text(store.selected!.attribution),
              ),
          ],
        ),
      ),
    );
  }

  void _showLicense(BuildContext context, AdhanRecording recording) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recording.nameAr),
        content: Text(
          'المكان: ${recording.placeAr}\n\nالحقوق: ${recording.licenseLabel}\n\nالمصدر: ${recording.licenseUrl}',
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
