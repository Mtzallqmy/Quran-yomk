import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/canonical_quran.dart';
import 'package:tarteel/src/reading_annotations.dart';
import 'package:tarteel/src/screens/reading_annotations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'named ayah positions stay independent and can be removed after restart',
    () async {
      SharedPreferences.setMockInitialValues({'mushaf:bookmarks:v1': '[]'});
      final preferences = await SharedPreferences.getInstance();
      final annotations = ReadingAnnotations(preferences);
      expect(
        await annotations.save(
          'hafs:5:77',
          const ReadingAnnotation(title: 'موضع للمراجعة', note: ''),
        ),
        isTrue,
      );
      expect(
        await annotations.save(
          'hafs:5:78',
          const ReadingAnnotation(title: '', note: 'ملاحظة شخصية'),
        ),
        isTrue,
      );

      final restored = ReadingAnnotations(preferences);
      expect(restored['hafs:5:77']?.title, 'موضع للمراجعة');
      expect(restored['hafs:5:78']?.note, 'ملاحظة شخصية');
      expect(await restored.save('hafs:5:77', null), isTrue);
      expect(ReadingAnnotations(preferences).records.keys, ['hafs:5:78']);
      expect(preferences.getString('mushaf:bookmarks:v1'), '[]');
    },
  );

  testWidgets('ayah action edits the note for the exact canonical identity', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final annotations = ReadingAnnotations(
      await SharedPreferences.getInstance(),
    );
    final verse = (await tester.runAsync(
      TarteelCanonicalQuran.load,
    ))!.ayah('5:77')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AyahAnnotationTile(verse: verse, annotations: annotations),
        ),
      ),
    );
    await tester.tap(find.text('أضف ملاحظة أو اسمًا للموضع'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'علامة خاصة');
    await tester.enterText(find.byType(TextField).last, 'خواطر شخصية');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('تعديل الملاحظة والموضع'), findsOneWidget);
    expect(annotations['hafs:5:77']?.title, 'علامة خاصة');
    expect(annotations['hafs:5:77']?.note, 'خواطر شخصية');
    expect(annotations['hafs:5:78'], isNull);
  });
}
