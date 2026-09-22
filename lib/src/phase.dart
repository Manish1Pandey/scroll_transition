import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'geometry.dart';

/// The three discrete states of a scroll transition, mirroring SwiftUI's
/// `ScrollTransitionPhase`.
enum ScrollPhase {
  /// The widget is partly or fully past the top (vertical) or leading
  /// (horizontal) edge of the viewport.
  topLeading,

  /// The widget is fully inside the viewport, or the inset region.
  identity,

  /// The widget is partly or fully past the bottom (vertical) or trailing
  /// (horizontal) edge of the viewport.
  bottomTrailing,
}

/// Where a widget is in its scroll transition, as a value from `-1` to `1`.
///
/// * `-1`: fully past the top/leading edge.
/// * `0`: fully visible (identity).
/// * `1`: fully past the bottom/trailing edge.
///
/// "Top/leading" is screen space: the physical top for vertical scrolling,
/// and the leading edge (left in LTR, right in RTL) for horizontal
/// scrolling. The scroll direction and `reverse` do not change it.
@immutable
class ScrollTransitionPhase {
  /// Creates a phase with the given [value], clamped to `-1..1`.
  const ScrollTransitionPhase(double value)
    : value = value < -1.0 ? -1.0 : (value > 1.0 ? 1.0 : value);

  /// The fully-visible phase.
  static const ScrollTransitionPhase identity = ScrollTransitionPhase(0);

  /// Fully past the top/leading edge.
  static const ScrollTransitionPhase topLeading = ScrollTransitionPhase(-1);

  /// Fully past the bottom/trailing edge.
  static const ScrollTransitionPhase bottomTrailing = ScrollTransitionPhase(1);

  /// The continuous phase value from `-1` to `1`.
  final double value;

  /// The discrete phase this value belongs to.
  ScrollPhase get kind => value < 0
      ? ScrollPhase.topLeading
      : (value > 0 ? ScrollPhase.bottomTrailing : ScrollPhase.identity);

  /// Whether the widget is fully visible (`value == 0`).
  bool get isIdentity => value == 0;

  /// How far the widget is from identity, from `0` to `1`, whichever edge
  /// it is crossing.
  double get magnitude => value.abs();

  /// Returns this phase with its magnitude reshaped by [curve]. The sign
  /// stays the same.
  ScrollTransitionPhase curved(Curve curve) {
    if (value == 0 || identical(curve, Curves.linear)) return this;
    return ScrollTransitionPhase(
      value.sign * curve.transform(value.abs().clamp(0.0, 1.0)),
    );
  }

  /// Computes the continuous phase for [geometry].
  ///
  /// The "fully inside" region is the viewport shrunk by [topInset] at
  /// the top/leading edge and [bottomInset] at the bottom/trailing edge.
  /// A widget reaches `-1`/`1` once it is fully outside the region, and is
  /// `0` while fully inside. A widget larger than the region is `0` while
  /// it covers the region, and moves towards `±1` over the region's extent.
  static ScrollTransitionPhase fromGeometry(
    VisualEffectGeometry geometry, {
    double topInset = 0,
    double bottomInset = 0,
  }) {
    if (!geometry.hasViewport) return identity;
    final start = topInset;
    final end = geometry.viewportMainAxisExtent - bottomInset;
    final region = end - start;
    final extent = geometry.mainAxisExtent;
    final leading = geometry.leadingOffset;
    if (region <= 0 || extent <= 0) {
      if (extent <= 0 && region > 0) {
        if (leading < start) return topLeading;
        if (leading > end) return bottomTrailing;
        return identity;
      }
      final center = leading + extent / 2;
      return center < (start + end) / 2 ? topLeading : bottomTrailing;
    }
    final upper = math.min(start, end - extent);
    final lower = math.max(start, end - extent);
    final span = math.min(extent, region);
    if (leading < upper) {
      return ScrollTransitionPhase(-((upper - leading) / span));
    }
    if (leading > lower) {
      return ScrollTransitionPhase((leading - lower) / span);
    }
    return identity;
  }

  /// Computes the discrete phase used by
  /// [ScrollTransitionConfiguration.animated]. It is identity when at
  /// least [threshold] of the widget's main-axis extent is inside the
  /// inset region (any visible part when [threshold] is 0). Otherwise it
  /// is [topLeading] or [bottomTrailing], whichever edge the widget is
  /// beyond.
  static ScrollTransitionPhase discreteFromGeometry(
    VisualEffectGeometry geometry, {
    double topInset = 0,
    double bottomInset = 0,
    double threshold = 0.5,
  }) {
    if (!geometry.hasViewport) return identity;
    final start = topInset;
    final end = geometry.viewportMainAxisExtent - bottomInset;
    final region = end - start;
    final extent = geometry.mainAxisExtent;
    final leading = geometry.leadingOffset;
    if (region > 0) {
      final overlap =
          math.min(leading + extent, end) - math.max(leading, start);
      final denominator = math.min(extent, region);
      final visible = threshold <= 0
          ? (extent <= 0 ? (leading >= start && leading <= end) : overlap > 0)
          : (denominator > 0 && overlap / denominator >= threshold - 1e-9);
      if (visible) return identity;
    }
    final continuous = fromGeometry(
      geometry,
      topInset: topInset,
      bottomInset: bottomInset,
    );
    if (continuous.value != 0) {
      return continuous.value < 0 ? topLeading : bottomTrailing;
    }
    final center = leading + extent / 2;
    return center < (start + end) / 2 ? topLeading : bottomTrailing;
  }

  /// Whether [other] is within [tolerance] of this phase.
  bool closeTo(ScrollTransitionPhase other, {double tolerance = 1e-6}) =>
      (value - other.value).abs() <= tolerance;

  @override
  bool operator ==(Object other) =>
      other is ScrollTransitionPhase && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() =>
      'ScrollTransitionPhase(${value.toStringAsFixed(3)}, ${kind.name})';
}

/// How the phase follows the scroll position. Mirrors SwiftUI's
/// `ScrollTransitionConfiguration`.
@immutable
class ScrollTransitionConfiguration {
  /// The phase follows the scroll position continuously. [curve] reshapes
  /// the phase magnitude, for example `Curves.easeIn` to keep items near
  /// identity for longer.
  const ScrollTransitionConfiguration.interactive({this.curve = Curves.linear})
    : isAnimated = false,
      duration = Duration.zero,
      threshold = 0;

  /// The phase snaps between `-1`, `0` and `1`. It becomes identity once
  /// [threshold] (0..1) of the widget is visible, and animates to each new
  /// state over [duration] with [curve]. On first appearance the widget
  /// takes its initial state without animating.
  const ScrollTransitionConfiguration.animated({
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeInOut,
    this.threshold = 0.5,
  }) : isAnimated = true,
       assert(threshold >= 0 && threshold <= 1);

  /// Whether this is the animated configuration.
  final bool isAnimated;

  /// Interactive: the curve applied to the phase magnitude. Animated: the
  /// animation curve.
  final Curve curve;

  /// Animated only: the animation duration.
  final Duration duration;

  /// Animated only: the visible fraction at which the widget counts as
  /// identity.
  final double threshold;

  @override
  bool operator ==(Object other) =>
      other is ScrollTransitionConfiguration &&
      other.isAnimated == isAnimated &&
      other.curve == curve &&
      other.duration == duration &&
      other.threshold == threshold;

  @override
  int get hashCode => Object.hash(isAnimated, curve, duration, threshold);

  @override
  String toString() => isAnimated
      ? 'ScrollTransitionConfiguration.animated($duration, $curve, threshold: $threshold)'
      : 'ScrollTransitionConfiguration.interactive($curve)';
}
