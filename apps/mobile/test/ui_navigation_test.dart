import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/app.dart';
import 'package:tarteel/src/navigation.dart';
import 'package:tarteel/src/screens/quran_index.dart';
import 'package:tarteel/src/services.dart';
import 'ui_fixture.dart';

Future<UiServices> uiServices({bool radioEnabled = true}) async {
  SharedPreferences.setMockInitialValues({
    'tarteel_remote_config:v1':
        '{"radio_enabled":$radioEnabled,"prayer_features_enabled":false}',
  });
  return UiServices(await SharedPreferences.getInstance());
}

void main() {
  test('destination identities survive a disabled radio feature', () {
    expect(mobileDestinations(radioEnabled: true).length, 5);
    final reduced = mobileDestinations(radioEnabled: false);
    expect(reduced, [
      MobileDestination.home,
      MobileDestination.quran,
      MobileDestination.listen,
      MobileDestination.library,
    ]);
    expect(reduced[3], MobileDestination.library);
  });
  test('Arabic Quran queries normalize diacritics and digit forms', () {
    expect(normalizeQuranQuery(' إِبْرَاهِيم '), 'ابراهيم');
    expect(normalizeQuranQuery('٢٩٣'), '293');
  });
  testWidgets('shell opens all destinations and preserves Quran scroll', (
    tester,
  ) async {
    final originalError = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalError!(details);
    };
    addTearDown(() => FlutterError.onError = originalError);
    final services = await uiServices();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TarteelApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('المشغل المصغر'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('destination-quran')));
    await tester.pumpAndSettle();
    expect(find.byType(QuranIndexPage), findsOneWidget);
    await tester.tap(find.text('الصفحات'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const PageStorageKey('page')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    final before = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('page')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    for (final destination in ['listen', 'radio', 'library', 'quran']) {
      await tester.tap(find.byKey(ValueKey('destination-$destination')));
      await tester.pumpAndSettle();
    }
    final after = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(const PageStorageKey('page')),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(after, before);
    expect(services.settings.mobileDestination, 'quran');
    expect(
      Directionality.of(tester.element(find.byType(NavigationBar))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reader is a separate full screen route; back returns to index', (
    tester,
  ) async {
    final services = await uiServices(radioEnabled: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const TarteelApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.byKey(const ValueKey('destination-quran')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الصفحات'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الصفحة 3'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(services.repository.openedPages, contains(3));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
