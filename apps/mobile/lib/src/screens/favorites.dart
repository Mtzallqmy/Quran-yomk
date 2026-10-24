import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../common.dart';
import '../feature_manager.dart';
import '../models.dart';
import '../navigation.dart';
import '../quran_audio.dart';
import '../services.dart';
import 'legacy_reciter_detail.dart';

class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});
  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  late Future<List<Object>> _catalog;
  @override
  void initState() {
    super.initState();
    _catalog = _load();
  }

  Future<List<Object>> _load() async {
    final services = ref.read(servicesProvider);
    final result = await Future.wait<List<Object>>([
      services.repository
          .stations()
          .then<List<Object>>((v) => v)
          .catchError((Object _) => <Object>[]),
      services.repository
          .reciters()
          .then<List<Object>>((v) => v)
          .catchError((Object _) => <Object>[]),
      services.quranAudio
          .reciters()
          .then<List<Object>>((v) => v)
          .catchError((Object _) => <Object>[]),
    ]);
    return result.expand((value) => value).toList();
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider);
    return AnimatedBuilder(
      animation: Listenable.merge([services.favorites, services.features]),
      builder: (context, _) => FutureBuilder<List<Object>>(
        future: _catalog,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const LoadingPane();
          final values = snapshot.data!
              .where(
                (value) => switch (value) {
                  final Station station =>
                    services.features.enabled(TarteelFeature.radio) &&
                        services.favorites.isStation(station.id),
                  final Reciter reciter => services.favorites.isReciter(
                    reciter.id,
                  ),
                  final QuranAudioCatalogReciter reciter =>
                    services.favorites.isReciter(reciter.identityKey),
                  _ => false,
                },
              )
              .toList();
          return ListView.builder(
            itemCount: values.length + 2,
            itemBuilder: (context, index) {
              if (index == 0)
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('سجل الاستماع'),
                  onTap: () =>
                      Navigator.pushNamed(context, MobileRoutes.history),
                );
              if (index == values.length + 1)
                return services.favorites.trackIds.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'التلاوات المفضلة: ${services.favorites.trackIds.length}. افتح صفحة القارئ لعرض التلاوات المتاحة.',
                        ),
                      );
              final value = values[index - 1];
              if (value is Station)
                return ListTile(
                  key: ValueKey(value.id),
                  leading: Artwork(url: value.logoUrl),
                  title: Text(value.nameAr),
                  trailing: IconButton(
                    tooltip: 'تشغيل المحطة',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: value.isPlayable
                        ? () async {
                            try {
                              await services.playback.playStation(value);
                            } catch (_) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تعذر تشغيل المحطة'),
                                  ),
                                );
                            }
                          }
                        : null,
                  ),
                );
              if (value is QuranAudioCatalogReciter)
                return ListTile(
                  key: ValueKey(value.identityKey),
                  leading: const Icon(Icons.headphones),
                  title: Text(value.nameAr),
                  subtitle: value.riwayah == null ? null : Text(value.riwayah!),
                  onTap: () => Navigator.pushNamed(
                    context,
                    MobileRoutes.reciter,
                    arguments: value,
                  ),
                );
              final reciter = value as Reciter;
              return ListTile(
                key: ValueKey(reciter.id),
                leading: Artwork(
                  url: reciter.imageUrl,
                  icon: Icons.person_outline,
                ),
                title: Text(reciter.nameAr),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ReciterDetailPage(reciter: reciter),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
