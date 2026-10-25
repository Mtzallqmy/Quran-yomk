import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local_backup.dart';
import '../native_audio.dart';
import '../services.dart';

class LocalBackupPage extends ConsumerStatefulWidget {
  const LocalBackupPage({super.key});
  @override
  ConsumerState<LocalBackupPage> createState() => _LocalBackupPageState();
}

class _LocalBackupPageState extends ConsumerState<LocalBackupPage> {
  bool busy = false;
  bool restoreSettings = false;
  String? message;
  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      final result = await action();
      if (mounted) setState(() => message = result);
    } catch (_) {
      if (mounted)
        setState(
          () => message =
              'تعذرت العملية. اختر ملف نسخة ترتيل صالحًا وحاول مجددًا.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نسخة محلية لبياناتك')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(Icons.save_alt_rounded, size: 64),
        const SizedBox(height: 16),
        const Text(
          'احفظ مفضلاتك ومظهر التطبيق وإعدادات حساب الصلاة في ملف JSON يمكنك نقله إلى نسخة أخرى من ترتيل. يتضمن الملف موقع الصلاة المحفوظ؛ اختر مكانًا خاصًا لحفظه.',
        ),
        const SizedBox(height: 12),
        const Text(
          'الأصوات والتنزيلات وسجل التشغيل والقوائم لا تُضمّن في هذا الملف. لا يتضمن مفاتيح الدخول السحابية. الاستيراد يدمج المفضلة، وتبقى تنبيهات إعدادات الصلاة المستوردة متوقفة حتى تفعّلها بنفسك.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.ios_share),
          label: const Text('تصدير نسخة محلية'),
          onPressed: busy
              ? null
              : () => _run(() async {
                  final backup = LocalDataBackup(
                    await SharedPreferences.getInstance(),
                  );
                  final directory = await getTemporaryDirectory();
                  final file = File(
                    '${directory.path}/tarteel-backup-${DateTime.now().millisecondsSinceEpoch}.json',
                  );
                  await file.writeAsString(backup.export());
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(file.path)],
                      subject: 'نسخة بيانات ترتيل',
                    ),
                  );
                  return 'اختر تطبيق الملفات أو وجهة مناسبة من نافذة المشاركة لحفظ النسخة.';
                }),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: restoreSettings,
          onChanged: busy
              ? null
              : (value) => setState(() => restoreSettings = value),
          title: const Text('استيراد الإعدادات أيضًا'),
          subtitle: const Text(
            'المظهر واللغة وحساب الصلاة؛ تنبيهات الصلاة تحتاج إعادة تفعيل.',
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('استيراد ملف ودمج المفضلة'),
          onPressed: busy
              ? null
              : () => _run(() async {
                  final services = ref.read(servicesProvider);
                  final text = await NativeAudio.call<String>('pickBackup');
                  if (text == null) return null;
                  final count = await LocalDataBackup(
                    await SharedPreferences.getInstance(),
                  ).restore(text, restoreSettings: restoreSettings);
                  services.favorites.reload();
                  if (restoreSettings) {
                    services.settings.reload();
                    services.prayerSettings.reload();
                    await services.prayerReminders.reconcile();
                  }
                  if (mounted) setState(() {});
                  return 'تمت إضافة $count عنصرًا إلى المفضلة. أعد فتح التطبيق لتطبيق إعدادات المظهر واللغة المستوردة.';
                }),
        ),
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(message!, semanticsLabel: message),
          ),
      ],
    ),
  );
}
