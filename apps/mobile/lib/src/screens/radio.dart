import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

const _categoryNames = <String, String>{
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

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key});
  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  late Future<List<Station>> future;
  String filter = 'ALL';
  String? category;
  @override
  void initState() {
    super.initState();
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر تشغيل ${station.nameAr}. تحقق من الاتصال أو أعد المحاولة.',
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
      if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData)
        return const LoadingPane();
      if (snapshot.hasError && !snapshot.hasData)
        return ErrorPane(error: snapshot.error!, onRetry: () => reload(true));
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
      final services = ref.watch(servicesProvider);
      return Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment(value: 'ALL', label: Text('الكل')),
                ButtonSegment(value: 'INTERNAL', label: Text('ترتيل')),
                ButtonSegment(value: 'EXTERNAL', label: Text('خارجي')),
              ],
              selected: <String>{filter},
              onSelectionChanged: (values) => setState(() {
                filter = values.first;
                if (filter == 'INTERNAL') category = null;
              }),
            ),
          ),
          if (filter != 'INTERNAL')
            SizedBox(
              height: 44,
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
                        label: Text(_categoryNames[value] ?? value),
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
                ? const EmptyPane()
                : RefreshIndicator(
                    onRefresh: () async {
                      reload(true);
                      await future;
                    },
                    child: ListView(
                      children: groups.entries
                          .expand((entry) {
                            final title = entry.key == 'INTERNAL'
                                ? 'إذاعة ترتيل'
                                : _categoryNames[entry.key] ?? entry.key;
                            return <Widget>[
                              SectionHeader(title),
                              ...entry.value.map(
                                (station) => Card(
                                  child: ListTile(
                                    leading: Artwork(url: station.logoUrl),
                                    title: Text(station.nameAr),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          station.isInternal
                                              ? 'بث ترتيل الداخلي'
                                              : '${station.providerName ?? station.provider ?? 'مصدر خارجي'} • ${station.streamType}',
                                        ),
                                        if (station.healthStatus != null)
                                          Text(
                                            'الحالة: ${station.healthStatus}',
                                          ),
                                        if (station.attribution != null)
                                          Text(
                                            station.attribution!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: <Widget>[
                                        AnimatedBuilder(
                                          animation: services.favorites,
                                          builder: (context, _) => IconButton(
                                            tooltip: 'المفضلة',
                                            onPressed: () => services.favorites
                                                .toggleStation(station.id),
                                            icon: Icon(
                                              services.favorites.isStation(
                                                    station.id,
                                                  )
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'تشغيل',
                                          onPressed: station.isPlayable
                                              ? () => _play(station)
                                              : null,
                                          icon: const Icon(
                                            Icons.play_circle_fill,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
