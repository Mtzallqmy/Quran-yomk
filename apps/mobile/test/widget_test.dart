import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_yutla_mobile/main.dart';
import 'package:quran_yutla_mobile/core/services/app_services.dart';
import 'package:quran_yutla_mobile/core/config/features_manager.dart';
import 'package:quran_yutla_mobile/core/repositories/quran_yutla_repository.dart';
import 'package:quran_yutla_mobile/core/models/app_models.dart';

void main() {
  group('Quran Yutla Mobile Unit & Widget Tests', () {
    testWidgets('Quran Yutla App boots with Arabic title and dynamic navigation shell', (WidgetTester tester) async {
      final mockServices = AppServices(isInitialized: true, activeEnvironment: 'test');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appServicesProvider.overrideWithValue(mockServices),
          ],
          child: const QuranYutlaApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Brand AppBar title
      expect(find.text('قرآن يتلى'), findsOneWidget);

      // Verify Bottom Navigation items
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('الإذاعة'), findsOneWidget);
      expect(find.text('المصحف'), findsOneWidget);
      expect(find.text('القراء'), findsOneWidget);
      expect(find.text('المفضلة'), findsOneWidget);
    });

    test('FeaturesManager toggles radio feature flag correctly', () {
      final manager = FeaturesManager();
      expect(manager.state.radioEnabled, isTrue);

      manager.toggleRadio(false);
      expect(manager.state.radioEnabled, isFalse);

      manager.toggleRadio(true);
      expect(manager.state.radioEnabled, isTrue);
    });

    test('FavoritesNotifier adds and removes favorite IDs', () {
      final notifier = FavoritesNotifier();
      expect(notifier.isFavorite('station-1'), isTrue);

      notifier.toggleFavorite('station-1');
      expect(notifier.isFavorite('station-1'), isFalse);

      notifier.toggleFavorite('station-1');
      expect(notifier.isFavorite('station-1'), isTrue);
    });

    test('PlaylistsNotifier creates and renames playlists', () {
      final notifier = PlaylistsNotifier();
      final initialCount = notifier.state.length;

      notifier.createPlaylist('تلاوات المساء');
      expect(notifier.state.length, initialCount + 1);
      expect(notifier.state.last.name, 'تلاوات المساء');

      final newId = notifier.state.last.id;
      notifier.renamePlaylist(newId, 'تلاوات المساء والوتر');
      expect(notifier.state.last.name, 'تلاوات المساء والوتر');

      notifier.deletePlaylist(newId);
      expect(notifier.state.length, initialCount);
    });

    test('DownloadsNotifier tracks task state and supports pausing', () {
      final notifier = DownloadsNotifier();
      final initialCount = notifier.state.length;

      notifier.addDownload(1, 'سورة الفاتحة', 'الشيخ عبد الباسط');
      expect(notifier.state.length, initialCount + 1);
      final addedTask = notifier.state.last;
      expect(addedTask.status, DownloadStatus.downloading);

      notifier.togglePauseResume(addedTask.id);
      final pausedTask = notifier.state.firstWhere((t) => t.id == addedTask.id);
      expect(pausedTask.status, DownloadStatus.paused);
    });
  });
}
