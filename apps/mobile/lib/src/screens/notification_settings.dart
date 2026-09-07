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
                    title: Text(
                      service.registered ? 'الجهاز مسجل' : 'الجهاز غير مسجل',
                    ),
                    subtitle: Text(
                      'إذن النظام: ${service.systemPermissionGranted ? 'مسموح' : 'غير مسموح'}\n'
                      'آخر مزامنة: ${service.lastSyncedAt?.toLocal() ?? 'لم تتم'}',
                    ),
                    isThreeLine: true,
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
            if (service.enabled) ...<Widget>[
              const Divider(),
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
