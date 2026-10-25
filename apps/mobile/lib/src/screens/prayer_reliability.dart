import 'dart:convert';
import 'package:flutter/material.dart';
import '../adhan_library.dart';

String alarmEventLabel(String state) => switch (state) {
  'RECEIVED' => 'استلم Android التنبيه',
  'SERVICE_STARTED' => 'بدأت خدمة الأذان',
  'AUDIO_READY' => 'تم تجهيز الصوت (لا يؤكد السماع)',
  'COMPLETED' => 'اكتمل تشغيل الملف',
  'SILENT_NOTIFICATION' => 'إشعار صامت حسب الإعدادات',
  'SKIPPED_STALE' => 'تجاوز تنبيهًا قديمًا متأخرًا',
  'AUDIO_FOCUS_DENIED' => 'تعذر الحصول على أولوية الصوت',
  'BACKGROUND_START_FAILED' => 'منع النظام تشغيل الخدمة في الخلفية',
  _ => 'تعثر التشغيل: $state',
};

class PrayerReliabilityDetails extends StatelessWidget {
  const PrayerReliabilityDetails({super.key, required this.status});
  final Map<String, dynamic> status;
  @override
  Widget build(BuildContext context) {
    final at = (status['nextAlarmAt'] as num?)?.toInt() ?? 0;
    final path = status['nextAlarmPath'] as String? ?? '';
    final sound = builtInAdhanSounds
        .where((s) => s.path.split('/').last == path)
        .firstOrNull;
    List<dynamic> events = [];
    try {
      events = jsonDecode(status['eventsJson'] as String? ?? '[]') as List;
    } catch (_) {}
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.alarm),
          title: Text(
            at > 0
                ? '${status['nextAlarmTitle']}'
                : 'لا توجد تنبيهات قادمة محفوظة',
          ),
          subtitle: Text(
            at > 0
                ? '${DateTime.fromMillisecondsSinceEpoch(at).toLocal()}\n${status['nextAlarmSilent'] == true ? 'صامت' : sound?.nameAr ?? (path.isEmpty ? 'الصوت الافتراضي' : 'تسجيل من الهاتف')}'
                : 'راجع تفعيل الصلاة والموقع وصلاحية المنبهات.',
          ),
        ),
        ListTile(
          title: Text('الجهاز: ${status['manufacturer'] ?? 'Android'}'),
          subtitle: Text(
            status['dndFilter'] == 1
                ? 'عدم الإزعاج غير مفعّل'
                : 'راجع سياسة عدم الإزعاج؛ قد تمنع الصوت.',
          ),
        ),
        if (events.isNotEmpty)
          ExpansionTile(
            title: const Text('سجل التنبيهات على هذا الجهاز'),
            children: [
              for (final e in events.reversed)
                if (e is Map && e['at'] is num)
                  ListTile(
                    title: Text(alarmEventLabel('${e['state']}')),
                    subtitle: Text(
                      '${e['title']} • ${DateTime.fromMillisecondsSinceEpoch((e['at'] as num).toInt()).toLocal()}',
                    ),
                  ),
            ],
          ),
      ],
    );
  }
}
