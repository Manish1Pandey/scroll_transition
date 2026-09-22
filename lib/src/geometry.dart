import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'phase.dart';

/// Where a widget sits in its nearest scroll viewport, measured during
/// the paint phase of the current frame.
///
/// All rects are in logical pixels in the viewport's coordinate system
/// (origin at the viewport's top-left). They describe the widget's layout
/// box *before* its own visual effect is applied.
@immutable
class VisualEffectGeometry {
  /// Creates a geometry snapshot.
  const VisualEffectGeometry({
    required this.rect,
    required this.viewportSize,
    this.axisDirection = AxisDirection.down,
    this.textDirection = TextDirection.ltr,
    this.hasViewport = true,
  });

  /// Geometry for a widget that is not inside any scroll viewport. The
  /// widget is treated as its own viewport, so it is always fully
  /// visible and its phase is identity.
  factory VisualEffectGeometry.standalone(
    Size size, {
    TextDirection textDirection = TextDirection.ltr,
  }) {
    return VisualEffectGeometry(
      rect: Offset.zero & size,
      viewportSize: size,
      textDirection: textDirection,
      hasViewport: false,
    );
  }

  /// The widget's bounds in viewport coordinates.
  final Rect rect;

  /// The size of the viewport the widget scrolls in.
  final Size viewportSize;

  /// The scroll direction of the viewport (for example
  /// [AxisDirection.up] for a reversed vertical list).
  final AxisDirection axisDirection;

  /// The ambient text direction. It decides which horizontal edge is
  /// "leading".
  final TextDirection textDirection;

  /// Whether the widget is inside a scroll viewport. When false, [rect]
  /// fills [viewportSize] and every phase is identity.
  final bool hasViewport;

  /// The scroll axis of the viewport.
  Axis get axis => axisDirectionToAxis(axisDirection);

  /// The viewport as a rect in its own coordinates.
  Rect get viewportRect => Offset.zero & viewportSize;

  /// The widget's extent along the scroll axis.
  double get mainAxisExtent => axis == Axis.vertical ? rect.height : rect.width;

  /// The viewport's extent along the scroll axis.
  double get viewportMainAxisExtent =>
      axis == Axis.vertical ? viewportSize.height : viewportSize.width;

  /// Distance from the viewport's top (vertical) or leading (horizontal:
  /// left in LTR, right in RTL) edge to the widget's matching edge. It is
  /// negative when the widget sticks out past that edge.
  double get leadingOffset {
    if (axis == Axis.vertical) return rect.top;
    return textDirection == TextDirection.ltr
        ? rect.left
        : viewportSize.width - rect.right;
  }

  /// The fraction (0..1) of the widget's main-axis extent that lies inside
  /// the viewport. A zero-extent widget counts as 1 when its position is
  /// inside the viewport and 0 otherwise.
  double get visibleFraction {
    final extent = mainAxisExtent;
    final start = leadingOffset;
    final end = start + extent;
    final viewportExtent = viewportMainAxisExtent;
    if (extent <= 0) {
      return (start >= 0 && start <= viewportExtent) ? 1.0 : 0.0;
    }
    final overlap = math.min(end, viewportExtent) - math.max(start, 0.0);
    return (overlap / extent).clamp(0.0, 1.0);
  }

  /// Signed distance from the viewport centre to the widget centre along
  /// the scroll axis, normalised by half the viewport extent. The result
  /// is `-1` when the widget centre is on the top/leading edge, `0` when
  /// centred and `1` on the bottom/trailing edge. It is not clamped.
  double get centerOffset {
    final half = viewportMainAxisExtent / 2;
    if (half <= 0) return 0;
    final center = leadingOffset + mainAxisExtent / 2;
    return (center - half) / half;
  }

  /// The [ScrollTransitionPhase] for this geometry. See
  /// [ScrollTransitionPhase.fromGeometry].
  ScrollTransitionPhase phase({double topInset = 0, double bottomInset = 0}) {
    return ScrollTransitionPhase.fromGeometry(
      this,
      topInset: topInset,
      bottomInset: bottomInset,
    );
  }

  /// Returns a copy with the widget moved by [delta] along the main axis
  /// in *physical* coordinates (positive = down or right).
  VisualEffectGeometry shiftedPhysical(double delta) {
    final offset = axis == Axis.vertical ? Offset(0, delta) : Offset(delta, 0);
    return VisualEffectGeometry(
      rect: rect.shift(offset),
      viewportSize: viewportSize,
      axisDirection: axisDirection,
      textDirection: textDirection,
      hasViewport: hasViewport,
    );
  }

  /// Whether [other] describes the same geometry within [tolerance]
  /// logical pixels.
  bool closeTo(VisualEffectGeometry other, {double tolerance = 1e-3}) {
    bool near(double a, double b) => (a - b).abs() <= tolerance;
    return hasViewport == other.hasViewport &&
        axisDirection == other.axisDirection &&
        textDirection == other.textDirection &&
        near(rect.left, other.rect.left) &&
        near(rect.top, other.rect.top) &&
        near(rect.right, other.rect.right) &&
        near(rect.bottom, other.rect.bottom) &&
        near(viewportSize.width, other.viewportSize.width) &&
        near(viewportSize.height, other.viewportSize.height);
  }

  @override
  bool operator ==(Object other) {
    return other is VisualEffectGeometry &&
        other.rect == rect &&
        other.viewportSize == viewportSize &&
        other.axisDirection == axisDirection &&
        other.textDirection == textDirection &&
        other.hasViewport == hasViewport;
  }

  @override
  int get hashCode => Object.hash(
    rect,
    viewportSize,
    axisDirection,
    textDirection,
    hasViewport,
  );

  @override
  String toString() =>
      'VisualEffectGeometry(rect: $rect, viewport: $viewportSize, '
      '$axisDirection, $textDirection${hasViewport ? '' : ', standalone'})';
}
