import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tarteel/src/mushaf_page_reader.dart';
import 'package:tarteel/src/mushaf_library.dart';

import 'ui_fixture.dart';

void main() {
  testWidgets('existing reader moves to a newly requested page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final services = UiServices(await SharedPreferences.getInstance());
    Widget reader(int page) => MaterialApp(
      home: Scaffold(
        body: MushafPageReader(
          repository: services.mushafPages,
          contentRepository: services.islamicContent,
          store: services.mushaf,
          initialPage: page,
          onPageChanged: (_) {},
          onPlayAyah: (_) {},
          onChooseReciter: () {},
          onPlaySurah: () {},
          onDownloadSurah: () {},
          onShowText: () {},
          onImmersiveChanged: (_) {},
          resolveVerse: (_, _) async => null,
        ),
      ),
    );
    await tester.pumpWidget(reader(1));
    await tester.pumpAndSettle();
    await tester.pumpWidget(reader(120));
    await tester.pumpAndSettle();
    final view = tester.widget<PageView>(find.byType(PageView));
    expect(view.controller!.page, 119);
    expect(find.text('120 / 604'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('verse lookup preserves overlapping topics and source order', () {
    final index = MushafTopicIndex(const [
      MushafTopic(1, 'first', null, ['1:1', '1:2']),
      MushafTopic(2, 'second', 1, ['1:1']),
    ]);
    expect(index.forVerse('1:1').map((t) => t.id), [1, 2]);
    expect(index.forVerse('1:2').map((t) => t.id), [1]);
    expect(index.forVerse('114:6'), isEmpty);
    expect(() => index.forVerse('1:1').clear(), throwsUnsupportedError);
  });
}
