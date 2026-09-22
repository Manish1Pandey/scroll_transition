import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scroll_transition/scroll_transition.dart';

VisualEffectGeometry vertical(double top, {double extent = 100}) =>
    VisualEffectGeometry(
      rect: Rect.fromLTWH(0, top, 800, extent),
      viewportSize: const Size(800, 600),
    );

void main() {
  group('ScrollTransitionPhase.fromGeometry', () {
    test('identity when fully inside', () {
      expect(vertical(0).phase().value, 0);
      expect(vertical(250).phase().value, 0);
      expect(vertical(500).phase().value, 0);
    });

    test('top/leading edge is -1..0', () {
      expect(vertical(-25).phase().value, -0.25);
      expect(vertical(-50).phase().value, -0.5);
      expect(vertical(-100).phase().value, -1);
      expect(vertical(-400).phase().value, -1);
      expect(vertical(-50).phase().kind, ScrollPhase.topLeading);
    });

    test('bottom/trailing edge is 0..1', () {
      expect(vertical(550).phase().value, 0.5);
      expect(vertical(600).phase().value, 1);
      expect(vertical(575).phase().kind, ScrollPhase.bottomTrailing);
    });

    test('insets shrink the identity region', () {
      expect(vertical(0).phase(topInset: 100).value, -1);
      expect(vertical(50).phase(topInset: 100).value, -0.5);
      expect(vertical(100).phase(topInset: 100).value, 0);
      expect(vertical(450).phase(bottomInset: 100).value, 0.5);
    });

    test('items larger than the region are continuous through 0', () {
      // Extent 800 in a 600 viewport: identity while covering it.
      expect(vertical(0, extent: 800).phase().value, 0);
      expect(vertical(-200, extent: 800).phase().value, 0);
      expect(vertical(-100, extent: 800).phase().value, 0);
      expect(vertical(300, extent: 800).phase().value, 0.5);
      expect(vertical(-500, extent: 800).phase().value, -0.5);
      expect(vertical(-800, extent: 800).phase().value, -1);
    });

    test('horizontal honours text direction', () {
      const ltr = VisualEffectGeometry(
        rect: Rect.fromLTWH(-100, 0, 200, 600),
        viewportSize: Size(800, 600),
        axisDirection: AxisDirection.right,
      );
      expect(ltr.phase().value, -0.5);
      const rtl = VisualEffectGeometry(
        rect: Rect.fromLTWH(700, 0, 200, 600),
        viewportSize: Size(800, 600),
        axisDirection: AxisDirection.left,
        textDirection: TextDirection.rtl,
      );
      // Right edge sticks out by 100 at the RTL leading side.
      expect(rtl.leadingOffset, -100);
      expect(rtl.phase().value, -0.5);
    });

    test('standalone geometry is identity', () {
      final g = VisualEffectGeometry.standalone(const Size(10, 10));
      expect(g.hasViewport, isFalse);
      expect(g.phase(topInset: 50).value, 0);
    });

    test('degenerate regions and zero extents', () {
      expect(vertical(10, extent: 0).phase().value, 0);
      expect(vertical(-1, extent: 0).phase().value, -1);
      expect(vertical(601, extent: 0).phase().value, 1);
      expect(vertical(0).phase(topInset: 400, bottomInset: 400).value, -1);
      expect(vertical(500).phase(topInset: 400, bottomInset: 400).value, 1);
    });
  });

  group('discreteFromGeometry', () {
    test('threshold decides identity', () {
      expect(
        ScrollTransitionPhase.discreteFromGeometry(vertical(-40)).value,
        0,
      );
      expect(
        ScrollTransitionPhase.discreteFromGeometry(vertical(-60)).value,
        -1,
      );
      expect(
        ScrollTransitionPhase.discreteFromGeometry(vertical(560)).value,
        1,
      );
      expect(
        ScrollTransitionPhase.discreteFromGeometry(
          vertical(-99),
          threshold: 0,
        ).value,
        0,
      );
      expect(
        ScrollTransitionPhase.discreteFromGeometry(
          vertical(-10),
          threshold: 1,
        ).value,
        -1,
      );
      expect(
        ScrollTransitionPhase.discreteFromGeometry(
          VisualEffectGeometry.standalone(const Size(1, 1)),
        ).value,
        0,
      );
    });
  });

  group('phase helpers', () {
    test('clamping, kind, magnitude and curve', () {
      expect(const ScrollTransitionPhase(-3).value, -1);
      expect(const ScrollTransitionPhase(2).value, 1);
      expect(ScrollTransitionPhase.identity.isIdentity, isTrue);
      expect(const ScrollTransitionPhase(-0.4).magnitude, 0.4);
      final curved = const ScrollTransitionPhase(-0.5).curved(Curves.easeIn);
      expect(curved.value, closeTo(-Curves.easeIn.transform(0.5), 1e-12));
      expect(const ScrollTransitionPhase(0.5).curved(Curves.linear).value, 0.5);
    });

    test('geometry helpers', () {
      final g = vertical(-50);
      expect(g.visibleFraction, 0.5);
      expect(g.centerOffset, -1);
      expect(vertical(250).centerOffset, 0);
      expect(g.shiftedPhysical(30).rect.top, -20);
      expect(g.closeTo(vertical(-50.0000001)), isTrue);
      expect(g == vertical(-50), isTrue);
    });
  });

  group('ScrollEffects', () {
    const half = ScrollTransitionPhase(-0.5);

    test('fade', () {
      expect(ScrollEffects.fade().resolve(half).opacity, 0.5);
      expect(
        ScrollEffects.fade(
          0.2,
        ).resolve(ScrollTransitionPhase.topLeading).opacity,
        closeTo(0.2, 1e-12),
      );
      expect(
        ScrollEffects.fade().resolve(ScrollTransitionPhase.identity).isIdentity,
        isTrue,
      );
    });

    test('scale, rotate, blur, saturate', () {
      expect(ScrollEffects.scale(0.5).resolve(half).scale, 0.75);
      expect(ScrollEffects.rotate(1).resolve(half).rotation, -0.5);
      expect(ScrollEffects.blur(10).resolve(half).blur, 5);
      expect(ScrollEffects.saturate(0).resolve(half).saturation, 0.5);
    });

    test('rotate3D picks the axis perpendicular to scrolling', () {
      final v = ScrollEffects.rotate3D(angle: 1).resolve(half);
      expect(v.rotationX, -0.5);
      expect(v.rotationY, 0);
      final h = ScrollEffects.rotate3D(
        angle: 1,
      ).resolve(half, axis: Axis.horizontal);
      expect(h.rotationY, 0.5);
      final hRtl = ScrollEffects.rotate3D(
        angle: 1,
      ).resolve(half, axis: Axis.horizontal, textDirection: TextDirection.rtl);
      expect(hRtl.rotationY, -0.5);
    });

    test('slide follows the scroll axis and leading edge', () {
      expect(
        ScrollEffects.slide(40).resolve(half).offset,
        const Offset(0, -20),
      );
      expect(
        ScrollEffects.slide(40).resolve(half, axis: Axis.horizontal).offset,
        const Offset(-20, 0),
      );
      expect(
        ScrollEffects.slide(40)
            .resolve(
              half,
              axis: Axis.horizontal,
              textDirection: TextDirection.rtl,
            )
            .offset,
        const Offset(20, 0),
      );
      expect(
        ScrollEffects.translate(const Offset(100, 0)).resolve(half).offset,
        const Offset(50, 0),
      );
    });

    test('chaining combines parts', () {
      final effect = ScrollEffects.fade().scale(0.5).blur(6).slide(10);
      final v = effect.resolve(const ScrollTransitionPhase(1));
      expect(v.opacity, 0);
      expect(v.scale, 0.5);
      expect(v.blur, closeTo(6, 1e-12));
      expect(v.offset, const Offset(0, 10));
      expect(
        ScrollEffects.fade().then(ScrollEffects.scale(0.5)),
        ScrollEffects.fade().scale(0.5),
      );
      expect(ScrollEffects.none.isNone, isTrue);
    });

    test('custom effects', () {
      final effect = ScrollEffects.custom(
        (p) => VisualEffectValues(opacity: p.isIdentity ? 1 : 0.3),
      );
      expect(effect.resolve(half).opacity, 0.3);
      expect(effect.resolve(ScrollTransitionPhase.identity).opacity, 1);
    });
  });

  group('VisualEffectValues', () {
    test('merge rules', () {
      const a = VisualEffectValues(
        opacity: 0.5,
        scale: 2,
        blur: 3,
        offset: Offset(1, 0),
      );
      const b = VisualEffectValues(
        opacity: 0.5,
        scale: 0.5,
        blur: 4,
        offset: Offset(0, 1),
      );
      final m = a.merge(b);
      expect(m.opacity, 0.25);
      expect(m.scale, 1);
      expect(m.blur, 5);
      expect(m.offset, const Offset(1, 1));
      expect(VisualEffectValues.identity.merge(a), a);
    });

    test('transformFor scales around the centre and translates', () {
      const v = VisualEffectValues(scale: 0.5, offset: Offset(10, 0));
      final m = v.transformFor(const Size(100, 100));
      final topLeft = MatrixUtils.transformPoint(m, Offset.zero);
      expect(topLeft, const Offset(35, 25));
      const r = VisualEffectValues(rotation: math.pi);
      final p = MatrixUtils.transformPoint(
        r.transformFor(const Size(100, 100)),
        Offset.zero,
      );
      expect(p.dx, closeTo(100, 1e-9));
      expect(p.dy, closeTo(100, 1e-9));
    });

    test('filters', () {
      expect(VisualEffectValues.identity.saturationFilter, isNull);
      expect(VisualEffectValues.identity.blurFilter, isNull);
      expect(
        const VisualEffectValues(saturation: 0).saturationFilter,
        isNotNull,
      );
      expect(const VisualEffectValues(blur: 2).blurFilter, isNotNull);
      expect(const VisualEffectValues(rotationX: 0.3).hasTransform, isTrue);
    });
  });

  test('configuration equality', () {
    expect(
      const ScrollTransitionConfiguration.animated(),
      const ScrollTransitionConfiguration.animated(),
    );
    expect(
      const ScrollTransitionConfiguration.animated() ==
          const ScrollTransitionConfiguration.interactive(),
      isFalse,
    );
  });
}
