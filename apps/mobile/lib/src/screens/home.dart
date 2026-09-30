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
          Text(
            'مرحبًا بك في ترتيل',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
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
          if (services.features.enabled(TarteelFeature.prayer))
            const DashboardPrayerTimes(),
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
              _shortcut('القراء', Icons.headphones, MobileRoutes.reciters),
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
  const DashboardPrayerTimes({super.key});
  @override
  ConsumerState<DashboardPrayerTimes> createState() =>
      _DashboardPrayerTimesState();
}

class _DashboardPrayerTimesState extends ConsumerState<DashboardPrayerTimes> {
  late Future<PrayerSnapshot> _snapshot;
  Timer? _timer;
  late final PrayerSettingsStore _settings;
  @override
  void initState() {
    super.initState();
    _refresh();
    _settings = ref.read(servicesProvider).prayerSettings;
    _settings.addListener(_refresh);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _refresh();
    });
  }

  void _refresh() {
    final services = ref.read(servicesProvider);
    _snapshot = services.prayerTimes.snapshot(
      settings: services.prayerSettings.value,
    );
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
      final remaining = data.next.time.difference(DateTime.now());
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data.next.prayer.nameAr} القادمة • متبقي ${remaining.inHours}:${(remaining.inMinutes % 60).clamp(0, 59).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                ref.read(servicesProvider).prayerSettings.value.locationName,
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final prayer in data.today.requiredPrayers)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: 24,
                          top: 8,
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
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PrayerTimesPage(),
                  ),
                ),
                child: const Text('مواقيت الصلاة'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
