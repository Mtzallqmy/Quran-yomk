import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/common.dart';
import 'package:tarteel/src/theme.dart';

void main() {
  test('brand themes keep the green and gold design system', () {
    for (final theme in <ThemeData>[
      TarteelTheme.light(),
      TarteelTheme.dark(),
    ]) {
      expect(theme.colorScheme.primary, isNot(theme.colorScheme.secondary));
      expect(theme.colorScheme.tertiary, theme.colorScheme.secondary);
      expect(theme.cardTheme.shape, isA<RoundedRectangleBorder>());
      expect(
        theme.navigationBarTheme.indicatorColor,
        theme.colorScheme.secondaryContainer,
      );
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    }
  });

  testWidgets('Arabic surface is RTL-capable and scalable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TarteelTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: Semantics(
                label: 'اسم التطبيق',
                child: const Text('ترتيل'),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('ترتيل'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('ترتيل')).label,
      contains('اسم التطبيق'),
    );
  });

  testWidgets('empty state does not overflow at large Arabic text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TarteelTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: EmptyPane(message: 'لا يوجد محتوى متاح في الوقت الحالي'),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('لا يوجد محتوى متاح في الوقت الحالي'), findsOneWidget);
  });

  testWidgets('internal routes use the shared light transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TarteelTheme.light(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(body: Text('الصفحة الداخلية')),
              ),
            ),
            child: const Text('فتح'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('فتح'));
    await tester.pump(const Duration(milliseconds: 40));

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('الصفحة الداخلية'), findsOneWidget);
  });
}
