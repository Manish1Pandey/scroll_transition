# scroll_transition — Specification

## Purpose

Bring SwiftUI's `.scrollTransition` and `.visualEffect` to Flutter
(flutter/flutter#128870). A widget placed anywhere inside a scroll view
learns where it sits in the viewport — its *phase* — and applies visual
effects (fade, scale, rotate, 3D tilt, blur, slide, desaturate) from that
phase, every frame, without rebuilding the widget tree on scroll.

Pure Dart, no platform code, works on every Flutter platform.

## Functional requirements

| ID | Requirement |
|----|-------------|
| FR-1 | `ScrollTransition` wraps any child inside any `Scrollable` (ListView, GridView, CustomScrollView slivers, PageView, SingleChildScrollView), vertical or horizontal, normal or reversed. |
| FR-2 | The phase is computed from the child's render box rect relative to the nearest viewport at paint time, each frame the scroll position changes. |
| FR-3 | Phase value: `-1..0` while the child crosses the **top/leading** edge, `0` when fully inside, `0..1` while crossing the **bottom/trailing** edge. Screen-space semantics like SwiftUI: "top" is the physical top, "leading" is left in LTR and right in RTL, whatever the scroll direction. |
| FR-4 | `topInset` / `bottomInset` shrink the region the child counts as "fully inside" (for example, behind a pinned header). |
| FR-5 | `ScrollTransitionConfiguration.interactive({curve})` follows the scroll continuously; `.animated({duration, curve, threshold})` switches between the three discrete phases (-1, 0, 1) when the visible fraction crosses `threshold` and animates between them. |
| FR-6 | `effect:` (a `ScrollEffect`) is applied at paint time through a custom `RenderProxyBox`. It uses layers (transform, opacity, colour filter, image filter) and does no rebuilds. |
| FR-7 | Ready-made effects: `ScrollEffects.fade`, `scale`, `rotate`, `rotate3D`, `blur`, `slide`, `translate`, `saturate`, `custom`. You chain them: `ScrollEffects.fade().scale(0.8).blur(4)`. |
| FR-8 | `builder: (context, child, phase)` lets you build arbitrary widgets from the phase. Only the builder reruns, and only when the phase changes. `child` is never rebuilt. |
| FR-9 | `VisualEffect(effect: (geometry) => VisualEffectValues)` gets the geometry (rect in the viewport, viewport size, axis direction, text direction, helpers) and applies the result at paint time. `VisualEffect(builder:)` is the rebuild-based variant. |
| FR-10 | Outside any `Scrollable`: phase = identity, geometry.hasViewport = false. |
| FR-11 | Hit testing follows the painted transform. |
| FR-12 | Correct with keep-alive items, pinned headers, nested scrollables (phase is always relative to the *nearest* scrollable) and RTL. |

## Can / Cannot

| Can | Cannot / limits |
|-----|-----------------|
| Animate any child from its viewport position with zero rebuilds (`effect:` / `VisualEffect(effect:)`). | Change layout from the phase with zero rebuilds. Layout-affecting output needs `builder:`, which rebuilds when the phase changes (like SwiftUI, which only allows visual effects there). |
| Exact, same-frame phase for `effect:` in every scroll view. | The `builder:` path predicts the phase when the scroll position changes, so it is same-frame for normal items. For children whose movement is not proportional to scroll (pinned/floating headers), the first scroll frame can be off by one frame until the ratio is learned. |
| Items entering the viewport for the first time in builder mode are never painted with a wrong phase. | That first frame is skipped instead (the item is invisible for 1 frame at the viewport edge). |
| Work in ListView/GridView/CustomScrollView/PageView/SingleChildScrollView, reversed, horizontal, RTL. | Two-dimensional scroll views (`TwoDimensionalScrollView`): only the nearest scrollable's axis is used. |
| Update when the scroll offset changes or the item is relaid out or repainted. | If an item moves inside the viewport *without* the scroll offset changing and without repainting (for example, a sibling above resizes while the item sits behind a RepaintBoundary), the phase refreshes on the next scroll or repaint. |
| Blur, desaturate, 3D tilt on every platform (Skia and Impeller). | Blur is an image filter, so it costs GPU per item. Keep sigma modest in long lists. |

## Public API sketch

```dart
ScrollTransition({
  ScrollEffect? effect,
  ScrollTransitionWidgetBuilder? builder,   // (context, child, phase) => Widget
  ScrollTransitionConfiguration configuration = const ScrollTransitionConfiguration.interactive(),
  double topInset = 0, double bottomInset = 0,
  Widget? child,
})

class ScrollTransitionPhase { double value; ScrollPhase kind; bool isIdentity;
  static ScrollTransitionPhase fromGeometry(VisualEffectGeometry, {topInset, bottomInset}); }
enum ScrollPhase { topLeading, identity, bottomTrailing }

ScrollTransitionConfiguration.interactive({Curve curve})
ScrollTransitionConfiguration.animated({Duration duration, Curve curve, double threshold})

abstract final class ScrollEffects { fade, scale, rotate, rotate3D, blur, slide, translate, saturate, custom, none }
class ScrollEffect { chainable same-named methods; then(); resolve(phase, axis:, textDirection:) }

class VisualEffectValues { opacity, offset, scale, rotation, rotationX, rotationY, blur, saturation, alignment, perspective; merge(); transformFor(size) }

VisualEffect({VisualEffectCallback? effect, VisualEffectWidgetBuilder? builder, Widget? child})
class VisualEffectGeometry { rect, viewportSize, axisDirection, textDirection, hasViewport,
  axis, leadingOffset, mainAxisExtent, viewportMainAxisExtent, visibleFraction, centerOffset, phase() }
```

## Platform matrix

| Android | iOS | Web | macOS | Windows | Linux |
|---------|-----|-----|-------|---------|-------|
| yes | yes | yes | yes | yes | yes |

Pure Dart and Flutter framework only. Verified here by tests plus example builds for web and macOS.
