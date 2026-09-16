import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../prayer_settings.dart';
import '../prayer_times.dart';
import '../services.dart';
import '../theme.dart';

class PrayerTimesPage extends ConsumerStatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  ConsumerState<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends ConsumerState<PrayerTimesPage> {
  late Future<PrayerSnapshot> _future;
  Timer? _clock;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    final services = ref.read(servicesProvider);
    services.prayerSettings.addListener(_reload);
    _future = _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<PrayerSnapshot> _load() {
    final services = ref.read(servicesProvider);
    return services.prayerTimes.snapshot(
      settings: services.prayerSettings.value,
    );
  }

  void _reload() {
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _openSettings() async {
    if (_openingSettings) return;
    _openingSettings = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const PrayerSettingsPage()),
      );
    } finally {
      _openingSettings = false;
    }
  }

  @override
  void dispose() {
    ref.read(servicesProvider).prayerSettings.removeListener(_reload);
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(servicesProvider).prayerSettings.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مواقيت الصلاة'),
        actions: <Widget>[
          IconButton(
            tooltip: 'إعدادات الصلاة',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: FutureBuilder<PrayerSnapshot>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingPane();
          }
          if (snapshot.hasError || snapshot.data == null) {
            return ErrorPane(
              error: snapshot.error ?? StateError('PRAYER_TIMES_UNAVAILABLE'),
              onRetry: _reload,
            );
          }
          return PrayerTimesView(
            snapshot: snapshot.data!,
            settings: settings,
            now: DateTime.now(),
          );
        },
      ),
    );
  }
}

class PrayerTimesView extends StatelessWidget {
  const PrayerTimesView({
    super.key,
    required this.snapshot,
    required this.settings,
    required this.now,
  });

  final PrayerSnapshot snapshot;
  final PrayerSettings settings;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: <Color>[
                scheme.primaryContainer,
                scheme.surfaceContainerLow,
              ],
            ),
            borderRadius: BorderRadius.circular(TarteelTokens.radiusLg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SwitchListTile(
                        title: const Text('توقيت يدوي ثابت يوميًا'),
                        subtitle: const Text('عند إيقافه تُستخدم المواقيت المحسوبة حسب التاريخ والموقع. الوقت اليدوي لا يتغير مع الفصول.'),
                        value: settings.manualTimes.containsKey(prayer),
                        onChanged: (enabled) async {
                          if (!enabled) {
                            await store.setManualTime(prayer, null);
                            return;
                          }
                          final chosen = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (chosen != null) {
                            await store.setManualTime(prayer, chosen.hour * 60 + chosen.minute);
                          }
                        },
                      ),
                      if (settings.manualTimes.containsKey(prayer))
                        ListTile(
                          title: const Text('موعد الصلاة اليدوي'),
                          subtitle: Text(TimeOfDay(
                            hour: settings.manualTimes[prayer]! ~/ 60,
                            minute: settings.manualTimes[prayer]! % 60,
                          ).format(context)),
                          trailing: const Icon(Icons.schedule),
                          onTap: () async {
                            final minutes = settings.manualTimes[prayer]!;
                            final chosen = await showTimePicker(context: context,
                              initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
                            if (chosen != null) {
                              await store.setManualTime(prayer, chosen.hour * 60 + chosen.minute);
                            }
                          },
                        ),
                      Icon(Icons.location_on_outlined, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        settings.locationName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  _ReminderChip(enabled: settings.remindersEnabled),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'الصلاة القادمة',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      snapshot.next.prayer.nameAr,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Text(
                    _time(snapshot.next.time),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('متبقي ${_remaining(snapshot.next.time.difference(now))}'),
            ],
          ),
        ),
        const SectionHeader('مواقيت اليوم'),
        Card(
          child: Column(
            children: <Widget>[
              for (
                var index = 0;
                index < snapshot.today.ordered.length;
                index++
              )
                _PrayerTimeRow(
                  occurrence: snapshot.today.ordered[index],
                  reminderMode: settings.reminderModeFor(
                    snapshot.today.ordered[index].prayer,
                  ),
                  divider: index < snapshot.today.ordered.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrayerTimeRow extends StatelessWidget {
  const _PrayerTimeRow({
    required this.occurrence,
    required this.reminderMode,
    required this.divider,
  });

  final PrayerOccurrence occurrence;
  final PrayerReminderMode reminderMode;
  final bool divider;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      ListTile(
        leading: Icon(
          occurrence.prayer == PrayerKind.sunrise
              ? Icons.wb_sunny_outlined
              : Icons.access_time,
        ),
        title: Text(occurrence.prayer.nameAr),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _time(occurrence.time),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (reminderMode != PrayerReminderMode.disabled) ...<Widget>[
              const SizedBox(width: 10),
              Tooltip(
                message: reminderMode.nameAr,
                child: Icon(
                  reminderMode == PrayerReminderMode.adhan
                      ? Icons.volume_up_outlined
                      : Icons.notifications_active_outlined,
                  size: 20,
                ),
              ),
            ],
          ],
        ),
      ),
      if (divider) const Divider(indent: 16, endIndent: 16),
    ],
  );
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(
      enabled ? Icons.notifications_active : Icons.notifications_off_outlined,
      size: 18,
    ),
    label: Text(enabled ? 'التذكير مفعل' : 'التذكير متوقف'),
  );
}

class PrayerSettingsPage extends ConsumerStatefulWidget {
  const PrayerSettingsPage({super.key});

  @override
  ConsumerState<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends ConsumerState<PrayerSettingsPage> {
  PrayerKind? _changingPrayer;

  Future<void> _editCalculation(PrayerSettings current) async {
    var city = _prayerCities.firstWhere(
      (value) => value.name == current.locationName,
      orElse: () => _prayerCities.first,
    );
    var calculation = current.calculationMethod;
    var asr = current.asrMethod;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الموقع وطريقة الحساب'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                DropdownButtonFormField<_PrayerCity>(
                  initialValue: city,
                  decoration: const InputDecoration(labelText: 'المدينة'),
                  items: <DropdownMenuItem<_PrayerCity>>[
                    for (final value in _prayerCities)
                      DropdownMenuItem(value: value, child: Text(value.name)),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => city = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PrayerCalculationMethod>(
                  initialValue: calculation,
                  decoration: const InputDecoration(
                    labelText: 'طريقة الحساب',
                  ),
                  items: <DropdownMenuItem<PrayerCalculationMethod>>[
                    for (final value in PrayerCalculationMethod.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_methodName(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => calculation = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PrayerAsrMethod>(
                  initialValue: asr,
                  decoration: const InputDecoration(labelText: 'حساب العصر'),
                  items: <DropdownMenuItem<PrayerAsrMethod>>[
                    for (final value in PrayerAsrMethod.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_asrName(value)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => asr = value);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  'تُحفظ هذه البيانات على جهازك وتُحسب المواقيت محليًا دون إرسال موقعك إلى الخادم.',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('حفظ وإعادة الجدولة'),
            ),
          ],
        ),
      ),
    );
    if (saved != true || !mounted) return;
    final store = ref.read(servicesProvider).prayerSettings;
    await store.updateLocation(
      current.copyWith(
        locationName: city.name,
        latitude: city.latitude,
        longitude: city.longitude,
        timezone: city.timezone,
        calculationMethod: calculation,
        asrMethod: asr,
      ),
    );
  }

  Future<void> _setMode(PrayerKind prayer, PrayerReminderMode mode) async {
    if (_changingPrayer != null) return;
    final services = ref.read(servicesProvider);
    if (mode != PrayerReminderMode.disabled &&
        !await services.localNotifications.exactSchedulingAvailable() &&
        mounted) {
      final requestExact = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('السماح بالتوقيت الدقيق؟'),
          content: const Text(
            'يحتاج تنبيه الصلاة في وقتها الدقيق إلى إذن «المنبّهات والتذكيرات» من Android. '
            'إذا لم تمنحه سيستمر ترتيل بتوقيت تقريبي آمن دون توقف التطبيق.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('استخدام توقيت تقريبي'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('فتح الإذن'),
            ),
          ],
        ),
      );
      if (requestExact == true) {
        await services.localNotifications.requestExactSchedulingPermission();
      }
    }
    if (!mounted) return;
    setState(() => _changingPrayer = prayer);
    final accepted = await services.prayerReminders.setPrayerMode(prayer, mode);
    if (!mounted) return;
    setState(() => _changingPrayer = null);
    if (mode != PrayerReminderMode.disabled && !accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'إذن الإشعارات مرفوض. فعّله من إعدادات Android ثم أعد المحاولة.',
          ),
          action: SnackBarAction(
            label: 'فتح الإعدادات',
            onPressed: () => ref
                .read(servicesProvider)
                .localNotifications
                .openSystemSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(servicesProvider).prayerSettings;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final settings = store.value;
        return Scaffold(
          appBar: AppBar(title: const Text('إعدادات الصلاة')),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: <Widget>[
              const SectionHeader('الموقع والحساب'),
              ListTile(
                leading: const Icon(Icons.location_city_outlined),
                title: Text(settings.locationName),
                subtitle: Text(
                  '${settings.timezone} • ${settings.latitude.toStringAsFixed(4)}, ${settings.longitude.toStringAsFixed(4)}',
                ),
                trailing: const Icon(Icons.edit_location_alt_outlined),
                onTap: () => _editCalculation(settings),
              ),
              ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('طريقة الحساب'),
                subtitle: Text(
                  '${_methodName(settings.calculationMethod)} • ${_asrName(settings.asrMethod)}',
                ),
              ),
              const SectionHeader('التذكيرات المحلية'),
              const Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Text(
                  'اختر لكل صلاة إشعارًا نصيًا أو أذانًا محليًا. يعمل إشعار الأذان كبديل آمن عندما يكون التطبيق في الخلفية.',
                ),
              ),
              for (final prayer in PrayerKind.values.where(
                (value) => value.isRequiredPrayer,
              ))
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 5,
                  ),
                  child: ExpansionTile(
                    leading: _changingPrayer == prayer
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            settings.reminderModeFor(prayer) ==
                                    PrayerReminderMode.adhan
                                ? Icons.volume_up_outlined
                                : Icons.notifications_outlined,
                          ),
                    title: Text('صلاة ${prayer.nameAr}'),
                    subtitle: Text(
                      '${settings.reminderModeFor(prayer).nameAr} • ${_offsetLabel(settings.offsetFor(prayer))}',
                    ),
                    childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    children: <Widget>[
                      DropdownButtonFormField<PrayerReminderMode>(
                        key: ValueKey<String>('prayer-mode-${prayer.name}'),
                        initialValue: settings.reminderModeFor(prayer),
                        decoration: const InputDecoration(
                          labelText: 'نوع التذكير',
                        ),
                        items: <DropdownMenuItem<PrayerReminderMode>>[
                          for (final mode in PrayerReminderMode.values)
                            DropdownMenuItem<PrayerReminderMode>(
                              value: mode,
                              child: Text(mode.nameAr),
                            ),
                        ],
                        onChanged: _changingPrayer == null
                            ? (mode) {
                                if (mode != null) _setMode(prayer, mode);
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>('prayer-offset-${prayer.name}'),
                        initialValue: settings.offsetFor(prayer),
                        decoration: const InputDecoration(
                          labelText: 'تعديل الوقت',
                        ),
                        items: <DropdownMenuItem<int>>[
                          for (final value in _offsetValues(
                            settings.offsetFor(prayer),
                          ))
                            DropdownMenuItem<int>(
                              value: value,
                              child: Text(_offsetLabel(value)),
                            ),
                        ],
                        onChanged: settings.manualTimes.containsKey(prayer) ? null : (value) {
                          if (value != null) store.setOffset(prayer, value);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PrayerCity {
  const _PrayerCity(this.name, this.latitude, this.longitude, this.timezone);
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;
}

const _prayerCities = <_PrayerCity>[
  _PrayerCity('تعز', 13.5795, 44.0209, 'Asia/Aden'),
  _PrayerCity('صنعاء', 15.3694, 44.1910, 'Asia/Aden'),
  _PrayerCity('عدن', 12.7855, 45.0187, 'Asia/Aden'),
  _PrayerCity('إب', 13.9667, 44.1833, 'Asia/Aden'),
  _PrayerCity('الحديدة', 14.7978, 42.9545, 'Asia/Aden'),
  _PrayerCity('المكلا', 14.5425, 49.1242, 'Asia/Aden'),
  _PrayerCity('سيئون', 15.9433, 48.7873, 'Asia/Aden'),
  _PrayerCity('مأرب', 15.4625, 45.3258, 'Asia/Aden'),
];

String _time(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _remaining(Duration value) {
  final safe = value.isNegative ? Duration.zero : value;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  return hours > 0 ? '$hours ساعة و$minutes دقيقة' : '$minutes دقيقة';
}

String _methodName(PrayerCalculationMethod value) => switch (value) {
  PrayerCalculationMethod.muslimWorldLeague => 'رابطة العالم الإسلامي',
  PrayerCalculationMethod.egyptian => 'الهيئة المصرية',
  PrayerCalculationMethod.ummAlQura => 'أم القرى',
};

String _asrName(PrayerAsrMethod value) => switch (value) {
  PrayerAsrMethod.shafi => 'العصر: شافعي',
  PrayerAsrMethod.hanafi => 'العصر: حنفي',
};

String _offsetLabel(int value) => value == 0
    ? 'بدون تعديل'
    : value > 0
    ? '+$value دقيقة'
    : '$value دقيقة';

List<int> _offsetValues(int current) {
  final values = <int>{current};
  for (var value = -60; value <= 60; value += 5) {
    values.add(value);
  }
  final sorted = values.toList()..sort();
  return sorted;
}
