import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../radio_service.dart';
import '../services.dart';
import '../virtual_radio.dart';

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
  final _search = TextEditingController();
  String? category;
  String? provider;
  String query = '';
  String? pendingStationId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _play(Station station) async {
    final url = station.playbackUrl;
    if (url == null || url.isEmpty) {
      _showError('هذه المحطة غير متاحة للتشغيل حاليًا.');
      return;
    }
    if (Uri.tryParse(url)?.scheme != 'https') {
      _showError(
        'هذه المحطة تستخدم اتصال HTTP غير آمن، لذلك لا تُشغّل في نسخة Android الحالية.',
      );
      return;
    }
    setState(() => pendingStationId = station.id);
    try {
      await ref.read(servicesProvider).playback.playStation(station);
    } catch (error) {
      final webNote = kIsWeb
          ? ' وقد يمنع المتصفح بعض المصادر بسبب سياسات CORS.'
          : '';
      _showError('تعذر تشغيل ${station.nameAr}. حاول مرة أخرى.$webNote');
      debugPrint('Tarteel station playback error: $error');
    } finally {
      if (mounted && pendingStationId == station.id) {
        setState(() => pendingStationId = null);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'إغلاق', onPressed: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(radioProvider);
    final virtual = ref.watch(virtualRadioProvider);
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait<void>([
          ref.read(radioProvider.notifier).refresh(),
          ref.read(virtualRadioProvider.notifier).refresh(),
        ]);
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(child: _VirtualRadioCard(value: virtual)),
          SliverToBoxAdapter(
            child: _CatalogControls(
              controller: _search,
              query: query,
              category: category,
              provider: provider,
              stations: catalog.valueOrNull ?? const <Station>[],
              onQuery: (value) => setState(() => query = value),
              onCategory: (value) => setState(() => category = value),
              onProvider: (value) => setState(() => provider = value),
            ),
          ),
          ...catalog.when(
            loading: () => const <Widget>[
              SliverFillRemaining(hasScrollBody: false, child: LoadingPane()),
            ],
            error: (error, _) => <Widget>[
              SliverFillRemaining(
                hasScrollBody: false,
                child: ErrorPane(
                  error: error,
                  onRetry: () => ref.read(radioProvider.notifier).refresh(),
                ),
              ),
            ],
            data: (stations) => _catalogSlivers(stations),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _catalogSlivers(List<Station> stations) {
    final external = stations
        .where((station) => station.isExternal)
        .toList(growable: false);
    final normalized = query.trim().toLowerCase();
    final filtered = external
        .where((station) {
          if (category != null && station.category != category) return false;
          if (provider != null && station.provider != provider) return false;
          if (normalized.isEmpty) return true;
          return station.nameAr.contains(query.trim()) ||
              (station.nameEn ?? '').toLowerCase().contains(normalized) ||
              (station.providerName ?? '').toLowerCase().contains(normalized) ||
              (station.category ?? '').toLowerCase().contains(normalized);
        })
        .toList(growable: false);

    if (filtered.isEmpty) {
      return const <Widget>[
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyPane(message: 'لا توجد محطات تطابق الاختيار الحالي'),
        ),
      ];
    }

    return <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'إذاعات القرآن',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Text(
                '${filtered.length} محطة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final station = filtered[index];
          return StreamBuilder<MediaItem?>(
            stream: ref.read(servicesProvider).playback.mediaItemStream,
            builder: (context, snapshot) {
              final media = snapshot.data;
              final active =
                  media?.extras?['kind'] == 'station' &&
                  media?.extras?['entity_id'] == station.id;
              return _StationCard(
                station: station,
                active: active,
                pending: pendingStationId == station.id,
                onPlay: () => _play(station),
              );
            },
          );
        },
      ),
    ];
  }
}

class _VirtualRadioCard extends ConsumerWidget {
  const _VirtualRadioCard({required this.value});
  final AsyncValue<VirtualRadioResolution> value;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(servicesProvider).playback;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: value.when(
          loading: () => const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.radio),
                title: Text('إذاعة ترتيل'),
                subtitle: Text('تعذر تحديد مصدر البث الحالي'),
              ),
              FilledButton.icon(
                onPressed: () =>
                    ref.read(virtualRadioProvider.notifier).retry(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
          data: (resolution) {
            final station = resolution.station;
            final program = resolution.program;
            return StreamBuilder<MediaItem?>(
              stream: playback.mediaItemStream,
              builder: (context, mediaSnapshot) {
                final media = mediaSnapshot.data;
                final logicalActive = media?.extras?['kind'] == 'virtual_radio';
                return StreamBuilder<PlaybackState>(
                  stream: playback.playbackStateStream,
                  builder: (context, stateSnapshot) {
                    final state = stateSnapshot.data;
                    final playing = logicalActive && state?.playing == true;
                    final buffering =
                        logicalActive &&
                        (state?.processingState ==
                                AudioProcessingState.loading ||
                            state?.processingState ==
                                AudioProcessingState.buffering);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Artwork(
                              url: resolution.artworkUrl,
                              size: 72,
                              icon: Icons.radio,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          resolution.channelNameAr,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                        ),
                                      ),
                                      const Chip(label: Text('مباشر')),
                                    ],
                                  ),
                                  Text(
                                    program?.titleAr ??
                                        'بث مختار من إذاعات القرآن',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  if (program?.subtitleAr != null)
                                    Text(
                                      program!.subtitleAr!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: <Widget>[
                            if (program != null)
                              _MetaChip(
                                _categoryNames[program.category] ??
                                    program.category,
                              ),
                            if (resolution.isManaged)
                              _MetaChip(
                                'المزود: ${resolution.managedProvider == 'RADIO_CO' ? 'Radio.co' : resolution.managedProvider ?? 'Managed Radio'}',
                              ),
                            if (station != null)
                              _MetaChip('المصدر الحالي: ${station.nameAr}'),
                            if (resolution.isManaged &&
                                resolution.managedStatus != null)
                              _MetaChip(
                                _managedStatusLabel(resolution.managedStatus!),
                              )
                            else if (station?.healthStatus != null)
                              _MetaChip(_healthLabel(station!.healthStatus!)),
                          ],
                        ),
                        if (resolution.nextProgramTitleAr != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            'التالي: ${resolution.nextProgramTitleAr}${resolution.nextChangeAt == null ? '' : ' — ${_timeLabel(resolution.nextChangeAt!)}'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: !resolution.isPlayable
                                    ? null
                                    : () async {
                                        if (buffering) return;
                                        if (playing) {
                                          await playback.pause();
                                        } else if (logicalActive) {
                                          await playback.play();
                                        } else {
                                          await ref
                                              .read(
                                                virtualRadioProvider.notifier,
                                              )
                                              .play();
                                        }
                                      },
                                icon: buffering
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                label: Text(
                                  buffering
                                      ? 'جارٍ الاتصال…'
                                      : playing
                                      ? 'إيقاف مؤقت'
                                      : 'تشغيل إذاعة ترتيل',
                                ),
                              ),
                            ),
                            if (logicalActive) ...<Widget>[
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                tooltip: 'إيقاف',
                                onPressed: () => ref
                                    .read(virtualRadioProvider.notifier)
                                    .stop(),
                                icon: const Icon(Icons.stop),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          resolution.isManaged
                              ? 'الصوت يصل عبر رابط إذاعة ترتيل الثابت من مزود البث المُدار؛ Supabase يحدد البرنامج والمصدر، ولا يتصل Flutter بمصدر الـRelay مباشرةً.'
                              : resolution.managedConfigured
                              ? 'تكامل البث المُدار مهيأ لكنه غير مفعّل بعد؛ يعمل هذا الوضع كبديل تطويري مباشر إلى أن ينجح Sync Schedule واختبار Relay.'
                              : 'إذاعة ترتيل قناة افتراضية تختار مصدرًا خارجيًا متاحًا وفق الجدول؛ الصوت يصل مباشرةً من مزود البث ولا يُعاد بثه عبر خوادم ترتيل.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CatalogControls extends StatelessWidget {
  const _CatalogControls({
    required this.controller,
    required this.query,
    required this.category,
    required this.provider,
    required this.stations,
    required this.onQuery,
    required this.onCategory,
    required this.onProvider,
  });

  final TextEditingController controller;
  final String query;
  final String? category;
  final String? provider;
  final List<Station> stations;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onProvider;

  @override
  Widget build(BuildContext context) {
    final external = stations
        .where((s) => s.isExternal)
        .toList(growable: false);
    final categories =
        external.map((s) => s.category).whereType<String>().toSet().toList()
          ..sort();
    final providers = <String, String>{};
    for (final station in external) {
      final key = station.provider;
      if (key != null && key.isNotEmpty) {
        providers[key] = station.providerName ?? key;
      }
    }
    final providerEntries = providers.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: <Widget>[
          TextField(
            controller: controller,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'ابحث عن إذاعة أو قارئ أو مصدر',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        controller.clear();
                        onQuery('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: onQuery,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                ChoiceChip(
                  label: const Text('كل التصنيفات'),
                  selected: category == null,
                  onSelected: (_) => onCategory(null),
                ),
                const SizedBox(width: 6),
                ...categories.map(
                  (value) => Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      label: Text(_categoryNames[value] ?? value),
                      selected: category == value,
                      onSelected: (_) => onCategory(value),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (providerEntries.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: <Widget>[
                  ChoiceChip(
                    label: const Text('كل المصادر'),
                    selected: provider == null,
                    onSelected: (_) => onProvider(null),
                  ),
                  const SizedBox(width: 6),
                  ...providerEntries.map(
                    (entry) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(entry.value),
                        selected: provider == entry.key,
                        onSelected: (_) => onProvider(entry.key),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StationCard extends ConsumerWidget {
  const _StationCard({
    required this.station,
    required this.active,
    required this.pending,
    required this.onPlay,
  });
  final Station station;
  final bool active;
  final bool pending;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final services = ref.watch(servicesProvider);
    final secure = Uri.tryParse(station.playbackUrl ?? '')?.scheme == 'https';
    final playable = station.isPlayable && secure;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: InkWell(
        onTap: playable ? onPlay : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Artwork(url: station.logoUrl, size: 62, icon: Icons.radio),
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
                    const SizedBox(height: 3),
                    Text(
                      station.providerName ?? station.provider ?? 'مصدر خارجي',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: <Widget>[
                        if (station.category != null)
                          _MetaChip(
                            _categoryNames[station.category] ??
                                station.category!,
                          ),
                        _MetaChip(station.streamType),
                        if (station.healthStatus != null)
                          _MetaChip(_healthLabel(station.healthStatus!)),
                      ],
                    ),
                    if (!secure && station.playbackUrl != null) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'HTTP غير آمن — غير متاح في Android',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: <Widget>[
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
                  if (pending)
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    )
                  else
                    IconButton.filled(
                      tooltip: playable
                          ? (active ? 'إعادة التشغيل' : 'تشغيل')
                          : 'غير متاح',
                      onPressed: playable ? onPlay : null,
                      icon: Icon(active ? Icons.graphic_eq : Icons.play_arrow),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

String _healthLabel(String value) => switch (value.toUpperCase()) {
  'HEALTHY' => 'متاح',
  'DEGRADED' => 'قد يتأخر',
  'UNAVAILABLE' || 'UNREACHABLE' => 'غير متاح',
  'UNSUPPORTED' => 'غير مدعوم',
  _ => 'غير مفحوص',
};

String _managedStatusLabel(String value) => switch (value.toLowerCase()) {
  'onair' => 'Radio.co: على الهواء',
  'offair' => 'Radio.co: خارج الهواء',
  _ => 'Radio.co: ${value.toLowerCase()}',
};

String _timeLabel(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
