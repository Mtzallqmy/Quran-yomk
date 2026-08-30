import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel/src/theme.dart';

void main() {
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
}
