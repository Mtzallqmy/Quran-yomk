import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud_backup.dart';
import '../services.dart';

class CloudBackupPage extends ConsumerStatefulWidget {
  const CloudBackupPage({super.key});
  @override
  ConsumerState<CloudBackupPage> createState() => _CloudBackupPageState();
}

class _CloudBackupPageState extends ConsumerState<CloudBackupPage> {
  final _client = CloudBackupClient();
  bool _enabled = false;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _client
        .enabled()
        .then((value) {
          if (mounted) setState(() => _enabled = value);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      await action();
      final connected = await _client.enabled();
      if (mounted)
        setState(() {
          _enabled = connected;
          _status = message;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => _status =
              'تعذر إكمال الطلب. تحقق من الاتصال وحاول مجددًا؛ المفضلة المحلية محفوظة.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    final favorites = services.favorites;
    return Scaffold(
      appBar: AppBar(title: const Text('النسخ السحابي الاختياري')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.cloud_outlined, size: 64),
          const SizedBox(height: 16),
          const Text(
            'احفظ نسخة من مفضلة الإذاعات والقراء والتلاوات في خدمة ترتيل على Neon. لا تُرسل مواقيت الصلاة أو الموقع أو ملفات الصوت. يبدأ الاتصال عند اختيارك فقط.',
          ),
          const SizedBox(height: 12),
          const Text(
            'النسخة مرتبطة بمفتاح هذا التثبيت المحفوظ بأمان على الجهاز، وليست حسابًا لاستعادتها على هاتف آخر. حذف التطبيق قد يفقد المفتاح. الاستعادة تدمج المفضلة ولا تحذف الموجود.',
          ),
          const SizedBox(height: 20),
          if (!_client.configured)
            const Text(
              'الخدمة غير مهيأة في هذا البناء. تبقى جميع الوظائف المحلية متاحة.',
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_status!, semanticsLabel: _status),
            ),
          if (!_enabled)
            FilledButton.icon(
              onPressed: _busy || !_client.configured
                  ? null
                  : () => _run(
                      _client.connectWithConsent,
                      'تم تفعيل النسخة الاختيارية. يمكنك الآن حفظ المفضلة.',
                    ),
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('أوافق على إرسال المفضلة وتفعيل النسخة'),
            ),
          if (_enabled) ...[
            const Text(
              'يمكنك حفظ إعدادات الأذان بصورة منفصلة: طريقة الحساب، التعديلات، أنماط التنبيه، مستوى الصوت واختيارات الأصوات المدمجة. لا تُرسل الإحداثيات أو المواقيت اليدوية أو الملفات الصوتية. تبقى الجدولة محلية وتحتاج صلاحيات الهاتف.',
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _client.uploadPrayerPreferences(
                        services.prayerSettings.value,
                      ),
                      'حُفظت إعدادات الأذان دون الموقع أو ملفات الصوت.',
                    ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('أوافق على حفظ إعدادات الأذان'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _client.restorePrayerPreferences(
                        services.prayerSettings,
                      ),
                      'استُعيدت إعدادات الأذان. تُراجع الجدولة محليًا وفق صلاحيات الهاتف؛ موقعك محفوظ.',
                    ),
              icon: const Icon(Icons.alarm),
              label: const Text('استعادة إعدادات الأذان وإعادة الجدولة'),
            ),
            const Divider(),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _client.upload(favorites),
                      'تم حفظ نسخة المفضلة.',
                    ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('حفظ نسخة الآن'),
            ),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(
                      () => _client.restore(favorites),
                      'تم دمج المفضلة المحفوظة.',
                    ),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('استعادة ودمج المفضلة'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                      _client.disconnectAndDelete,
                      'حُذفت النسخة السحابية وأُلغي المفتاح.',
                    ),
              child: const Text('إيقاف الخدمة وحذف النسخة السحابية'),
            ),
          ],
        ],
      ),
    );
  }
}
