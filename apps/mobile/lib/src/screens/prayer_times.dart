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
        MaterialPageRoute<void>(
          builder: (_) => const PrayerSettingsPage(),
        ),
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
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                ),
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
              for (var index = 0; index < snapshot.today.ordered.length; index++)
                _PrayerTimeRow(
                  occurrence: snapshot.today.ordered[index],
                  reminderEnabled:
                      settings.remindersEnabled &&
                      snapshot.today.ordered[index].prayer.isRequiredPrayer,
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
    required this.reminderEnabled,
    required this.divider,
  });

  final PrayerOccurrence occurrence;
  final bool reminderEnabled;
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
            if (reminderEnabled) ...<Widget>[
              const SizedBox(width: 10),
              const Tooltip(
                message: 'التذكير مفعل',
                child: Icon(Icons.notifications_active_outlined, size: 20),
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
  ConsumerState<PrayerSettingsPage> createState() =>
      _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends ConsumerState<PrayerSettingsPage> {
  bool _changingPermission = false;

  Future<void> _setReminders(bool enabled) async {
    if (_changingPermission) return;
    setState(() => _changingPermission = true);
    final accepted = await ref
        .read(servicesProvider)
        .prayerReminders
        .setEnabled(enabled);
    if (!mounted) return;
    setState(() => _changingPermission = false);
    if (enabled && !accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لم تُمنح صلاحية الإشعارات. لم يتم تفعيل التذكيرات.'),
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
              ),
              ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('طريقة الحساب'),
                subtitle: Text(
                  '${_methodName(settings.calculationMethod)} • ${_asrName(settings.asrMethod)}',
                ),
              ),
              const SectionHeader('التذكيرات المحلية'),
              SwitchListTile(
                secondary: _changingPermission
                    ? const SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.notifications_active_outlined),
                title: const Text('تذكير عند دخول وقت الصلاة'),
                subtitle: const Text(
                  'إشعار نصي محلي دون إنترنت، من دون تشغيل صوت الأذان.',
                ),
                value: settings.remindersEnabled,
                onChanged: _changingPermission ? null : _setReminders,
              ),
              ExpansionTile(
                leading: const Icon(Icons.tune),
                title: const Text('ضبط الدقائق'),
                subtitle: const Text('تقديم أو تأخير وقت كل صلاة عند الحاجة'),
                children: <Widget>[
                  for (final prayer in PrayerKind.values)
                    ListTile(
                      title: Text(prayer.nameAr),
                      trailing: DropdownButton<int>(
                        value: settings.offsetFor(prayer),
                        onChanged: (value) {
                          if (value != null) store.setOffset(prayer, value);
                        },
                        items: <DropdownMenuItem<int>>[
                          for (final value in _offsetValues(
                            settings.offsetFor(prayer),
                          ))
                            DropdownMenuItem<int>(
                              value: value,
                              child: Text(_offsetLabel(value)),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

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
