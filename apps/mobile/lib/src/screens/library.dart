import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryData {
  const _LibraryData(this.categories, this.surahs);
  final List<Category> categories;
  final List<Surah> surahs;
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  late Future<_LibraryData> future;
  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_LibraryData> load({bool refresh = false}) async {
    final repo = ref.read(servicesProvider).repository;
    final categories = await repo.categories(refresh: refresh);
    final surahs = await repo.surahs(refresh: refresh);
    return _LibraryData(categories, surahs);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LibraryData>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done && !snapshot.hasData) return const LoadingPane();
          if (snapshot.hasError && !snapshot.hasData) return ErrorPane(error: snapshot.error!, onRetry: () => setState(() => future = load(refresh: true)));
          final data = snapshot.data;
          if (data == null) return const EmptyPane();
          return RefreshIndicator(
            onRefresh: () async { setState(() => future = load(refresh: true)); await future; },
            child: ListView(children: <Widget>[
              const SectionHeader('التصنيفات'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: data.categories.map((category) => Chip(avatar: const Icon(Icons.folder_outlined, size: 18), label: Text(category.nameAr))).toList(growable: false)),
              ),
              const SectionHeader('سور القرآن — 114 سورة'),
              for (final surah in data.surahs)
                ListTile(
                  leading: CircleAvatar(child: Text('${surah.number}')),
                  title: Text(surah.nameAr),
                  subtitle: Text('${surah.nameEn} • ${surah.ayahCount} آية'),
                ),
              const SizedBox(height: 24),
            ]),
          );
        },
      );
}
