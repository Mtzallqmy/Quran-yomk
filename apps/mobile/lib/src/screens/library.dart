import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';
import 'radio.dart';
import 'search.dart';

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
    final values = await Future.wait<dynamic>([
      repo.categories(refresh: refresh),
      repo.surahs(refresh: refresh),
    ]);
    return _LibraryData(values[0] as List<Category>, values[1] as List<Surah>);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_LibraryData>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done &&
          !snapshot.hasData) {
        return const LoadingPane();
      }
      if (snapshot.hasError && !snapshot.hasData) {
        return ErrorPane(
          error: snapshot.error!,
          onRetry: () => setState(() => future = load(refresh: true)),
        );
      }
      final data = snapshot.data;
      if (data == null) return const EmptyPane();
      return RefreshIndicator(
        onRefresh: () async {
          setState(() => future = load(refresh: true));
          await future;
        },
        child: ListView(
          children: <Widget>[
            const SectionHeader('تصفح حسب القسم'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.7,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: data.categories.length,
                itemBuilder: (context, index) {
                  final category = data.categories[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              RadioPage(initialCategory: category.slug),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.folder_open_outlined),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                category.nameAr,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_left, size: 18),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SectionHeader('سور القرآن — ${data.surahs.length} سورة'),
            for (final surah in data.surahs)
              ListTile(
                leading: CircleAvatar(child: Text('${surah.number}')),
                title: Text(surah.nameAr),
                subtitle: Text('${surah.nameEn} • ${surah.ayahCount} آية'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SearchPage(initialQuery: surah.nameAr),
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      );
    },
  );
}
