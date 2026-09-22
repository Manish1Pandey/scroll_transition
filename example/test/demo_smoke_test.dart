import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_transition/scroll_transition.dart';
import 'package:scroll_transition_example/main.dart';

void main() {
  testWidgets('every demo opens, scrolls and closes without errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ScrollTransitionExampleApp());
    final titles = tester
        .widgetList<ListTile>(find.byType(ListTile))
        .map((t) => (t.title! as Text).data!)
        .toList();
    expect(titles.length, greaterThanOrEqualTo(8));
    for (final title in titles) {
      final tile = find.widgetWithText(ListTile, title);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();
      final scrollables = find.byType(Scrollable).hitTestable();
      expect(scrollables, findsWidgets, reason: title);
      await tester.fling(scrollables.first, const Offset(-300, -300), 1500);
      await tester.pumpAndSettle();
      expect(
        find.byType(ScrollTransition).evaluate().isNotEmpty ||
            find.byType(VisualEffect).evaluate().isNotEmpty,
        isTrue,
        reason: title,
      );
      expect(tester.takeException(), isNull, reason: title);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
