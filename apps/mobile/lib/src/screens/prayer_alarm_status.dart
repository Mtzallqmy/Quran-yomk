import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../native_prayer_alarm.dart';
import '../services.dart';

class PrayerAlarmStatusPage extends ConsumerStatefulWidget {
  const PrayerAlarmStatusPage({super.key});

  @override
  ConsumerState<PrayerAlarmStatusPage> createState() =>
      _PrayerAlarmStatusPageState();
}

class _PrayerAlarmStatusPageState
    extends ConsumerState<PrayerAlarmStatusPage> {
  late Future<NativePrayerAlarmStatus> _status;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _status = ref.read(servicesProvider).prayerReminders.nativeStatus();
  }

  void _refresh() {
    setState(() {
      _status = ref.read(servicesProvider).prayerReminders.nativeStatus();
    });
  }

  Future<void> _requestExact() async {
    final notifications = ref.read(servicesProvider).localNotifications;
    await notifications.requestExactSchedulingPermission();
    if (!mounted) return;
    await ref.read(servicesProvider).prayerReminders.reconcile();
    _refresh();
  }

  Future<void> _test(bool adhan) async {
    if (_busy) return;
    setState(() => _busy = true);
    final services = ref.read(servicesProvider);
    try {
      if (!await services.localNotifications.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('اسمح بإشعارات ترتيل أولًا.')),
          );
        }
        return;
      }
      final scheduled = await services.prayerReminders.scheduleAlarmTest(
        playAdhan: adhan,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            scheduled
                ? adhan
                    ? 'تمت جدولة تجربة الأذان بعد 10 ثوانٍ. أغلق التطبيق وانتظر.'
                    : 'تمت جدولة تجربة المنبه بعد 10 ثوانٍ. أغلق التطبيق وانتظر.'
                : 'تعذر جدولة الاختبار على هذا الجهاز.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(servicesProvider).prayerSettings.value;
    return Scaffold(
      appBar: AppBar(title: const Text('حالة منبه الصلاة')),
      body: FutureBuilder<NativePrayerAlarmStatus>(
        future: _status,
        builder: (context, snapshot) {
          final status = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      leading: Icon(
                        status?.configured == true
                            ? Icons.alarm_on_outlined
                            : Icons.alarm_off_outlined,
                      ),
                      title: const Text('محرك المنبه الأصلي في Android'),
                      subtitle: Text(
                        status == null
                            ? 'جارٍ الفحص…'
                            : !status.available
                                ? 'غير متاح على هذا الجهاز/الإصدار'
                                : status.configured
                                    ? 'مهيأ ويعمل مستقلًا عن واجهة Flutter'
                                    : 'غير مهيأ بعد',
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: const Text('المنبهات المجدولة حاليًا'),
                      trailing: Text('${status?.scheduled ?? 0}'),
                    ),
                    ListTile(
                      leading: Icon(
                        status?.exact == true
                            ? Icons.verified_outlined
                            : Icons.warning_amber_outlined,
                      ),
                      title: const Text('دقة التوقيت'),
                      subtitle: Text(
                        status?.exact == true
                            ? 'Android يسمح بالمنبهات الدقيقة'
                            : 'يعمل بالتوقيت التقريبي حتى تمنح إذن «المنبهات والتذكيرات»',
                      ),
                      trailing: status?.exact == false
                          ? TextButton(
                              onPressed: _requestExact,
                              child: const Text('السماح'),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'اختبار فعلي',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'الاختبار يُجدول من Android نفسه. بعد الضغط يمكنك إغلاق ترتيل كليًا؛ يجب أن يظهر المنبه بعد 10 ثوانٍ.',
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _test(false),
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('اختبار إشعار الصلاة بعد 10 ثوانٍ'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _test(true),
                        icon: const Icon(Icons.volume_up_outlined),
                        label: const Text('اختبار الأذان بعد 10 ثوانٍ'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(settings.locationName),
                  subtitle: Text(
                    '${settings.timezone} • ${settings.latitude.toStringAsFixed(4)}, ${settings.longitude.toStringAsFixed(4)}',
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'يُعاد إنشاء منبهات الصلاة تلقائيًا بعد إعادة تشغيل الهاتف، تحديث التطبيق، تغيير الساعة أو المنطقة الزمنية. الأذان المدمج يعمل بلا إنترنت.',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
