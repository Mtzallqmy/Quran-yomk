import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feature_manager.dart';
import '../learning.dart';
import '../navigation.dart';
import '../prayer_settings.dart';
import '../prayer_times.dart';
import '../services.dart';
import '../theme.dart';
import 'learning.dart';
import 'prayer_times.dart';

class WorshipPage extends ConsumerStatefulWidget {
  const WorshipPage({super.key});

  @override
  ConsumerState<WorshipPage> createState() => _WorshipPageState();
}

class _WorshipPageState extends ConsumerState<WorshipPage> {
  late final PrayerSettingsStore _settings;
  late final AppLifecycleListener _lifecycle;
  late Future<PrayerSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _settings = ref.read(servicesProvider).prayerSettings;
    _snapshot = _load();
    _settings.addListener(_refresh);
    _lifecycle = AppLifecycleListener(onResume: _refresh);
  }

  Future<PrayerSnapshot> _load() => ref
      .read(servicesProvider)
      .prayerTimes
      .snapshot(settings: _settings.value);

  void _refresh() => setState(() => _snapshot = _load());

  @override
  void dispose() {
    _settings.removeListener(_refresh);
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('عبادتي')),
      body: ListenableBuilder(
        listenable: services.features,
        builder: (context, _) {
          final prayerEnabled = services.features.enabled(
            TarteelFeature.prayer,
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(TarteelTokens.spaceMd),
                children: [
                  if (prayerEnabled) ...[
                    _QiblaCard(
                      settings: _settings.value,
                      degrees: services.prayerTimes.qiblaBearing(
                        _settings.value,
                      ),
                    ),
                    _FastingCard(snapshot: _snapshot, retry: _refresh),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.mosque_outlined),
                        title: const Text('مواقيت الصلاة وإعدادات الأذان'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const PrayerTimesPage(),
                          ),
                        ),
                      ),
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.alarm_outlined),
                        title: const Text('التنبيهات الشخصية'),
                        onTap: () => Navigator.pushNamed(
                          context,
                          MobileRoutes.personalAlarms,
                        ),
                      ),
                    ),
                  ],
                  if (services.features.enabled(TarteelFeature.adhkar))
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.wb_twilight),
                        title: const Text('أذكاري'),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AdhkarPage(),
                          ),
                        ),
                      ),
                    ),
                  _TasbihCard(store: services.learning),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QiblaCard extends StatelessWidget {
  const _QiblaCard({required this.settings, required this.degrees});
  final PrayerSettings settings;
  final double? degrees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bearing = degrees;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(TarteelTokens.spaceMd),
        child: Column(
          children: [
            Text('اتجاه القبلة', style: theme.textTheme.titleLarge),
            Text(settings.locationName),
            if (bearing == null)
              const Text('يتعذر حساب اتجاه من هذا الموضع.')
            else ...[
              const SizedBox(height: 12),
              ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 96,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('ش'),
                          ),
                        ),
                        Transform.rotate(
                          angle: bearing * math.pi / 180,
                          child: Icon(
                            Icons.navigation_rounded,
                            size: 44,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${bearing.toStringAsFixed(1)}° مع عقارب الساعة من الشمال الحقيقي',
              ),
              const Text('اضبط أعلى الرسم على الشمال عند الاستعانة بخريطة.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _FastingCard extends StatelessWidget {
  const _FastingCard({required this.snapshot, required this.retry});
  final Future<PrayerSnapshot> snapshot;
  final VoidCallback retry;

  String _format(TimeOfDay time, BuildContext context) =>
      MaterialLocalizations.of(context).formatTimeOfDay(time);

  @override
  Widget build(BuildContext context) => Card(
    child: FutureBuilder<PrayerSnapshot>(
      future: snapshot,
      builder: (context, result) {
        final day = result.data?.today;
        if (result.hasError) {
          return ListTile(
            title: const Text('تعذر حساب مواقيت الصيام'),
            trailing: IconButton(
              onPressed: retry,
              tooltip: 'إعادة المحاولة',
              icon: const Icon(Icons.refresh),
            ),
          );
        }
        if (day == null) {
          return const ListTile(title: Text('جارٍ حساب مواقيت الصيام'));
        }
        final hijri = civilHijriForDate(day.date);
        final fajr = _format(
          TimeOfDay.fromDateTime(day.timeFor(PrayerKind.fajr)),
          context,
        );
        final maghrib = _format(
          TimeOfDay.fromDateTime(day.timeFor(PrayerKind.maghrib)),
          context,
        );
        return ListTile(
          leading: const Icon(Icons.nights_stay_outlined),
          title: Text(
            hijri.month == 9 ? 'مواقيت اليوم في رمضان' : 'مواقيت الصيام اليوم',
          ),
          subtitle: Text(
            'الفجر $fajr · المغرب $maghrib\\n${hijri.day}/${hijri.month}/${hijri.year} هـ · تقويم حسابي',
          ),
        );
      },
    ),
  );
}

class _TasbihCard extends StatefulWidget {
  const _TasbihCard({required this.store});
  final LearningStore store;

  @override
  State<_TasbihCard> createState() => _TasbihCardState();
}

class _TasbihCardState extends State<_TasbihCard> {
  bool _saving = false;

  Future<void> _change(int next) async {
    setState(() => _saving = true);
    final saved = await widget.store.setTasbihCount(next);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ العدّاد. حاول مرة أخرى.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(TarteelTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('عداد التسبيح', style: Theme.of(context).textTheme.titleMedium),
          Text(
            '${widget.store.tasbihCount}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () => _change(widget.store.tasbihCount + 1),
                icon: const Icon(Icons.add),
                label: const Text('زيادة العدّاد'),
              ),
              TextButton(
                onPressed: _saving || widget.store.tasbihCount == 0
                    ? null
                    : () => _change(0),
                child: const Text('تصفير'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
