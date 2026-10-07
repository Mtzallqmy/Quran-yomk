import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../native_audio.dart';
import '../personal_alarms.dart';
import '../services.dart';

class PersonalAlarmsPage extends ConsumerStatefulWidget {
  const PersonalAlarmsPage({super.key});
  @override
  ConsumerState<PersonalAlarmsPage> createState() => _PersonalAlarmsPageState();
}

class _PersonalAlarmsPageState extends ConsumerState<PersonalAlarmsPage> {
  PersonalAlarmStore? _store;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final store = PersonalAlarmStore(
      prefs,
      ref.read(servicesProvider).localNotifications,
    )..load();
    setState(() => _store = store);
  }

  @override
  void dispose() {
    _store?.dispose();
    super.dispose();
  }

  Future<void> _edit([PersonalAlarm? alarm]) async {
    final store = _store!;
    final controller = TextEditingController(text: alarm?.title ?? 'منبهي');
    var time = TimeOfDay(
      hour: (alarm?.minutes ?? 420) ~/ 60,
      minute: (alarm?.minutes ?? 420) % 60,
    );
    var path = alarm?.audioPath;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('منبه بصوت من الهاتف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(labelText: 'اسم المنبه'),
                ),
                ListTile(
                  title: Text(time.format(context)),
                  leading: const Icon(Icons.schedule),
                  onTap: saving
                      ? null
                      : () async {
                          final selected = await showTimePicker(
                            context: context,
                            initialTime: time,
                          );
                          if (selected != null && context.mounted)
                            update(() => time = selected);
                        },
                ),
                ListTile(
                  title: Text(
                    path == null
                        ? 'اختر ملفًا صوتيًا'
                        : 'تم حفظ الصوت داخل التطبيق',
                  ),
                  leading: const Icon(Icons.audio_file),
                  onTap: saving
                      ? null
                      : () async {
                          try {
                            final selected = await NativeAudio.pickAudio();
                            if (selected != null && context.mounted)
                              update(() => path = selected);
                          } catch (_) {
                            if (context.mounted)
                              update(() => error = 'الملف غير مدعوم');
                          }
                        },
                ),
                const Text(
                  'يتكرر يوميًا دون إنترنت ويستخدم مستوى صوت المنبه في الهاتف.',
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving || path == null
                  ? null
                  : () async {
                      update(() => saving = true);
                      try {
                        await store.save(
                          PersonalAlarm(
                            id: alarm?.id ?? store.nextId,
                            title: controller.text.trim().isEmpty
                                ? 'منبهي'
                                : controller.text.trim(),
                            minutes: time.hour * 60 + time.minute,
                            audioPath: path!,
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (_) {
                        if (context.mounted)
                          update(() {
                            saving = false;
                            error =
                                'فعّل إذن الإشعارات والمنبهات الدقيقة ثم أعد المحاولة';
                          });
                      }
                    },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = _store;
    return Scaffold(
      appBar: AppBar(title: const Text('المنبه الشخصي')),
      floatingActionButton: store == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add_alarm),
              label: const Text('إضافة منبه'),
            ),
      body: store == null
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: store,
              builder: (context, _) => ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  if (store.alarms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('أضف وقتًا وصوتًا من هاتفك لتشغيله محليًا.'),
                    ),
                  for (final alarm in store.alarms)
                    Card(
                      child: ListTile(
                        title: Text(alarm.title),
                        subtitle: Text(
                          '${TimeOfDay(hour: alarm.minutes ~/ 60, minute: alarm.minutes % 60).format(context)} • يوميًا',
                        ),
                        onTap: () => _edit(alarm),
                        leading: Switch(
                          value: alarm.enabled,
                          onChanged: (enabled) async {
                            try {
                              await store.save(
                                PersonalAlarm(
                                  id: alarm.id,
                                  title: alarm.title,
                                  minutes: alarm.minutes,
                                  audioPath: alarm.audioPath,
                                  timezone: alarm.timezone,
                                  enabled: enabled,
                                ),
                              );
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('فعّل إذن التنبيه أولًا'),
                                  ),
                                );
                            }
                          },
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => store.remove(alarm.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
