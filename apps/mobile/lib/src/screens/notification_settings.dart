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
    final service = ref.watch(servicesProvider).pushNotifications;
    return AnimatedBuilder(
      animation: service,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('إشعارات ترتيل')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: <Widget>[
            SwitchListTile(
              value: service.enabled,
              onChanged: service.busy
                  ? null
                  : (value) async {
                      final success = await service.setEnabled(value);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تعذر تفعيل الإشعارات أو رُفضت الصلاحية'),
                          ),
                        );
                      }
                    },
              title: const Text('الإشعارات عن بُعد'),
              subtitle: const Text(
                'منفصلة عن تنبيهات الصلاة والأذان المحلية',
              ),
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
