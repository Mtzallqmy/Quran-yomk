import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../local_notifications.dart';
import '../services.dart';

Future<void> showNotificationPrivacyDetails(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خصوصية الإشعارات'),
        content: const SingleChildScrollView(
          child: Text(
            'لا يبدأ Firebase ولا يُرسل رمز الجهاز قبل موافقتك. عند التفعيل، '
            'يرسل ترتيل إلى خادمه معرّف تثبيت عشوائيًا، ورمز FCM، ونوع النظام، '
            'وإصدار التطبيق، واللغة والمنطقة الزمنية، وتفضيلات الإشعارات.\n\n'
            'لا يصل التطبيق إلى جهات الاتصال أو الرسائل أو الصور أو الملفات أو '
            'الموقع من أجل الإشعارات. عند الإيقاف، يُلغى رمز الإرسال ويُفصل '
            'الحساب عن الجهاز. يمكنك إعادة التفعيل في أي وقت من هذه الصفحة.',
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );

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
                        : !service.systemPermissionChecked
                        ? 'جارٍ التحقق'
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
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('ما البيانات المستخدمة؟'),
                    subtitle: const Text(
                      'اعرض تفاصيل الموافقة والسحب وبيانات تسجيل الإشعارات',
                    ),
                    onTap: () => showNotificationPrivacyDetails(context),
                  ),
                ],
              ),
            ),
            const _NotificationDiagnosticsCard(),
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

class _NotificationDiagnosticsCard extends ConsumerStatefulWidget {
  const _NotificationDiagnosticsCard();

  @override
  ConsumerState<_NotificationDiagnosticsCard> createState() =>
      _NotificationDiagnosticsCardState();
}

class _NotificationDiagnosticsCardState
    extends ConsumerState<_NotificationDiagnosticsCard> {
  bool? _channelExists;
  bool? _channelEnabled;
  String _appVersion = '…';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final services = ref.read(servicesProvider);
    final results = await Future.wait<Object>(<Future<Object>>[
      services.localNotifications.remoteChannelExists(),
      services.localNotifications.remoteChannelEnabled(),
      PackageInfo.fromPlatform(),
    ]);
    if (!mounted) return;
    setState(() {
      _channelExists = results[0] as bool;
      _channelEnabled = results[1] as bool;
      final info = results[2] as PackageInfo;
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _localTest() async {
    final notifications = ref.read(servicesProvider).localNotifications;
    if (!await notifications.permissionGranted()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('إذن Android غير مسموح')));
      }
      return;
    }
    await notifications.show(
      LocalNotificationRequest(
        id: 990001,
        title: 'اختبار محلي من ترتيل',
        body: 'القناة وإذن Android يعملان على هذا الجهاز.',
        scheduledAt: DateTime.now(),
        timezone: 'Asia/Aden',
        payload: '/home',
        channel: LocalNotificationChannel.remotePush,
        preferExact: false,
      ),
    );
    await _refresh();
  }

  Future<void> _serverTest() async {
    setState(() => _testing = true);
    final push = ref.read(servicesProvider).pushNotifications;
    final accepted = await push.sendServerTest();
    if (!mounted) return;
    setState(() => _testing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'قبل Firebase الاختبار؛ راقب وصول الإشعار وفتحه أدناه.'
              : push.errorMessage,
        ),
      ),
    );
  }

  String _time(DateTime? value) =>
      value == null ? 'لم يحدث' : value.toLocal().toString();

  @override
  Widget build(BuildContext context) {
    final push = ref.watch(servicesProvider).pushNotifications;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: <Widget>[
            const ListTile(
              leading: Icon(Icons.monitor_heart_outlined),
              title: Text('تشخيص الإشعارات'),
              subtitle: Text('لا يعرض رمز FCM أو أي معلومات سرية'),
            ),
            _StatusTile(
              title: 'Firebase initialized',
              value: push.ready ? 'YES' : 'NO',
            ),
            _StatusTile(
              title: 'Notification consent',
              value: push.consentGranted ? 'YES' : 'NO',
            ),
            _StatusTile(
              title: 'POST_NOTIFICATIONS',
              value: push.systemPermissionGranted ? 'GRANTED' : 'DENIED',
            ),
            _StatusTile(
              title: 'Notification channel exists',
              value: _channelExists == null
                  ? '…'
                  : _channelExists!
                  ? 'YES'
                  : 'NO',
            ),
            _StatusTile(
              title: 'Notification channel enabled',
              value: _channelEnabled == null
                  ? '…'
                  : _channelEnabled!
                  ? 'YES'
                  : 'NO',
            ),
            _StatusTile(
              title: 'FCM token exists',
              value: push.hasToken ? 'YES' : 'NO',
            ),
            _StatusTile(
              title: 'Backend registration',
              value: push.registered ? 'REGISTERED' : 'UNREGISTERED',
            ),
            _StatusTile(
              title: 'Device linked to user',
              value: push.linkedToUser ? 'YES' : 'NO',
            ),
            _StatusTile(
              title: 'Installation ID',
              value: push.maskedInstallationId,
            ),
            _StatusTile(title: 'App version', value: _appVersion),
            _StatusTile(
              title: 'Last token refresh',
              value: _time(push.lastTokenRefreshAt),
            ),
            _StatusTile(
              title: 'Last backend registration',
              value: _time(push.lastSyncedAt),
            ),
            _StatusTile(
              title: 'Last push received',
              value: _time(push.lastReceivedAt),
            ),
            _StatusTile(
              title: 'Last notification displayed',
              value: _time(push.lastDisplayedAt),
            ),
            _StatusTile(
              title: 'Last notification opened',
              value: _time(push.lastOpenedAt),
            ),
            _StatusTile(
              title: 'Last error code',
              value: push.lastErrorCode ?? 'NONE',
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: _localTest,
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: const Text('اختبار محلي'),
                  ),
                  FilledButton.icon(
                    onPressed: _testing || !push.enabled ? null : _serverTest,
                    icon: _testing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: const Text('اختبار FCM من الخادم'),
                  ),
                  IconButton(
                    tooltip: 'تحديث التشخيص',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
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
  Widget build(BuildContext context) =>
      ListTile(dense: true, title: Text(title), trailing: Text(value));
}
