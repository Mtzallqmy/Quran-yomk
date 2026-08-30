import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

const categoryNames = <String, String>{
  'QURAN_GENERAL': 'إذاعات القرآن',
  'RECITER': 'القراء',
  'TAFSEER': 'التفسير',
  'HADITH': 'الحديث',
  'SEERAH': 'السيرة',
  'SAHABAH': 'الصحابة',
  'ADHKAR': 'الأذكار',
  'RUQYAH': 'الرقية',
  'FATWA': 'الفتاوى',
  'QURAN_TRANSLATION': 'ترجمات القرآن',
  'QURAN_SURAH': 'سور مختارة',
  'LIVE_TV_AUDIO': 'البث المباشر',
  'OTHER': 'أخرى',
};

String stationHealthLabel(Station station) {
  switch (station.healthStatus) {
    case 'HEALTHY':
      return 'متاح الآن';
    case 'DEGRADED':
      return 'متاح — الاتصال متذبذب';
    case 'UNAVAILABLE':
      return 'غير متاح حاليًا';
    case 'UNKNOWN':
      return station.isPlayable ? 'جاهز للتشغيل' : 'لم يتم التحقق بعد';
    default:
      return station.isPlayable ? 'جاهز للتشغيل' : 'غير متاح';
  }
}

class RadioBrowsePage extends StatelessWidget {
  const RadioBrowsePage({
    super.key,
    this.initialCategory,
    this.initialSource,
    this.title = 'الإذاعة',
  });
  final String? initialCategory;
  final String? initialSource;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: RadioPage(
      initialCategory: initialCategory,
      initialSource: initialSource,
    ),
  );
}

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key, this.initialCategory, this.initialSource});
  final String? initialCategory;
  final String? initialSource;

  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  late Future<List<Station>> future;
  late String filter;
  String? category;

  @override
  void initState() {
    super.initState();
    filter = widget.initialSource ?? 'ALL';
    category = widget.initialCategory;
    future = ref.read(servicesProvider).repository.stations();
  }

  void reload([bool refresh = false]) => setState(
    () => future = ref
        .read(servicesProvider)
        .repository
        .stations(refresh: refresh),
  );

  Future<void> _play(Station station) async {
    try {
      await ref.read(servicesProvider).playback.playStation(station);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text('يتم الآن تشغيل ${station.nameAr}'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل ${station.nameAr}. قد يكون البث متوقفًا مؤقتًا.',
          ),
          action: SnackBarAction(
            label: 'إعادة المحاولة',
            onPressed: () => _play(station),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Station>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const LoadingPane();
      }
      if (snapshot.hasError && !snapshot.hasData) {
        return ErrorPane(error: snapshot.error!, onRetry: () => reload(true));
      }
      final all = snapshot.data ?? const <Station>[];
      final categories =
          all.map((s) => s.category).whereType<String>().toSet().toList()
            ..sort();
      final filtered = all
          .where(
            (station) =>
                (filter == 'ALL' || station.source == filter) &&
                (category == null || station.category == category),
          )
          .toList(growable: false);
      final groups = <String, List<Station>>{};
      for (final station in filtered) {
        final key = station.isInternal
            ? 'INTERNAL'
            : station.category ?? 'OTHER';
        groups.putIfAbsent(key, () => <Station>[]).add(station);
      }
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: 'ALL', label: Text('الكل')),
                ButtonSegment(value: 'EXTERNAL', label: Text('بث مباشر')),
                ButtonSegment(value: 'INTERNAL', label: Text('ترتيل')),
              ],
              selected: <String>{filter},
              onSelectionChanged: (values) => setState(() {
                filter = values.first;
                if (filter == 'INTERNAL') category = null;
              }),
            ),
          ),
          if (filter != 'INTERNAL' && categories.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: const Text('كل التصنيفات'),
                      selected: category == null,
                      onSelected: (_) => setState(() => category = null),
                    ),
                  ),
                  ...categories.map(
                    (value) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(categoryNames[value] ?? value),
                        selected: category == value,
                        onSelected: (_) => setState(() => category = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: filtered.isEmpty
                ? const _RadioEmptyState()
                : RefreshIndicator(
                    onRefresh: () async {
                      reload(true);
                      await future;
                    },
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: groups.entries
                          .expand((entry) {
                            final title = entry.key == 'INTERNAL'
                                ? 'إذاعة ترتيل'
                                : categoryNames[entry.key] ?? entry.key;
                            return <Widget>[
                              SectionHeader(title),
                              ...entry.value.map(
                                (station) => _StationCard(
                                  station: station,
                                  onPlay: () => _play(station),
                                ),
                              ),
                            ];
                          })
                          .toList(growable: false),
                    ),
                  ),
          ),
        ],
      );
    },
  );
}

class _RadioEmptyState extends StatelessWidget {
  const _RadioEmptyState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.radio_outlined, size: 54),
          SizedBox(height: 12),
          Text('لا توجد إذاعات متاحة ضمن هذا الفلتر الآن.'),
        ],
      ),
    ),
  );
}

class _StationCard extends ConsumerWidget {
  const _StationCard({required this.station, required this.onPlay});
  final Station station;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => StationDetailPage(station: station),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Artwork(url: station.logoUrl, size: 58),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        station.nameAr,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        station.isInternal
                            ? 'بث ترتيل الداخلي'
                            : station.providerName ??
                                  station.provider ??
                                  'مصدر خارجي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(
                            station.isPlayable
                                ? Icons.check_circle_outline
                                : Icons.info_outline,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              stationHealthLabel(station),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedBuilder(
                  animation: services.favorites,
                  builder: (context, _) => IconButton(
                    tooltip: 'المفضلة',
                    onPressed: () =>
                        services.favorites.toggleStation(station.id),
                    icon: Icon(
                      services.favorites.isStation(station.id)
                          ? Icons.favorite
                          : Icons.favorite_border,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: station.isPlayable ? 'تشغيل' : 'غير متاح',
                  onPressed: station.isPlayable ? onPlay : null,
                  icon: const Icon(Icons.play_arrow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StationDetailPage extends ConsumerStatefulWidget {
  const StationDetailPage({super.key, required this.station});
  final Station station;

  @override
  ConsumerState<StationDetailPage> createState() => _StationDetailPageState();
}

class _StationDetailPageState extends ConsumerState<StationDetailPage> {
  bool starting = false;

  Future<void> _play() async {
    if (starting || !widget.station.isPlayable) return;
    setState(() => starting = true);
    try {
      await ref.read(servicesProvider).playback.playStation(widget.station);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم الآن تشغيل ${widget.station.nameAr}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر بدء البث. حاول مرة أخرى بعد قليل.')),
      );
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final station = widget.station;
    final services = ref.watch(servicesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(station.nameAr)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          Center(child: Artwork(url: station.logoUrl, size: 112)),
          const SizedBox(height: 18),
          Text(
            station.nameAr,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(stationHealthLabel(station), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: station.isPlayable && !starting ? _play : null,
            icon: starting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(
              station.isPlayable ? 'تشغيل البث الآن' : 'البث غير متاح',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => services.favorites.toggleStation(station.id),
            icon: const Icon(Icons.favorite_border),
            label: const Text('إضافة أو إزالة من المفضلة'),
          ),
          const SizedBox(height: 24),
          _DetailRow(
            label: 'التصنيف',
            value:
                categoryNames[station.category] ??
                station.category ??
                'غير مصنف',
          ),
          _DetailRow(
            label: 'المصدر',
            value: station.isInternal
                ? 'ترتيل'
                : station.providerName ?? station.provider ?? 'خارجي',
          ),
          _DetailRow(label: 'نوع البث', value: station.streamType),
          if (station.attribution != null)
            _DetailRow(label: 'الإسناد', value: station.attribution!),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 90,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
