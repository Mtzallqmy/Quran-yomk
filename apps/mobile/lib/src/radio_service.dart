import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'repository.dart';
import 'services.dart';

/// Source-agnostic station catalog used by the listener UI.
///
/// The current implementation reads the normalized Tarteel backend catalog.
/// A future provider can replace this service without changing the radio UI.
abstract interface class RadioService {
  Future<List<Station>> stations({bool refresh = false});
  Future<Station> station(String slug);
}

class BackendRadioService implements RadioService {
  const BackendRadioService(this.repository);

  final TarteelRepository repository;

  @override
  Future<List<Station>> stations({bool refresh = false}) =>
      repository.stations(refresh: refresh);

  @override
  Future<Station> station(String slug) => repository.api.station(slug);
}

final radioServiceProvider = Provider<RadioService>((ref) {
  return BackendRadioService(ref.watch(servicesProvider).repository);
});

final radioProvider = AsyncNotifierProvider<RadioCatalogController, List<Station>>(
  RadioCatalogController.new,
);

class RadioCatalogController extends AsyncNotifier<List<Station>> {
  @override
  Future<List<Station>> build() async {
    final values = await ref.watch(radioServiceProvider).stations();
    return _sorted(values);
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<Station>>();
    state = await AsyncValue.guard(() async {
      final values = await ref.read(radioServiceProvider).stations(refresh: true);
      return _sorted(values);
    });
  }

  Future<Station> station(String slug) =>
      ref.read(radioServiceProvider).station(slug);

  List<Station> _sorted(List<Station> values) {
    final result = List<Station>.from(values);
    result.sort((a, b) {
      if (a.isInternal != b.isInternal) return a.isInternal ? -1 : 1;
      final category = (a.category ?? '').compareTo(b.category ?? '');
      if (category != 0) return category;
      return a.nameAr.compareTo(b.nameAr);
    });
    return result;
  }
}
