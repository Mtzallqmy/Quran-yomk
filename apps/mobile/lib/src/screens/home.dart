import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feature_manager.dart';
import '../models.dart';
import '../navigation.dart';
import '../playback_ui.dart';
import '../prayer_settings.dart';
import '../prayer_times.dart';
import '../services.dart';
import '../reading_card.dart';
import '../theme.dart';
import 'prayer_times.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late Future<List<Station>> _stations;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _stations = ref.read(servicesProvider).repository.stations();
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تشغيل المحتوى حاليًا. حاول مرة أخرى.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([
        services.mushaf,
        services.quranPlayback,
        services.features,
      ]),
      builder: (context, _) => ListView(
        key: const PageStorageKey('home-dashboard'),
        padding: const EdgeInsets.all(16),
        children: [
          const _HomeWelcome(),
          const SizedBox(height: 16),
          if (services.features.enabled(TarteelFeature.prayer))
            const DashboardPrayerTimes(),
          const SizedBox(height: 8),
          ContinueReadingCard(
            position: services.mushaf.lastPosition,
            onOpen: () {
              final last = services.mushaf.lastPosition;
              Navigator.pushNamed(
                context,
                last == null ? MobileRoutes.quran : MobileRoutes.reader,
                arguments: last?.pageNumber,
              );
            },
          ),
          if (services.quranPlayback.last case final session?)
            Card(
              child: ListTile(
                leading: const Icon(Icons.headphones),
                title: const Text('استكمل الاستماع'),
                subtitle: Text(
                  'السورة ${session.surahNumber} • ${session.reciterName}\n${session.position.inMinutes}:${(session.position.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                trailing: IconButton(
                  tooltip: 'استكمال التشغيل',
                  icon: const Icon(Icons.play_arrow),
                  onPressed: _busy
                      ? null
                      : () => _action(
                          () => resumeQuranListening(services, session),
                        ),
                ),
              ),
            ),
          if (services.features.enabled(TarteelFeature.radio))
            FutureBuilder<List<Station>>(
              future: _stations,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return snapshot.hasError
                      ? Card(
                          child: ListTile(
                            title: const Text('البث غير متاح حاليًا'),
                            trailing: IconButton(
                              tooltip: 'إعادة المحاولة',
                              icon: const Icon(Icons.refresh),
                              onPressed: () => setState(() {
                                _stations = services.repository.stations(
                                  refresh: true,
                                );
                              }),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                final values = snapshot.data!.where(
                  (station) => station.isPlayable,
                );
                if (values.isEmpty) return const SizedBox.shrink();
                final featured = values.where((station) => station.isFeatured);
                final station = featured.isEmpty
                    ? values.first
                    : featured.first;
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.radio),
                    title: Text(station.nameAr),
                    subtitle: const Text('بث مباشر • LIVE'),
                    trailing: IconButton(
                      tooltip: 'تشغيل المحطة',
                      icon: const Icon(Icons.play_arrow),
                      onPressed: _busy
                          ? null
                          : () => _action(
                              () => services.playback.playStation(station),
                            ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _shortcut('المصحف', Icons.menu_book, MobileRoutes.quran),
              _shortcut('التلاوات', Icons.headphones, MobileRoutes.reciters),
              if (services.features.enabled(TarteelFeature.radio))
                _shortcut('الإذاعات', Icons.radio_outlined, MobileRoutes.radio),
              if (services.features.enabled(TarteelFeature.offlineDownloads))
                _shortcut(
                  'التنزيلات',
                  Icons.download_outlined,
                  MobileRoutes.downloads,
                ),
              _shortcut(
                'المفضلة',
                Icons.favorite_border,
                MobileRoutes.favorites,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shortcut(String label, IconData icon, String route) => ActionChip(
    avatar: Icon(icon),
    label: Text(label),
    onPressed: () => Navigator.pushNamed(context, route),
  );
}

class DashboardPrayerTimes extends ConsumerStatefulWidget {
  const DashboardPrayerTimes({super.key, this.clock});

  /// Injectable clock keeps countdown and local calculations on one instant.
  final DateTime Function()? clock;
  @override
  ConsumerState<DashboardPrayerTimes> createState() =>
      _DashboardPrayerTimesState();
}

class _DashboardPrayerTimesState extends ConsumerState<DashboardPrayerTimes> {
  late Future<PrayerSnapshot> _snapshot;
  Timer? _timer;
  late DateTime _now;
  late DateTime _lastRefresh;
  DateTime? _nextPrayerAt;
  late final PrayerSettingsStore _settings;
  @override
  void initState() {
    super.initState();
    _now = _readNow();
    _lastRefresh = _now;
    _refresh();
    _settings = ref.read(servicesProvider).prayerSettings;
    _settings.addListener(_refresh);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = _readNow());
      if ((_nextPrayerAt != null && !_nextPrayerAt!.isAfter(_now)) ||
          _now.difference(_lastRefresh).abs() >= const Duration(minutes: 1)) {
        _nextPrayerAt = null;
        _refresh();
      }
    });
  }

  DateTime _readNow() => widget.clock?.call() ?? DateTime.now();

  void _refresh() {
    _now = _readNow();
    _lastRefresh = _now;
    final services = ref.read(servicesProvider);
    _snapshot = services.prayerTimes
        .snapshot(now: _now, settings: services.prayerSettings.value)
        .then((snapshot) {
          _nextPrayerAt = snapshot.next.time;
          return snapshot;
        });
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings.removeListener(_refresh);
    super.dispose();
  }

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => FutureBuilder<PrayerSnapshot>(
    future: _snapshot,
    builder: (context, snapshot) {
      final data = snapshot.data;
      if (data == null) return const SizedBox.shrink();
      final remaining = data.next.time.difference(_now);
      final seconds = remaining.inSeconds.clamp(0, 172800);
      final countdown =
          '${(seconds ~/ 3600).toString().padLeft(2, '0')}:${((seconds ~/ 60) % 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [TarteelTheme.primary, TarteelTheme.deepGreen],
            ),
          ),
          child: CustomPaint(
            painter: const IslamicGeometryPainter(color: Color(0x15FFFFFF)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الصلاة القادمة'),
                              Text(
                                data.next.prayer.nameAr,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.mosque_outlined,
                          size: 34,
                          color: Color(0xFF83D6D4),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Semantics(
                      label:
                          'الوقت المتبقي ${remaining.inHours.clamp(0, 48)} ساعة و${remaining.inMinutes.clamp(0, 2880) % 60} دقيقة',
                      excludeSemantics: true,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            countdown,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Colors.white,
                          size: 16,
                        ),
                        Text(
                          ref
                              .read(servicesProvider)
                              .prayerSettings
                              .value
                              .locationName,
                        ),
                        Text('• ${_time(data.next.time)}'),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: Color(0x40FFFFFF)),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final prayer in data.today.requiredPrayers)
                            Container(
                              margin: const EdgeInsetsDirectional.only(end: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: prayer.prayer == data.next.prayer
                                    ? const Color(0x33FFFFFF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(prayer.prayer.nameAr),
                                  Text(_time(prayer.time)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const PrayerTimesPage(),
                          ),
                        ),
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 20,
                        ),
                        label: const Text('المواقيت وإعدادات الأذان'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _HomeWelcome extends StatelessWidget {
  const _HomeWelcome();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.auto_awesome_outlined,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('مرحبًا بك في ترتيل', style: theme.textTheme.titleLarge),
              Text(
                'قراءةٌ تُنير يومك، وذكرٌ يطمئن قلبك',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'الإعدادات',
          onPressed: () => Navigator.pushNamed(context, MobileRoutes.settings),
          icon: const Icon(Icons.tune_outlined),
        ),
      ],
    );
  }
}
