import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'library.dart';
import 'radio.dart';
import 'reciters.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final controller = TextEditingController();
  Timer? debounce;
  SearchBundle result = const SearchBundle(
    stations: <Station>[],
    reciters: <Reciter>[],
    surahs: <Surah>[],
  );
  bool loading = false;
  Object? error;

  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> runSearch(String query) async {
    if (query.trim().length < 2) {
      setState(() {
        result = const SearchBundle(
          stations: <Station>[],
          reciters: <Reciter>[],
          surahs: <Surah>[],
        );
        error = null;
        loading = false;
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final next = await ref.read(servicesProvider).repository.search(query);
      if (mounted) setState(() => result = next);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _play(Station station) async {
    try {
      await ref.read(servicesProvider).playback.playStation(station);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يتم الآن تشغيل ${station.nameAr}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تشغيل هذا البث الآن.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total =
        result.stations.length + result.reciters.length + result.surahs.length;
    return Scaffold(
      appBar: AppBar(title: const Text('البحث')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح',
                        onPressed: () {
                          controller.clear();
                          runSearch('');
                        },
                        icon: const Icon(Icons.close),
                      ),
                hintText: 'محطة، قارئ، أو سورة',
              ),
              onChanged: (value) {
                setState(() {});
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => runSearch(value),
                );
              },
            ),
          ),
          if (error != null)
            Expanded(
              child: ErrorPane(
                error: error!,
                onRetry: () => runSearch(controller.text),
              ),
            )
          else if (controller.text.trim().length < 2)
            const Expanded(
              child: EmptyPane(message: 'اكتب حرفين على الأقل للبحث'),
            )
          else if (!loading && total == 0)
            const Expanded(child: EmptyPane(message: 'لا توجد نتائج'))
          else
            Expanded(
              child: ListView(
                children: <Widget>[
                  if (result.stations.isNotEmpty) ...<Widget>[
                    const SectionHeader('الإذاعات'),
                    for (final station in result.stations)
                      ListTile(
                        leading: Artwork(url: station.logoUrl),
                        title: Text(station.nameAr),
                        subtitle: Text(stationHealthLabel(station)),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StationDetailPage(station: station),
                          ),
                        ),
                        trailing: IconButton.filledTonal(
                          tooltip: 'تشغيل',
                          onPressed: station.isPlayable
                              ? () => _play(station)
                              : null,
                          icon: const Icon(Icons.play_arrow),
                        ),
                      ),
                  ],
                  if (result.reciters.isNotEmpty) ...<Widget>[
                    const SectionHeader('القراء'),
                    for (final reciter in result.reciters)
                      ListTile(
                        leading: Artwork(
                          url: reciter.imageUrl,
                          icon: Icons.person_outline,
                        ),
                        title: Text(reciter.nameAr),
                        subtitle: reciter.rewaya == null
                            ? null
                            : Text(reciter.rewaya!),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ReciterDetailPage(reciter: reciter),
                          ),
                        ),
                      ),
                  ],
                  if (result.surahs.isNotEmpty) ...<Widget>[
                    const SectionHeader('السور'),
                    for (final surah in result.surahs)
                      ListTile(
                        leading: CircleAvatar(child: Text('${surah.number}')),
                        title: Text(surah.nameAr),
                        subtitle: Text('${surah.nameEn} • ${surah.ayahCount} آية'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => SurahDetailPage(surah: surah),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
