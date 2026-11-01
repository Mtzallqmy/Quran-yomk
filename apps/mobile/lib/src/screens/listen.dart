import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common.dart';
import '../models.dart';
import '../navigation.dart';
import '../services.dart';
import 'reciters.dart';

class ListenPage extends StatefulWidget {
  const ListenPage({super.key});
  @override
  State<ListenPage> createState() => _ListenPageState();
}

class _ListenPageState extends State<ListenPage> {
  int _section = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (index, label) in [
                      'القراء',
                      'المصاحف',
                      'السور',
                    ].indexed)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: ChoiceChip(
                          label: Text(label),
                          selected: _section == index,
                          onSelected: (_) => setState(() => _section = index),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'آخر الاستماعات',
              icon: const Icon(Icons.history),
              onPressed: () =>
                  Navigator.pushNamed(context, MobileRoutes.history),
            ),
          ],
        ),
      ),
      Expanded(
        child: IndexedStack(
          index: _section,
          children: const [
            RecitersPage(),
            RecitersPage(editionsView: true),
            _AudioSurahs(),
          ],
        ),
      ),
    ],
  );
}

class _AudioSurahs extends ConsumerStatefulWidget {
  const _AudioSurahs();
  @override
  ConsumerState<_AudioSurahs> createState() => _AudioSurahsState();
}

class _AudioSurahsState extends ConsumerState<_AudioSurahs> {
  late Future<List<Surah>> _surahs;
  @override
  void initState() {
    super.initState();
    _surahs = ref.read(servicesProvider).repository.surahs();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Surah>>(
    future: _surahs,
    builder: (context, snapshot) {
      if (snapshot.hasError)
        return ErrorPane(
          error: snapshot.error!,
          onRetry: () => setState(() {
            _surahs = ref
                .read(servicesProvider)
                .repository
                .surahs(refresh: true);
          }),
        );
      if (!snapshot.hasData) return const LoadingPane();
      final values = snapshot.data!;
      if (values.isEmpty) return const EmptyPane();
      return ListView.builder(
        key: const PageStorageKey('audio-surahs'),
        itemCount: values.length,
        itemBuilder: (context, index) => ListTile(
          key: ValueKey(values[index].number),
          leading: CircleAvatar(child: Text('${values[index].number}')),
          title: Text(values[index].nameAr),
          subtitle: const Text('اختر القارئ والمصحف الصوتي'),
          onTap: () => Navigator.pushNamed(
            context,
            MobileRoutes.reciters,
            arguments: values[index].number,
          ),
        ),
      );
    },
  );
}
