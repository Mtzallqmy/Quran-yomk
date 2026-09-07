import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services.dart';

class PushNotificationSettingsPage extends ConsumerWidget {
  const PushNotificationSettingsPage({super.key});

  static const _labels = <String, String>{
    'admin_announcements': 'إعلانات الإدارة',
    'content_updates': 'تحديثات المحتوى',
    'quran_content': 'محتوى القرآن',
    'radio': 'الإذاعة',
    'prayer_related': 'إعلانات الصلاة',
    'adhkar': 'الأذكار',
    'important_system': 'تنبيهات النظام المهمة',
    'memorization_review': 'الحفظ والمراجعة',
    'personal_reminders': 'التذكيرات الشخصية',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final service = services.pushNotifications;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('إشعارات ترتيل')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: Icon(
                      service.registered
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                    ),
                    title: const Text('حالة الإشعارات عن بُعد'),
                    subtitle: Text(
                      service.enabled
                          ? 'مفعلة بعد تحقق الإذن والرمز وتسجيل الجهاز'
                          : 'غير مفعلة بالكامل',
                    ),
                  ),
                  _StatusTile(
                    title: 'إذن Android',
                    value: !service.consentDecided
                        ? 'غير مطلوب بعد'
                        : service.systemPermissionGranted
                        ? 'مسموح'
                        : 'مرفوض',
                  ),
                  _StatusTile(
                    title: 'Firebase',
                    value: service.ready
                        ? service.hasToken
                              ? 'جاهز'
                              : 'لا يوجد FCM token'
                        : service.lastErrorCode ==
                              'FIREBASE_INITIALIZATION_FAILED'
                        ? 'فشل التهيئة'
                        : 'غير مهيأ',
                  ),
                  _StatusTile(
                    title: 'تسجيل الجهاز',
                    value: service.registered
                        ? 'مسجل'
                        : service.lastSyncedAt != null
                        ? 'يحتاج إعادة تسجيل'
                        : 'غير مسجل',
                  ),
                  _StatusTile(
                    title: 'آخر مزامنة',
                    value: '${service.lastSyncedAt?.toLocal() ?? 'لم تتم'}',
                  ),
                  if (service.lastErrorCode != null)
                    ListTile(
                      leading: Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: Text(service.errorMessage),
                      subtitle: Text(service.lastErrorCode!),
                      trailing: service.lastErrorCode == 'PERMISSION_DENIED'
                          ? TextButton(
                              onPressed: services
                                  .localNotifications
                                  .openSystemSettings,
                              child: const Text('فتح الإعدادات'),
                            )
                          : null,
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: service.busy
                            ? null
                            : () async {
                                final success = await service
                                    .registerCurrentDevice(
                                      requestPermission: true,
                                    );
                                if (!success && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(service.errorMessage),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.sync),
                        label: Text(
                          service.registered
                              ? 'إعادة تسجيل الجهاز'
                              : 'تفعيل وتسجيل الجهاز',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              value: service.enabled,
              onChanged: service.busy
                  ? null
                  : (value) async {
                      final success = await service.setEnabled(value);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(service.errorMessage)),
                        );
                      }
                    },
              title: const Text('الإشعارات عن بُعد'),
              subtitle: const Text('منفصلة عن تنبيهات الصلاة والأذان المحلية'),
              secondary: service.busy
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
            ),
            const ListTile(
              leading: Icon(Icons.alarm_outlined),
              title: Text('الإشعارات المحلية'),
              subtitle: Text(
                'تنبيهات الصلاة والأذان والتذكيرات المحلية مستقلة عن Firebase، '
                'وتبقى حسب إعداداتها داخل الجهاز.',
              ),
            ),
            if (service.enabled) ...<Widget>[
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('أنواع الإشعارات عن بُعد'),
              ),
              for (final entry in _labels.entries)
                SwitchListTile(
                  value: service.preference(entry.key),
                  title: Text(entry.value),
                  onChanged: (value) async {
                    try {
                      await service.updatePreferences(<String, bool>{
                        entry.key: value,
                      });
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تعذر حفظ التفضيل')),
                        );
                      }
                    }
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text(title),
    trailing: Text(value),
  );
}
