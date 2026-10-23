import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/screens/content_sources.dart';
import 'package:tarteel/src/screens/local_backup.dart';
import 'package:tarteel/src/theme.dart';

void main() {
  testWidgets('bundled sound sources are available without a backend', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: const BundledAudioSources()),
        ),
      ),
    );
    expect(find.text('أذان المسجد النبوي'), findsOneWidget);
    await tester.tap(find.text('أذان الحرم المكي'));
    await tester.pumpAndSettle();
    expect(find.text('Seyfula Islam'), findsOneWidget);
    expect(
      find.text('https://creativecommons.org/licenses/by/3.0/'),
      findsWidgets,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('local backup controls fit narrow RTL with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: TarteelTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: const Directionality(
              textDirection: TextDirection.rtl,
              child: LocalBackupPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('استيراد الإعدادات أيضًا'), 200);
    expect(tester.takeException(), isNull);
  });
}
