import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_transition/scroll_transition.dart';

// The default test surface is 800x600.

RenderVisualEffect effectOf(WidgetTester tester, Key key) {
  RenderObject? node = tester.renderObject(find.byKey(key));
  while (node != null && node is! RenderVisualEffect) {
    node = node.parent;
  }
  return node! as RenderVisualEffect;
}

double opacityOf(WidgetTester tester, Key key) =>
    effectOf(tester, key).lastValues?.opacity ?? 1.0;

class BuildCounter extends StatelessWidget {
  const BuildCounter({
    super.key,
    required this.counts,
    required this.id,
    this.extent = 100,
  });
  final Map<int, int> counts;
  final int id;
  final double extent;

  @override
  Widget build(BuildContext context) {
    counts[id] = (counts[id] ?? 0) + 1;
    return SizedBox(width: extent, height: extent, child: Text('$id'));
  }
}

class PaintCounter extends CustomPainter {
  PaintCounter(this.counts, this.id);
  final Map<int, int> counts;
  final int id;
  @override
  void paint(Canvas canvas, Size size) => counts[id] = (counts[id] ?? 0) + 1;
  @override
  bool shouldRepaint(PaintCounter oldDelegate) => false;
}

Widget app(Widget child, {TextDirection textDirection = TextDirection.ltr}) =>
    Directionality(textDirection: textDirection, child: child);

Widget fadeList({
  required ScrollController controller,
  Axis axis = Axis.vertical,
  bool reverse = false,
  double extent = 100,
  TextDirection textDirection = TextDirection.ltr,
}) {
  return app(
    ListView.builder(
      controller: controller,
      scrollDirection: axis,
      reverse: reverse,
      itemExtent: extent,
      itemCount: 50,
      itemBuilder: (context, i) => ScrollTransition(
        effect: ScrollEffects.fade(),
        child: SizedBox(key: ValueKey<int>(i)),
      ),
    ),
    textDirection: textDirection,
  );
}

void main() {
  group('phase at precise offsets (effect mode, same frame)', () {
    testWidgets('vertical', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(fadeList(controller: c));
      expect(opacityOf(tester, const ValueKey(0)), 1);
      expect(opacityOf(tester, const ValueKey(5)), 1);
      c.jumpTo(50);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
      expect(opacityOf(tester, const ValueKey(3)), 1);
      expect(opacityOf(tester, const ValueKey(6)), 0.5);
      c.jumpTo(125);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey(1)), 0.75);
      expect(opacityOf(tester, const ValueKey(7)), 0.25);
      expect(
        effectOf(tester, const ValueKey(1)).lastGeometry!.rect,
        const Rect.fromLTWH(0, -25, 800, 100),
      );
    });

    testWidgets('horizontal', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(
        fadeList(controller: c, axis: Axis.horizontal, extent: 200),
      );
      c.jumpTo(100);
      await tester.pump();
      final g0 = effectOf(tester, const ValueKey(0)).lastGeometry!;
      expect(g0.phase().value, -0.5);
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
      expect(opacityOf(tester, const ValueKey(4)), 0.5);
      expect(opacityOf(tester, const ValueKey(2)), 1);
    });

    testWidgets('reversed vertical: item 0 leaves at the bottom', (
      tester,
    ) async {
      final c = ScrollController();
      await tester.pumpWidget(fadeList(controller: c, reverse: true));
      c.jumpTo(50);
      await tester.pump();
      final g = effectOf(tester, const ValueKey(0)).lastGeometry!;
      expect(g.axisDirection, AxisDirection.up);
      expect(g.phase().value, 0.5);
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
      expect(
        effectOf(tester, const ValueKey(6)).lastGeometry!.phase().value,
        -0.5,
      );
    });

    testWidgets('RTL horizontal: item 0 leaves at the right (leading)', (
      tester,
    ) async {
      final c = ScrollController();
      await tester.pumpWidget(
        fadeList(
          controller: c,
          axis: Axis.horizontal,
          extent: 200,
          textDirection: TextDirection.rtl,
        ),
      );
      c.jumpTo(100);
      await tester.pump();
      final g = effectOf(tester, const ValueKey(0)).lastGeometry!;
      expect(g.rect.right, 900);
      expect(g.phase().value, -0.5);
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
    });

    testWidgets('PageView', (tester) async {
      final c = PageController();
      await tester.pumpWidget(
        app(
          PageView(
            controller: c,
            children: [
              for (var i = 0; i < 3; i++)
                ScrollTransition(
                  effect: ScrollEffects.scale(0.5),
                  child: SizedBox.expand(key: ValueKey<int>(i)),
                ),
            ],
          ),
        ),
      );
      c.jumpTo(400);
      await tester.pump();
      expect(
        effectOf(tester, const ValueKey(0)).lastGeometry!.phase().value,
        -0.5,
      );
      expect(
        effectOf(tester, const ValueKey(1)).lastGeometry!.phase().value,
        0.5,
      );
      expect(effectOf(tester, const ValueKey(1)).lastValues!.scale, 0.75);
      c.jumpTo(800);
      await tester.pump();
      expect(effectOf(tester, const ValueKey(1)).lastValues, isNull);
    });

    testWidgets('GridView and SingleChildScrollView', (tester) async {
      final c = ScrollController();
      await tester.pumpWidget(
        app(
          GridView.builder(
            controller: c,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisExtent: 100,
            ),
            itemCount: 80,
            itemBuilder: (_, i) => ScrollTransition(
              effect: ScrollEffects.fade(),
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      c.jumpTo(50);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey(3)), 0.5);
      expect(opacityOf(tester, const ValueKey(4)), 1);

      final s = ScrollController();
      await tester.pumpWidget(
        app(
          SingleChildScrollView(
            controller: s,
            child: Column(
              children: [
                for (var i = 0; i < 10; i++)
                  ScrollTransition(
                    effect: ScrollEffects.fade(),
                    child: SizedBox(key: ValueKey<String>('s$i'), height: 100),
                  ),
              ],
            ),
          ),
        ),
      );
      s.jumpTo(75);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey('s0')), 0.25);
      expect(opacityOf(tester, const ValueKey('s6')), 0.75);
    });

    testWidgets('topInset / bottomInset', (tester) async {
      await tester.pumpWidget(
        app(
          ListView(
            children: [
              for (var i = 0; i < 10; i++)
                ScrollTransition(
                  topInset: 100,
                  bottomInset: 100,
                  effect: ScrollEffects.fade(),
                  child: SizedBox(key: ValueKey<int>(i), height: 100),
                ),
            ],
          ),
        ),
      );
      expect(opacityOf(tester, const ValueKey(0)), 0);
      expect(opacityOf(tester, const ValueKey(1)), 1);
      expect(opacityOf(tester, const ValueKey(5)), 0);
      expect(opacityOf(tester, const ValueKey(4)), 1);
    });
  });

  group('builder mode', () {
    testWidgets('visible items get the exact phase in the same frame', (
      tester,
    ) async {
      final c = ScrollController();
      final phases = <int, ScrollTransitionPhase>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 50,
            itemBuilder: (_, i) => ScrollTransition(
              builder: (context, child, phase) {
                phases[i] = phase;
                return child!;
              },
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      expect(phases[0], ScrollTransitionPhase.identity);
      for (final offset in <double>[10, 30, 50, 80, 99]) {
        c.jumpTo(offset);
        await tester.pump();
        expect(
          phases[0]!.value,
          closeTo(-offset / 100, 1e-9),
          reason: 'offset $offset',
        );
        expect(phases[5]!.value, 0);
        if (offset > 10) {
          // Item 6 was first painted at offset 10; since then it is exact.
          expect(phases[6]!.value, closeTo(1 - offset / 100, 1e-9));
        }
      }
    });

    testWidgets('newly revealed items skip one frame, then are exact', (
      tester,
    ) async {
      final c = ScrollController();
      final phases = <int, ScrollTransitionPhase>{};
      final paints = <int, int>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 50,
            itemBuilder: (_, i) => ScrollTransition(
              builder: (context, child, phase) {
                phases[i] = phase;
                return child!;
              },
              child: CustomPaint(
                key: ValueKey<int>(i),
                painter: PaintCounter(paints, i),
              ),
            ),
          ),
        ),
      );
      // Item 6 is built in the cache extent but never painted.
      expect(paints[6], isNull);
      c.jumpTo(40);
      await tester.pump();
      expect(paints[6], isNull, reason: 'stale first frame is skipped');
      await tester.pump();
      expect(phases[6]!.value, closeTo(0.6, 1e-9));
      expect(paints[6], 1);
    });

    testWidgets('builder and effect together, child never rebuilt', (
      tester,
    ) async {
      final c = ScrollController();
      final builds = <int, int>{};
      final builderCalls = <int, int>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 50,
            itemBuilder: (_, i) => ScrollTransition(
              effect: ScrollEffects.fade(),
              builder: (context, child, phase) {
                builderCalls[i] = (builderCalls[i] ?? 0) + 1;
                return Opacity(opacity: 1, child: child);
              },
              child: BuildCounter(counts: builds, id: i),
            ),
          ),
        ),
      );
      for (var o = 1.0; o <= 40; o += 1) {
        c.jumpTo(o);
        await tester.pump();
      }
      // Item 3 stays fully visible throughout: no builder calls at all.
      expect(builderCalls[3], 1);
      // Item 0 changes phase every frame: builder reruns, child does not.
      expect(builderCalls[0], greaterThan(30));
      for (var i = 0; i < 6; i++) {
        expect(builds[i], 1, reason: 'child $i rebuilt');
      }
    });
  });

  testWidgets('effect mode: zero rebuilds while scrolling', (tester) async {
    final c = ScrollController();
    final builds = <int, int>{};
    await tester.pumpWidget(
      app(
        ListView.builder(
          controller: c,
          itemExtent: 100,
          itemCount: 50,
          itemBuilder: (_, i) => ScrollTransition(
            effect: ScrollEffects.fade().scale(0.8).rotate3D().blur(4),
            child: BuildCounter(counts: builds, id: i),
          ),
        ),
      ),
    );
    final initial = Map<int, int>.of(builds);
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pump();
    for (var o = 0.0; o < 200; o += 7) {
      c.jumpTo(o);
      await tester.pump();
    }
    for (final entry in initial.entries) {
      expect(
        builds[entry.key],
        entry.value,
        reason: 'item ${entry.key} rebuilt',
      );
    }
  });

  group('effects apply transforms and layers', () {
    Future<void> pumpOne(
      WidgetTester tester,
      ScrollEffect effect,
      ScrollController c,
    ) async {
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 20,
            itemBuilder: (_, i) => ScrollTransition(
              effect: effect,
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      c.jumpTo(50);
      await tester.pump();
    }

    testWidgets('scale transforms the painted rect', (tester) async {
      await pumpOne(tester, ScrollEffects.scale(0.5), ScrollController());
      // Layout rect (0,-50,800,100) scaled 0.75 around its centre (400,0).
      final rect = tester.getRect(find.byKey(const ValueKey(0)));
      expect(rect.left, closeTo(100, 1e-6));
      expect(rect.right, closeTo(700, 1e-6));
      expect(rect.top, closeTo(-37.5, 1e-6));
      expect(rect.bottom, closeTo(37.5, 1e-6));
      expect(tester.layers.whereType<TransformLayer>(), isNotEmpty);
    });

    testWidgets('slide moves the painted rect', (tester) async {
      await pumpOne(tester, ScrollEffects.slide(48), ScrollController());
      expect(
        tester.getRect(find.byKey(const ValueKey(0))).top,
        closeTo(-74, 1e-6),
      );
      expect(
        tester.getRect(find.byKey(const ValueKey(6))).top,
        closeTo(574, 1e-6),
      );
    });

    testWidgets('fade pushes an OpacityLayer with the right alpha', (
      tester,
    ) async {
      await pumpOne(tester, ScrollEffects.fade(), ScrollController());
      final alphas = tester.layers.whereType<OpacityLayer>().map(
        (l) => l.alpha,
      );
      expect(alphas, contains(Color.getAlphaFromOpacity(0.5)));
    });

    testWidgets('blur, saturate and rotate3D', (tester) async {
      await pumpOne(
        tester,
        ScrollEffects.blur(10).saturate(0).rotate3D(angle: 1),
        ScrollController(),
      );
      final v = effectOf(tester, const ValueKey(0)).lastValues!;
      expect(v.blur, 5);
      expect(v.saturation, 0.5);
      expect(v.rotationX, -0.5);
      expect(tester.layers.whereType<ImageFilterLayer>(), isNotEmpty);
      expect(tester.layers.whereType<ColorFilterLayer>(), isNotEmpty);
    });

    testWidgets('fully faded children are not painted', (tester) async {
      final paints = <int, int>{};
      final c = ScrollController();
      await tester.pumpWidget(
        app(
          ListView(
            controller: c,
            children: [
              for (var i = 0; i < 10; i++)
                ScrollTransition(
                  effect: ScrollEffects.fade(),
                  topInset: 100,
                  child: SizedBox(
                    height: 100,
                    child: CustomPaint(painter: PaintCounter(paints, i)),
                  ),
                ),
            ],
          ),
        ),
      );
      expect(paints[0], isNull);
      expect(paints[1], 1);
    });
  });

  group('animated configuration', () {
    testWidgets('animates to the discrete phase over the duration', (
      tester,
    ) async {
      final c = ScrollController();
      final phases = <int, ScrollTransitionPhase>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 50,
            itemBuilder: (_, i) => ScrollTransition(
              configuration: const ScrollTransitionConfiguration.animated(
                duration: Duration(milliseconds: 200),
                curve: Curves.linear,
              ),
              effect: ScrollEffects.fade(),
              builder: (context, child, phase) {
                phases[i] = phase;
                return child!;
              },
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(phases[0], ScrollTransitionPhase.identity);
      // 40% visible: below the 0.5 threshold, so the target is -1.
      c.jumpTo(60);
      await tester.pump();
      expect(phases[0]!.value, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(phases[0]!.value, closeTo(-0.5, 1e-9));
      expect(opacityOf(tester, const ValueKey(0)), closeTo(0.5, 1e-9));
      await tester.pump(const Duration(milliseconds: 100));
      expect(phases[0]!.value, -1);
      expect(opacityOf(tester, const ValueKey(0)), 0);
      // Crossing back animates back to identity.
      c.jumpTo(40);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(phases[0]!.value, closeTo(-0.75, 1e-9));
      await tester.pump(const Duration(milliseconds: 150));
      expect(phases[0]!.value, 0);
    });

    testWidgets('items appearing below the threshold snap without animating', (
      tester,
    ) async {
      final c = ScrollController();
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 50,
            itemBuilder: (_, i) => ScrollTransition(
              configuration: const ScrollTransitionConfiguration.animated(),
              effect: ScrollEffects.fade(),
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      c.jumpTo(20);
      await tester.pump();
      // Item 6 is 20% visible on its first paint: it starts at phase 1.
      expect(opacityOf(tester, const ValueKey(6)), 0);
      expect(tester.hasRunningAnimations, isFalse);
      c.jumpTo(80);
      await tester.pump();
      await tester.pump();
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(opacityOf(tester, const ValueKey(6)), 1);
    });
  });

  group('structural cases', () {
    testWidgets('outside a Scrollable the phase is identity', (tester) async {
      ScrollTransitionPhase? phase;
      VisualEffectGeometry? geometry;
      await tester.pumpWidget(
        app(
          Column(
            children: [
              ScrollTransition(
                effect: ScrollEffects.fade(),
                topInset: 50,
                builder: (context, child, p) {
                  phase = p;
                  return child!;
                },
                child: const SizedBox(key: ValueKey('a'), height: 20),
              ),
              VisualEffect(
                effect: (g) {
                  geometry = g;
                  return VisualEffectValues.identity;
                },
                child: const SizedBox(height: 30, width: 40),
              ),
            ],
          ),
        ),
      );
      expect(phase, ScrollTransitionPhase.identity);
      expect(effectOf(tester, const ValueKey('a')).lastValues, isNull);
      expect(geometry!.hasViewport, isFalse);
      expect(geometry!.rect, const Rect.fromLTWH(0, 0, 40, 30));
    });

    testWidgets('keepAlive items keep state and report correct phase', (
      tester,
    ) async {
      final c = ScrollController();
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 100,
            itemBuilder: (_, i) => ScrollTransition(
              effect: ScrollEffects.fade(),
              child: _KeepAliveCounter(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      tester
              .state<_KeepAliveCounterState>(find.byKey(const ValueKey(0)))
              .value =
          42;
      c.jumpTo(5000);
      await tester.pump();
      expect(
        find.byKey(const ValueKey(0), skipOffstage: false),
        findsOneWidget,
      );
      c.jumpTo(50);
      await tester.pump();
      expect(
        tester
            .state<_KeepAliveCounterState>(find.byKey(const ValueKey(0)))
            .value,
        42,
      );
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
    });

    testWidgets('pinned header stays identity; list uses topInset', (
      tester,
    ) async {
      final c = ScrollController();
      final headerPhases = <ScrollTransitionPhase>[];
      await tester.pumpWidget(
        app(
          CustomScrollView(
            controller: c,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _Header(
                  ScrollTransition(
                    effect: ScrollEffects.fade(),
                    builder: (context, child, p) {
                      headerPhases.add(p);
                      return child!;
                    },
                    child: const SizedBox.expand(key: ValueKey('header')),
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: 30,
                itemBuilder: (_, i) => ScrollTransition(
                  topInset: 100,
                  effect: ScrollEffects.fade(),
                  child: SizedBox(key: ValueKey<int>(i), height: 100),
                ),
              ),
            ],
          ),
        ),
      );
      c.jumpTo(250);
      await tester.pump();
      await tester.pump();
      expect(effectOf(tester, const ValueKey('header')).lastValues, isNull);
      expect(
        effectOf(tester, const ValueKey('header')).lastGeometry!.rect.top,
        0,
      );
      // Item 2 is at 100 + 200 - 250 = 50 on screen: half under the header.
      expect(opacityOf(tester, const ValueKey(2)), 0.5);
      // Once the header's movement ratio is learned, prediction stays exact.
      for (var o = 260.0; o < 400; o += 10) {
        c.jumpTo(o);
        await tester.pump();
        expect(headerPhases.last, ScrollTransitionPhase.identity);
      }
    });

    testWidgets('nested scrollables use the nearest viewport', (tester) async {
      final outer = ScrollController();
      final inner = ScrollController();
      await tester.pumpWidget(
        app(
          ListView(
            controller: outer,
            children: [
              const SizedBox(height: 100),
              SizedBox(
                height: 100,
                child: ListView(
                  controller: inner,
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < 10; i++)
                      ScrollTransition(
                        effect: ScrollEffects.fade(),
                        child: SizedBox(key: ValueKey<int>(i), width: 200),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      );
      outer.jumpTo(150);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey(0)), 1);
      final g = effectOf(tester, const ValueKey(0)).lastGeometry!;
      expect(g.axis, Axis.horizontal);
      expect(g.viewportSize, const Size(800, 100));
      inner.jumpTo(100);
      await tester.pump();
      expect(opacityOf(tester, const ValueKey(0)), 0.5);
    });

    testWidgets('hit testing follows the transform', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        app(
          Align(
            alignment: Alignment.topLeft,
            child: VisualEffect(
              effect: (_) => const VisualEffectValues(offset: Offset(200, 0)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(250, 50));
      expect(taps, 1);
      await tester.tapAt(const Offset(50, 50));
      expect(taps, 1);
    });

    testWidgets('changing the effect repaints', (tester) async {
      Widget build(ScrollEffect effect) => app(
        ListView(
          children: [
            ScrollTransition(
              topInset: 50,
              effect: effect,
              child: const SizedBox(key: ValueKey('x'), height: 100),
            ),
          ],
        ),
      );
      await tester.pumpWidget(build(ScrollEffects.fade()));
      expect(opacityOf(tester, const ValueKey('x')), 0.5);
      await tester.pumpWidget(build(ScrollEffects.fade(0.5)));
      expect(opacityOf(tester, const ValueKey('x')), 0.75);
    });
  });

  testWidgets('switching configuration at runtime keeps working', (
    tester,
  ) async {
    final c = ScrollController();
    Widget build(ScrollTransitionConfiguration config) => app(
      ListView.builder(
        controller: c,
        itemExtent: 100,
        itemCount: 20,
        itemBuilder: (_, i) => ScrollTransition(
          configuration: config,
          effect: ScrollEffects.fade(),
          child: SizedBox(key: ValueKey<int>(i)),
        ),
      ),
    );
    await tester.pumpWidget(
      build(const ScrollTransitionConfiguration.interactive()),
    );
    c.jumpTo(70);
    await tester.pump();
    expect(opacityOf(tester, const ValueKey(0)), closeTo(0.3, 1e-9));
    await tester.pumpWidget(
      build(
        const ScrollTransitionConfiguration.animated(duration: Duration.zero),
      ),
    );
    await tester.pump();
    expect(opacityOf(tester, const ValueKey(0)), 0);
    await tester.pumpWidget(
      build(
        const ScrollTransitionConfiguration.interactive(curve: Curves.easeIn),
      ),
    );
    expect(
      opacityOf(tester, const ValueKey(0)),
      closeTo(1 - Curves.easeIn.transform(0.7), 1e-9),
    );
    await tester.pumpWidget(const SizedBox());
  });

  group('VisualEffect', () {
    testWidgets('effect receives exact geometry each frame', (tester) async {
      final c = ScrollController();
      final seen = <int, VisualEffectGeometry>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 20,
            itemBuilder: (_, i) => VisualEffect(
              effect: (g) {
                seen[i] = g;
                return VisualEffectValues(
                  scale: 1 - 0.2 * g.centerOffset.abs(),
                );
              },
              child: SizedBox(key: ValueKey<int>(i)),
            ),
          ),
        ),
      );
      c.jumpTo(33);
      await tester.pump();
      expect(seen[0]!.rect, const Rect.fromLTWH(0, -33, 800, 100));
      expect(seen[0]!.viewportSize, const Size(800, 600));
      expect(seen[0]!.visibleFraction, closeTo(0.67, 1e-9));
      // Item 2 centre at 217: centerOffset (217-300)/300.
      expect(seen[2]!.centerOffset, closeTo(-83 / 300, 1e-9));
      expect(
        effectOf(tester, const ValueKey(2)).lastValues!.scale,
        closeTo(1 - 0.2 * 83 / 300, 1e-9),
      );
    });

    testWidgets('builder gets predicted geometry in the same frame', (
      tester,
    ) async {
      final c = ScrollController();
      VisualEffectGeometry? seen;
      final builds = <int, int>{};
      await tester.pumpWidget(
        app(
          ListView.builder(
            controller: c,
            itemExtent: 100,
            itemCount: 20,
            itemBuilder: (_, i) => i == 1
                ? VisualEffect(
                    builder: (context, child, g) {
                      seen = g;
                      return child!;
                    },
                    child: BuildCounter(counts: builds, id: i),
                  )
                : const SizedBox(),
          ),
        ),
      );
      await tester.pump();
      expect(seen!.rect.top, 100);
      for (final o in <double>[10, 20, 70]) {
        c.jumpTo(o);
        await tester.pump();
        expect(seen!.rect.top, closeTo(100 - o, 1e-9));
      }
      expect(builds[1], 1);
    });
  });
}

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.child);
  final Widget child;
  @override
  double get minExtent => 100;
  @override
  double get maxExtent => 100;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
  @override
  bool shouldRebuild(_Header oldDelegate) => false;
}

class _KeepAliveCounter extends StatefulWidget {
  const _KeepAliveCounter({super.key});
  @override
  State<_KeepAliveCounter> createState() => _KeepAliveCounterState();
}

class _KeepAliveCounterState extends State<_KeepAliveCounter>
    with AutomaticKeepAliveClientMixin {
  int value = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text('$value');
  }
}
