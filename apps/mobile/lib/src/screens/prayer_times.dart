import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../local_notifications.dart';
import '../prayer_settings.dart';
import '../prayer_times.dart';
import '../services.dart';
import '../theme.dart';
import 'adhan_library.dart';
import 'learning.dart';

class PrayerTimesPage extends ConsumerStatefulWidget {
  const PrayerTimesPage({super.key});

  @override
  ConsumerState<PrayerTimesPage> createState() => _PrayerTimesPageState();
}

class _PrayerTimesPageState extends ConsumerState<PrayerTimesPage>
    with WidgetsBindingObserver {
  late Future<PrayerSnapshot> _future;
  Timer? _clock;
  bool _openingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final services = ref.read(servicesProvider);
    services.prayerSettings.addListener(_reload);
    _future = _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _reload();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reload();
      unawaited(ref.read(servicesProvider).prayerReminders.reconcile());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
            tooltip: 'الجدول الأسبوعي والشهري',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PrayerCalendarPage(),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
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
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            '${_civilDate(snapshot.today.date)} • ${_hijriDate(snapshot.today.date)}',
            textAlign: TextAlign.center,
          ),
        ),
        if (settings.calculationWarning case final String warning)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(warning, style: TextStyle(color: scheme.error)),
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
                  isNext:
                      snapshot.today.ordered[index].time == snapshot.next.time,
                  isCurrent:
                      _currentPrayer(snapshot.today, now) ==
                      snapshot.today.ordered[index].prayer,
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
    this.isNext = false,
    this.isCurrent = false,
  });

  final PrayerOccurrence occurrence;
  final PrayerReminderMode reminderMode;
  final bool divider;
  final bool isNext;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      ListTile(
        selected: isNext,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.35),
        subtitle: isNext
            ? const Text('القادمة')
            : isCurrent
            ? const Text('الصلاة الحالية')
            : null,
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
    final form = GlobalKey<FormState>();
    final name = TextEditingController(text: current.locationName);
    final latitude = TextEditingController(text: current.latitude.toString());
    final longitude = TextEditingController(text: current.longitude.toString());
    final timezone = TextEditingController(text: current.timezone);
    var calculation = current.calculationMethod;
    var asr = current.asrMethod;
    var locating = false;
    await ref.read(servicesProvider).prayerTimes.initialize();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('الموقع وطريقة الحساب'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  DropdownButtonFormField<_PrayerCity>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'مدن محفوظة — أو أدخل موقعك أدناه',
                    ),
                    items: [
                      for (final city in _prayerCities)
                        DropdownMenuItem(value: city, child: Text(city.name)),
                    ],
                    onChanged: (city) {
                      if (city == null) return;
                      setDialogState(() {
                        name.text = city.name;
                        latitude.text = city.latitude.toString();
                        longitude.text = city.longitude.toString();
                        timezone.text = city.timezone;
                      });
                    },
                  ),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'اسم الموقع'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسم الموقع'
                        : null,
                  ),
                  TextFormField(
                    controller: latitude,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'خط العرض'),
                    validator: (value) => _coordinateError(value, 90),
                  ),
                  TextFormField(
                    controller: longitude,
                    textDirection: TextDirection.ltr,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(labelText: 'خط الطول'),
                    validator: (value) => _coordinateError(value, 180),
                  ),
                  TextFormField(
                    controller: timezone,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(
                      labelText: 'المنطقة الزمنية IANA',
                      helperText:
                          'مثل Asia/Aden أو Europe/London — التوقيت الصيفي تلقائي',
                    ),
                    validator: (value) {
                      try {
                        tz.getLocation(value?.trim() ?? '');
                        return null;
                      } catch (_) {
                        return 'أدخل منطقة زمنية صحيحة';
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: locating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('استخدام موقع الهاتف بإذنك'),
                    onPressed: locating
                        ? null
                        : () async {
                            setDialogState(() => locating = true);
                            try {
                              final result =
                                  await const MethodChannel(
                                    'app.tarteel.tarteel/settings',
                                  ).invokeMapMethod<String, dynamic>(
                                    'getPrayerLocation',
                                  );
                              if (!dialogContext.mounted) return;
                              if (result?['latitude'] is num &&
                                  result?['longitude'] is num) {
                                setDialogState(() {
                                  latitude.text = (result!['latitude'] as num)
                                      .toDouble()
                                      .toStringAsFixed(6);
                                  longitude.text = (result['longitude'] as num)
                                      .toDouble()
                                      .toStringAsFixed(6);
                                  name.text = 'موقعي';
                                  if (result['timezone'] is String)
                                    timezone.text =
                                        result['timezone'] as String;
                                });
                              } else {
                                throw const FormatException(
                                  'LOCATION_UNAVAILABLE',
                                );
                              }
                            } catch (_) {
                              if (dialogContext.mounted)
                                ScaffoldMessenger.of(
                                  dialogContext,
                                ).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تعذّر تحديد الموقع. تحقق من إذن الموقع وGPS أو أدخل الإحداثيات يدويًا.',
                                    ),
                                  ),
                                );
                            } finally {
                              if (dialogContext.mounted)
                                setDialogState(() => locating = false);
                            }
                          },
                  ),
                  DropdownButtonFormField<PrayerCalculationMethod>(
                    initialValue: calculation,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الحساب',
                    ),
                    items: [
                      for (final value in PrayerCalculationMethod.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_methodName(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) calculation = value;
                    },
                  ),
                  DropdownButtonFormField<PrayerAsrMethod>(
                    isExpanded: true,
                    initialValue: asr,
                    decoration: const InputDecoration(labelText: 'حساب العصر'),
                    items: [
                      for (final value in PrayerAsrMethod.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_asrName(value)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) asr = value;
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تُحفظ الإحداثيات محليًا. لا تُرسل إلى Neon أو أي خادم. راجع المواقيت مع تقويم المسجد المحلي.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate())
                  Navigator.pop(dialogContext, true);
              },
              child: const Text('حفظ وإعادة الجدولة'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await ref
          .read(servicesProvider)
          .prayerSettings
          .updateLocation(
            current.copyWith(
              locationName: name.text.trim(),
              latitude: double.parse(latitude.text.trim()),
              longitude: double.parse(longitude.text.trim()),
              timezone: timezone.text.trim(),
              calculationMethod: calculation,
              asrMethod: asr,
            ),
          );
    }
    name.dispose();
    latitude.dispose();
    longitude.dispose();
    timezone.dispose();
  }

  Widget _prayerSoundPicker(
    BuildContext context,
    PrayerKind prayer,
    PrayerSettings settings,
  ) {
    final services = ref.read(servicesProvider);
    final paths = services.adhanLibrary.availablePaths;
    final selected = settings.audioPaths[prayer];
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('sound-${prayer.name}-$selected'),
          initialValue: selected ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'صوت خاص لهذه الصلاة'),
          items: [
            const DropdownMenuItem(value: '', child: Text('الصوت الافتراضي')),
            for (final entry in paths.entries)
              DropdownMenuItem(
                value: entry.value,
                child: Text(
                  services.adhanLibrary.labelFor(entry.key),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (selected != null && !paths.containsValue(selected))
              DropdownMenuItem(
                value: selected,
                child: const Text('الملف المختار سابقًا'),
              ),
          ],
          onChanged: (path) =>
              services.prayerSettings.setPrayerAudio(prayer, path),
        ),
        TextButton.icon(
          onPressed: () => services.adhanAudio.play(
            path: settings.audioPathFor(
              prayer,
              fallback:
                  settings.reminderModeFor(prayer) ==
                      PrayerReminderMode.shortAlert
                  ? 'assets/audio/reminder.wav'
                  : services.adhanAudio.assetPath,
            ),
          ),
          icon: const Icon(Icons.play_arrow),
          label: const Text('اختبار الصوت'),
        ),
        TextButton.icon(
          onPressed: services.adhanAudio.stop,
          icon: const Icon(Icons.stop),
          label: const Text('إيقاف الاختبار'),
        ),
      ],
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
            'تعذّر تفعيل التنبيه. تحقق من إذن الإشعارات والمنبهات الدقيقة ثم أعد المحاولة.',
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
      animation: Listenable.merge([
        store,
        ref.read(servicesProvider).adhanLibrary,
      ]),
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
              if (settings.calculationWarning case final String warning)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    warning,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SectionHeader('التذكيرات المحلية'),
              ListTile(
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('حالة التنبيهات والصلاحيات'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PrayerAlarmStatusPage(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.wb_twilight),
                title: const Text('أذكار الصباح والمساء'),
                subtitle: const Text(
                  'المواعيد والصوت والأذكار المحفوظة محليًا',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const AdhkarPage()),
                ),
              ),
              const Padding(
                padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Text(
                  'تعمل التنبيهات محليًا دون إنترنت. قد تقيد بعض الهواتف التشغيل في الخلفية؛ راجع حالة الصلاحيات واختبر التنبيه مع إغلاق الشاشة.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.library_music_outlined),
                title: const Text('اختيار صوت الأذان'),
                subtitle: const Text('أصوات مدمجة واستيراد ملفات من الهاتف'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdhanLibraryPage(),
                  ),
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
                      SwitchListTile(
                        title: const Text('توقيت يدوي ثابت يوميًا'),
                        subtitle: const Text(
                          'عند إيقافه تُستخدم المواقيت المحسوبة حسب التاريخ والموقع. الوقت اليدوي لا يتغير مع الفصول.',
                        ),
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
                            await store.setManualTime(
                              prayer,
                              chosen.hour * 60 + chosen.minute,
                            );
                          }
                        },
                      ),
                      if (settings.manualTimes.containsKey(prayer))
                        ListTile(
                          title: const Text('موعد الصلاة اليدوي'),
                          subtitle: Text(
                            TimeOfDay(
                              hour: settings.manualTimes[prayer]! ~/ 60,
                              minute: settings.manualTimes[prayer]! % 60,
                            ).format(context),
                          ),
                          trailing: const Icon(Icons.schedule),
                          onTap: () async {
                            final minutes = settings.manualTimes[prayer]!;
                            final chosen = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: minutes ~/ 60,
                                minute: minutes % 60,
                              ),
                            );
                            if (chosen != null) {
                              await store.setManualTime(
                                prayer,
                                chosen.hour * 60 + chosen.minute,
                              );
                            }
                          },
                        ),
                      DropdownButtonFormField<PrayerReminderMode>(
                        isExpanded: true,
                        key: ValueKey<String>('prayer-mode-${prayer.name}'),
                        initialValue: settings.reminderModeFor(prayer),
                        decoration: const InputDecoration(
                          labelText: 'نوع التذكير',
                        ),
                        items: <DropdownMenuItem<PrayerReminderMode>>[
                          for (final mode in PrayerReminderMode.values)
                            DropdownMenuItem<PrayerReminderMode>(
                              value: mode,
                              child: Text(
                                mode.nameAr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: _changingPrayer == null
                            ? (mode) {
                                if (mode != null) _setMode(prayer, mode);
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      if (settings.reminderModeFor(prayer) ==
                              PrayerReminderMode.adhan ||
                          settings.reminderModeFor(prayer) ==
                              PrayerReminderMode.shortAlert) ...[
                        _prayerSoundPicker(context, prayer, settings),
                        Text(
                          'مستوى الصوت: ${(settings.volumeFor(prayer) * 100).round()}٪',
                        ),
                        _PrayerVolumeSlider(
                          value: settings.volumeFor(prayer),
                          onSaved: (value) =>
                              store.setPrayerVolume(prayer, value),
                        ),
                        const Text(
                          'يُطبّق على صوت ترتيل دون تغيير صوت النظام أو تجاوز وضع عدم الإزعاج.',
                        ),
                      ],
                      for (final before in [true, false])
                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          key: ValueKey(
                            'prayer-${before ? 'before' : 'after'}-${prayer.name}-${before ? settings.beforeMinutesFor(prayer) : settings.afterMinutesFor(prayer)}',
                          ),
                          initialValue: before
                              ? settings.beforeMinutesFor(prayer)
                              : settings.afterMinutesFor(prayer),
                          decoration: InputDecoration(
                            labelText: before
                                ? 'تذكير قبل الصلاة'
                                : 'تذكير وأذكار بعد الصلاة',
                          ),
                          items: [
                            for (var minutes = 0; minutes <= 120; minutes++)
                              DropdownMenuItem(
                                value: minutes,
                                child: Text(
                                  minutes == 0 ? 'متوقف' : '$minutes دقيقة',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null)
                              store.setReminderMinutes(
                                prayer,
                                before: before ? value : null,
                                after: before ? null : value,
                              );
                          },
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        isExpanded: true,
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
                              child: Text(
                                _offsetLabel(value),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: settings.manualTimes.containsKey(prayer)
                            ? null
                            : (value) {
                                if (value != null)
                                  store.setOffset(prayer, value);
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
  _PrayerCity('مكة المكرمة', 21.4225, 39.8262, 'Asia/Riyadh'),
  _PrayerCity('القاهرة', 30.0444, 31.2357, 'Africa/Cairo'),
  _PrayerCity('لندن', 51.5074, -0.1278, 'Europe/London'),
  _PrayerCity('نيويورك', 40.7128, -74.006, 'America/New_York'),
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
  PrayerCalculationMethod.karachi => 'جامعة العلوم الإسلامية — كراتشي',
  PrayerCalculationMethod.northAmerica => 'الجمعية الإسلامية لأمريكا الشمالية',
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
  for (var value = -60; value <= 60; value++) {
    values.add(value);
  }
  final sorted = values.toList()..sort();
  return sorted;
}

String? _coordinateError(String? text, double limit) {
  final value = double.tryParse(text?.trim() ?? '');
  return value == null || !value.isFinite || value < -limit || value > limit
      ? 'أدخل قيمة بين ${-limit} و$limit'
      : null;
}

PrayerKind? _currentPrayer(PrayerDay day, DateTime now) {
  PrayerKind? current;
  for (final item in day.requiredPrayers) {
    if (!item.time.isAfter(now)) current = item.prayer;
  }
  return current;
}

/// Civil tabular Hijri date, explicitly labelled approximate; moon-sighting
/// calendars may differ by one or two days.
String _hijriDate(DateTime date) {
  final hijri = civilHijriForDate(date);
  const names = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];
  return '${hijri.day} ${names[hijri.month - 1]} ${hijri.year} هـ — هجري حسابي؛ قد يختلف عن الرؤية';
}

class PrayerCalendarPage extends ConsumerStatefulWidget {
  const PrayerCalendarPage({super.key});
  @override
  ConsumerState<PrayerCalendarPage> createState() => _PrayerCalendarPageState();
}

class _PrayerCalendarPageState extends ConsumerState<PrayerCalendarPage> {
  int _days = 7;
  late Future<List<PrayerDay>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final services = ref.read(servicesProvider);
    _future = services.prayerTimes
        .snapshot(settings: services.prayerSettings.value)
        .then(
          (snapshot) => services.prayerTimes.calendar(
            from: snapshot.today.date,
            days: _days,
            settings: services.prayerSettings.value,
          ),
        );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('جدول مواقيت الصلاة')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 7, label: Text('أسبوعي')),
              ButtonSegment(value: 30, label: Text('شهري — ٣٠ يومًا')),
            ],
            selected: {_days},
            onSelectionChanged: (selection) => setState(() {
              _days = selection.first;
              _reload();
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'المواقيت حسب الموقع والمنطقة الزمنية المحفوظين، وتُحسب على جهازك دون إنترنت. اسحب الجدول أفقيًا لعرض جميع الصلوات.',
          ),
        ),
        Expanded(
          child: FutureBuilder<List<PrayerDay>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return ErrorPane(
                  error: snapshot.error!,
                  onRetry: () => setState(_reload),
                );
              if (!snapshot.hasData) return const LoadingPane();
              return SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('التاريخ')),
                      for (final prayer in PrayerKind.values)
                        DataColumn(label: Text(prayer.nameAr)),
                    ],
                    rows: [
                      for (final day in snapshot.data!)
                        DataRow(
                          cells: [
                            DataCell(Text(_civilDate(day.date, compact: true))),
                            for (final prayer in PrayerKind.values)
                              DataCell(
                                Text(
                                  _time(day.timeFor(prayer)),
                                  textDirection: TextDirection.ltr,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class PrayerAlarmStatusPage extends ConsumerStatefulWidget {
  const PrayerAlarmStatusPage({super.key});
  @override
  ConsumerState<PrayerAlarmStatusPage> createState() =>
      _PrayerAlarmStatusPageState();
}

class _PrayerAlarmStatusPageState extends ConsumerState<PrayerAlarmStatusPage>
    with WidgetsBindingObserver {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  void _load() => _future = ref
      .read(servicesProvider)
      .localNotifications
      .alarmDiagnostics();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(_load);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _testAlarm() async {
    final services = ref.read(servicesProvider);
    if (!await services.localNotifications.requestPermission()) return;
    await services.localNotifications.schedule(
      LocalNotificationRequest(
        id: 8_999_001,
        title: 'ترتيل — اختبار التنبيه',
        body:
            'إذا سمعت هذا الصوت فالتنبيه المحلي يعمل حاليًا. اختبره أيضًا مع إغلاق الشاشة.',
        scheduledAt: DateTime.now().add(const Duration(minutes: 1)),
        timezone: services.prayerSettings.value.timezone,
        payload: '/prayer-times',
        audioPath:
            services.adhanLibrary.selectedPath ?? 'assets/audio/adhan.ogg',
        channel: LocalNotificationChannel.adhan,
      ),
    );
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تمت جدولة اختبار بعد دقيقة. أغلق الشاشة للتحقق من تشغيله في الخلفية.',
          ),
        ),
      );
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.read(servicesProvider).localNotifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('حالة التنبيهات والصلاحيات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return ErrorPane(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            );
          if (!snapshot.hasData) return const LoadingPane();
          final status = snapshot.data!;
          Widget row(
            String title,
            bool active,
            String explanation,
            VoidCallback action,
          ) => ListTile(
            leading: Icon(
              active ? Icons.check_circle_outline : Icons.warning_amber,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.error,
            ),
            title: Text(title),
            subtitle: Text(
              '${active ? 'مفعّل' : 'يحتاج إلى مراجعة'} • $explanation',
            ),
            onTap: action,
            trailing: const Icon(Icons.open_in_new),
          );
          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              row(
                'إذن الإشعارات',
                status['notifications'] == true,
                'يُسمح بإظهار تنبيهات الصلاة.',
                () => notifications.openSystemSettings(),
              ),
              row(
                'المنبهات والتذكيرات الدقيقة',
                status['exactAlarms'] == true,
                'دون هذا الإذن قد يتأخر التنبيه.',
                () => notifications.openAlarmSettings(),
              ),
              row(
                'قناة الأذان',
                status['alarmChannelEnabled'] == true,
                'تحقق أن قناة الأذان مفعّلة في Android.',
                () => notifications.openSystemSettings(),
              ),
              row(
                'التشغيل في الخلفية',
                status['batteryUnrestricted'] == true,
                'سياسة البطارية قد توقف الأذان على بعض الأجهزة.',
                () => notifications.openBatterySettings(),
              ),
              ListTile(
                leading: const Icon(Icons.volume_up_outlined),
                title: const Text('صوت منبهات النظام'),
                subtitle: Text(
                  '${status['alarmVolume'] ?? '—'} / ${status['alarmVolumeMax'] ?? '—'} • راجع مستوى الصوت وعدم الإزعاج من إعدادات الهاتف.',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('التنبيهات المحلية المجدولة'),
                subtitle: Text(
                  '${status['scheduledCount'] ?? 0} تنبيه. تجدد المواقيت عند فتح التطبيق؛ عند إضافة تذكيرات قبل/بعد الصلاة تكفي النافذة ٢٨ يومًا، وإلا ٤٥ يومًا.',
                ),
              ),
              if (status['lastReadyAt'] is num &&
                  (status['lastReadyAt'] as num) > 0)
                ListTile(
                  leading: const Icon(Icons.play_circle_outline),
                  title: const Text('آخر تجهيز للصوت في Android'),
                  subtitle: Text(
                    '${DateTime.fromMillisecondsSinceEpoch((status['lastReadyAt'] as num).toInt()).toLocal()}\nتجهيز الملف لا يؤكد سماعه؛ راجع مستوى الصوت وجرّب مع إغلاق الشاشة.',
                  ),
                ),
              if (status['lastFailure'] is String &&
                  (status['lastFailure'] as String).isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('آخر مشكلة مسجلة'),
                  subtitle: Text(status['lastFailure'] as String),
                ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'لا يمكن ضمان التنبيه إذا أوقفت التطبيق إجباريًا أو منع نظام الهاتف العمل في الخلفية. بعد إعادة التشغيل أو تحديث التطبيق تُستعاد التنبيهات المحفوظة. بعد تغيير الموقع أو إعدادات التوقيت افتح ترتيل لتحديث حساب المواقيت.',
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FilledButton.icon(
                  onPressed: _testAlarm,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('اختبار الأذان بعد دقيقة'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _civilDate(DateTime date, {bool compact = false}) {
  const weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  final label = '${weekdays[date.weekday - 1]} ${date.day}/${date.month}';
  return compact ? label : '$label/${date.year}';
}

class _PrayerVolumeSlider extends StatefulWidget {
  const _PrayerVolumeSlider({required this.value, required this.onSaved});
  final double value;
  final ValueChanged<double> onSaved;
  @override
  State<_PrayerVolumeSlider> createState() => _PrayerVolumeSliderState();
}

class _PrayerVolumeSliderState extends State<_PrayerVolumeSlider> {
  late double _volume = widget.value;
  @override
  void didUpdateWidget(covariant _PrayerVolumeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _volume = widget.value;
  }

  @override
  Widget build(BuildContext context) => Slider(
    value: _volume,
    divisions: 10,
    label: '${(_volume * 100).round()}٪',
    onChanged: (value) => setState(() => _volume = value),
    onChangeEnd: widget.onSaved,
  );
}
