import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common.dart';
import '../models.dart';
import '../services.dart';

class RadioPage extends ConsumerStatefulWidget {
  const RadioPage({super.key});
  @override
  ConsumerState<RadioPage> createState() => _RadioPageState();
}

class _RadioPageState extends ConsumerState<RadioPage> {
  late Future<List<Station>> future;
  String filter = 'ALL';
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

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment(value: 'ALL', label: Text('الكل')),
            ButtonSegment(value: 'INTERNAL', label: Text('ترتيل')),
            ButtonSegment(value: 'EXTERNAL', label: Text('خارجي')),
          ],
          selected: <String>{filter},
          onSelectionChanged: (values) => setState(() => filter = values.first),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<Station>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done &&
                !snapshot.hasData)
              return const LoadingPane();
            if (snapshot.hasError && !snapshot.hasData)
              return ErrorPane(
                error: snapshot.error!,
                onRetry: () => reload(true),
              );
            final all = snapshot.data ?? const <Station>[];
            final stations = filter == 'ALL'
                ? all
                : all
                      .where((station) => station.source == filter)
                      .toList(growable: false);
            if (stations.isEmpty) return const EmptyPane();
            final services = ref.watch(servicesProvider);
            return RefreshIndicator(
              onRefresh: () async {
                reload(true);
                await future;
              },
              child: ListView.builder(
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return Card(
                    child: ListTile(
                      leading: Artwork(url: station.logoUrl),
                      title: Text(station.nameAr),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            station.isInternal
                                ? 'بث ترتيل الداخلي'
                                : 'بث خارجي',
                          ),
                          if (station.healthStatus != null)
                            Text('الحالة: ${station.healthStatus}'),
                          if (station.attribution != null)
                            Text(
                              station.attribution!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                      isThreeLine:
                          station.healthStatus != null ||
                          station.attribution != null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
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
                          IconButton(
                            tooltip: 'تشغيل',
                            onPressed: station.isPlayable
                                ? () => services.playback.playStation(station)
                                : null,
                            icon: const Icon(Icons.play_circle_fill),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    ],
  );
}
