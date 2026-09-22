// Drives the real example app on a device (macOS here), checks the painted
// effects at known scroll positions, and saves in-app screenshots.
//
//   flutter test integration_test -d macos
//
// Screenshots go to `<systemTemp>/scroll_transition_shots/` (inside the app
// sandbox container on macOS). The path is printed for each file.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:scroll_transition/scroll_transition.dart';
import 'package:scroll_transition_example/main.dart';

final GlobalKey _shotKey = GlobalKey();

Future<void> _screenshot(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary =
      _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final logicalWidth = boundary.size.width;
  final ratio = (1000 / logicalWidth).clamp(1.0, 3.0);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final dir = Directory('${Directory.systemTemp.path}/scroll_transition_shots')
    ..createSync(recursive: true);
  final file = File('${dir.path}/$name.png')..writeAsBytesSync(bytes!);
  // ignore: avoid_print
  print('SCREENSHOT ${file.path} (${bytes.length} bytes)');
}

/// Every measured RenderVisualEffect inside the current demo's scrollable.
List<RenderVisualEffect> _effects(WidgetTester tester) {
  final result = <RenderVisualEffect>[];
  void visit(RenderObject node) {
    if (node is RenderVisualEffect && node.lastGeometry != null) {
      result.add(node);
    }
    node.visitChildren(visit);
  }

  visit(tester.renderObject(find.byType(Scrollable).hitTestable().first));
  return result;
}

ScrollPosition _demoPosition(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).hitTestable().first)
    .position;

Future<void> _jump(WidgetTester tester, double offset) async {
  _demoPosition(tester).jumpTo(offset);
  await tester.pump();
  await tester.pump();
}

Future<void> _openDemo(WidgetTester tester, String title) async {
  final tile = find.widgetWithText(ListTile, title);
  await tester.scrollUntilVisible(
    tile,
    80,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
}

/// Checks each painted item's applied values against the effect resolved
/// from its measured phase. Returns how many items were mid-transition.
int _verify(
  WidgetTester tester,
  ScrollEffect effect, {
  double topInset = 0,
  double bottomInset = 0,
}) {
  var transitioning = 0;
  final effects = _effects(tester).where((e) {
    final g = e.lastGeometry!;
    return g.hasViewport && g.axisDirection == AxisDirection.down;
  }).toList();
  expect(effects, isNotEmpty);
  for (final e in effects) {
    final g = e.lastGeometry!;
    final phase = g.phase(topInset: topInset, bottomInset: bottomInset);
    final expected = effect.resolve(phase, axis: g.axis);
    final actual = e.lastValues ?? VisualEffectValues.identity;
    if (expected.opacity <= 0) continue; // not painted at all
    expect(actual.opacity, closeTo(expected.opacity, 1e-9), reason: '$g');
    expect(actual.scale, closeTo(expected.scale, 1e-9), reason: '$g');
    expect(actual.rotationX, closeTo(expected.rotationX, 1e-9));
    expect(actual.blur, closeTo(expected.blur, 1e-9));
    if (!phase.isIdentity && phase.magnitude < 1) transitioning++;
  }
  return transitioning;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('effects render at known scroll positions', (tester) async {
    await tester.pumpWidget(
      RepaintBoundary(key: _shotKey, child: const ScrollTransitionExampleApp()),
    );
    await tester.pumpAndSettle();

    // 1. Fade + scale: item extent is 96 + 2 * 6 margin = 108.
    await _openDemo(tester, 'Fade + scale');
    final fadeScale = ScrollEffects.fade().scale(0.8);
    for (final offset in <double>[0, 54, 300, 1000]) {
      await _jump(tester, offset);
      final n = _verify(tester, fadeScale);
      if (offset > 0) expect(n, greaterThan(0));
      await _screenshot(tester, 'fade_scale_${offset.round()}');
    }
    // At offset 54 item 0 is half past the top: phase -0.5.
    await _jump(tester, 54);
    final first = _effects(
      tester,
    ).firstWhere((e) => e.lastGeometry!.rect.top.round() == -54);
    expect(first.lastGeometry!.phase().value, closeTo(-0.5, 1e-9));
    expect(first.lastValues!.opacity, closeTo(0.5, 1e-9));
    expect(first.lastValues!.scale, closeTo(0.9, 1e-9));
    final tileRect = tester.getRect(find.text('Item 0'));
    expect(tileRect.width, lessThan(120)); // painted text is scaled down
    await _back(tester);

    // 2. 3D drum.
    await _openDemo(tester, '3D drum');
    final drum = ScrollEffects.rotate3D(angle: 3.141592653589793 / 3).fade(0.3);
    for (final offset in <double>[0, 150, 600]) {
      await _jump(tester, offset);
      expect(
        _verify(tester, drum, topInset: 80, bottomInset: 80),
        greaterThan(0),
      );
      await _screenshot(tester, 'drum_${offset.round()}');
    }
    await _back(tester);

    // 3. Blur + desaturate grid.
    await _openDemo(tester, 'Blur + desaturate grid');
    final blur = ScrollEffects.blur(6).saturate(0).scale(0.9);
    for (final offset in <double>[0, 120, 700]) {
      await _jump(tester, offset);
      expect(
        _verify(tester, blur, topInset: 40, bottomInset: 40),
        greaterThan(0),
      );
      await _screenshot(tester, 'blur_grid_${offset.round()}');
    }
    await _back(tester);

    // 4. Carousel (VisualEffect, horizontal).
    await _openDemo(tester, 'Carousel (VisualEffect)');
    for (final offset in <double>[0, 250, 900]) {
      await _jump(tester, offset);
      final cards = _effects(
        tester,
      ).where((e) => e.lastGeometry!.axis == Axis.horizontal).toList();
      expect(cards, isNotEmpty);
      for (final e in cards) {
        final d = e.lastGeometry!.centerOffset.clamp(-1.0, 1.0);
        final v = e.lastValues ?? VisualEffectValues.identity;
        expect(v.scale, closeTo(1 - 0.25 * d.abs(), 1e-9));
        expect(v.rotationY, closeTo(-0.6 * d, 1e-9));
      }
      await _screenshot(tester, 'carousel_${offset.round()}');
    }
    await _back(tester);

    // 5. PageView mid-swipe.
    await _openDemo(tester, 'PageView');
    // A held drag keeps the page between snaps (jumpTo would start
    // PageView's snap animation).
    final position = _demoPosition(tester);
    final width = position.viewportDimension;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PageView)),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.moveBy(Offset(-(width * 0.45 - 40), 0));
    await tester.pump();
    await tester.pump();
    final t = position.pixels / width;
    final pages =
        _effects(tester)
            .where((e) => e.lastGeometry!.axis == Axis.horizontal)
            .map((e) => e.lastGeometry!.phase().value)
            .toList()
          ..sort();
    expect(t, greaterThan(0.3));
    expect(pages.first, closeTo(-t, 1e-6));
    expect(pages.last, closeTo(1 - t, 1e-6));
    await _screenshot(tester, 'pageview_half');
    await gesture.up();
    await tester.pumpAndSettle();
    await _back(tester);
  });
}
