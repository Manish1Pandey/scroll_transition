import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'effect_values.dart';
import 'phase.dart';

/// Computes [VisualEffectValues] from a phase. Used by
/// [ScrollEffects.custom].
typedef ScrollEffectCallback =
    VisualEffectValues Function(ScrollTransitionPhase phase);

/// A composable, immutable description of how a widget looks at each
/// [ScrollTransitionPhase].
///
/// Start one from [ScrollEffects] and chain more effects onto it:
///
/// ```dart
/// ScrollEffects.fade().scale(0.8).blur(4)
/// ```
///
/// Every effect is the identity at phase 0 and at full strength at phase
/// ±1.
@immutable
class ScrollEffect {
  const ScrollEffect._(this._parts);

  final List<_EffectPart> _parts;

  /// Whether this effect has no parts.
  bool get isNone => _parts.isEmpty;

  ScrollEffect _add(_EffectPart part) => ScrollEffect._(
    List<_EffectPart>.unmodifiable(<_EffectPart>[..._parts, part]),
  );

  /// Adds a fade to [opacity] at full phase. See [ScrollEffects.fade].
  ScrollEffect fade([double opacity = 0.0]) => _add(_Fade(opacity));

  /// Adds a uniform scale. See [ScrollEffects.scale].
  ScrollEffect scale([double scale = 0.75, Alignment? alignment]) =>
      _add(_Scale(scale, alignment));

  /// Adds a 2D rotation. See [ScrollEffects.rotate].
  ScrollEffect rotate([double angle = math.pi / 12]) => _add(_Rotate(angle));

  /// Adds a 3D tilt. See [ScrollEffects.rotate3D].
  ScrollEffect rotate3D({
    double angle = math.pi / 4,
    Axis? axis,
    double? perspective,
  }) => _add(_Rotate3D(angle, axis, perspective));

  /// Adds a Gaussian blur. See [ScrollEffects.blur].
  ScrollEffect blur([double sigma = 8.0]) => _add(_Blur(sigma));

  /// Adds a slide. See [ScrollEffects.slide].
  ScrollEffect slide([double distance = 48.0, Axis? axis]) =>
      _add(_Slide(distance, axis));

  /// Adds a fixed translation. See [ScrollEffects.translate].
  ScrollEffect translate(Offset offset) => _add(_Translate(offset));

  /// Adds a saturation change. See [ScrollEffects.saturate].
  ScrollEffect saturate([double saturation = 0.0]) =>
      _add(_Saturate(saturation));

  /// Adds a custom effect. See [ScrollEffects.custom].
  ScrollEffect custom(ScrollEffectCallback callback) => _add(_Custom(callback));

  /// Adds every part of [other] after this effect's parts.
  ScrollEffect then(ScrollEffect other) => ScrollEffect._(
    List<_EffectPart>.unmodifiable(<_EffectPart>[..._parts, ...other._parts]),
  );

  /// Computes the combined values for [phase].
  ///
  /// [axis] is the scroll axis. It picks the slide direction and the 3D
  /// tilt axis. [textDirection] makes horizontal slides and tilts follow
  /// the leading edge.
  VisualEffectValues resolve(
    ScrollTransitionPhase phase, {
    Axis axis = Axis.vertical,
    TextDirection textDirection = TextDirection.ltr,
  }) {
    var values = VisualEffectValues.identity;
    for (final part in _parts) {
      values = values.merge(part.resolve(phase, axis, textDirection));
    }
    return values;
  }

  @override
  bool operator ==(Object other) =>
      other is ScrollEffect && listEquals(other._parts, _parts);

  @override
  int get hashCode => Object.hashAll(_parts);

  @override
  String toString() => 'ScrollEffect(${_parts.join(', ')})';
}

/// Ready-made [ScrollEffect]s. Chain more with the instance methods of the
/// same name: `ScrollEffects.fade().scale(0.8)`.
abstract final class ScrollEffects {
  /// An effect that does nothing. Use it as the start of a chain built in
  /// a loop.
  static const ScrollEffect none = ScrollEffect._(<_EffectPart>[]);

  /// Fades to [opacity] (0..1) as the widget reaches phase ±1.
  static ScrollEffect fade([double opacity = 0.0]) => none.fade(opacity);

  /// Scales to [scale] at phase ±1 around [alignment] (default: centre).
  static ScrollEffect scale([double scale = 0.75, Alignment? alignment]) =>
      none.scale(scale, alignment);

  /// Rotates in 2D by `angle * phase.value` radians. Widgets leaving the
  /// top/leading edge turn one way, widgets leaving the bottom/trailing
  /// edge the other.
  static ScrollEffect rotate([double angle = math.pi / 12]) =>
      none.rotate(angle);

  /// Tilts the widget in 3D by up to [angle] radians, so the edge nearest
  /// the viewport boundary it is crossing recedes, like cards on a drum.
  ///
  /// [axis] is the rotation axis. It defaults to the axis perpendicular to
  /// scrolling: [Axis.horizontal] (rotate around X) for vertical lists,
  /// [Axis.vertical] (rotate around Y) for horizontal ones.
  /// [perspective] overrides [VisualEffectValues.defaultPerspective].
  static ScrollEffect rotate3D({
    double angle = math.pi / 4,
    Axis? axis,
    double? perspective,
  }) => none.rotate3D(angle: angle, axis: axis, perspective: perspective);

  /// Blurs with Gaussian sigma `sigma * |phase|`.
  static ScrollEffect blur([double sigma = 8.0]) => none.blur(sigma);

  /// Moves the widget by `distance * phase.value` logical pixels along
  /// [axis] (default: the scroll axis), away from the viewport centre as it
  /// leaves.
  static ScrollEffect slide([double distance = 48.0, Axis? axis]) =>
      none.slide(distance, axis);

  /// Moves the widget by `offset * |phase|`, the same direction at both
  /// edges. Use it for "slide in from the side" entrances.
  static ScrollEffect translate(Offset offset) => none.translate(offset);

  /// Moves colour saturation towards [saturation] (0 = greyscale) at phase
  /// ±1.
  static ScrollEffect saturate([double saturation = 0.0]) =>
      none.saturate(saturation);

  /// An arbitrary effect computed from the phase.
  static ScrollEffect custom(ScrollEffectCallback callback) =>
      none.custom(callback);
}

@immutable
sealed class _EffectPart {
  const _EffectPart();

  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection textDirection,
  );
}

double _leadingSign(Axis axis, TextDirection textDirection) =>
    axis == Axis.horizontal && textDirection == TextDirection.rtl ? -1 : 1;

final class _Fade extends _EffectPart {
  const _Fade(this.opacity);
  final double opacity;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(opacity: lerpDouble(1.0, opacity, phase.magnitude)!);

  @override
  bool operator ==(Object other) => other is _Fade && other.opacity == opacity;
  @override
  int get hashCode => Object.hash(_Fade, opacity);
  @override
  String toString() => 'fade($opacity)';
}

final class _Scale extends _EffectPart {
  const _Scale(this.scale, this.alignment);
  final double scale;
  final Alignment? alignment;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(
    scale: lerpDouble(1.0, scale, phase.magnitude)!,
    alignment: alignment,
  );

  @override
  bool operator ==(Object other) =>
      other is _Scale && other.scale == scale && other.alignment == alignment;
  @override
  int get hashCode => Object.hash(_Scale, scale, alignment);
  @override
  String toString() => 'scale($scale)';
}

final class _Rotate extends _EffectPart {
  const _Rotate(this.angle);
  final double angle;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(rotation: angle * phase.value);

  @override
  bool operator ==(Object other) => other is _Rotate && other.angle == angle;
  @override
  int get hashCode => Object.hash(_Rotate, angle);
  @override
  String toString() => 'rotate($angle)';
}

final class _Rotate3D extends _EffectPart {
  const _Rotate3D(this.angle, this.axis, this.perspective);
  final double angle;
  final Axis? axis;
  final double? perspective;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis scrollAxis,
    TextDirection td,
  ) {
    final rotationAxis =
        axis ?? (scrollAxis == Axis.vertical ? Axis.horizontal : Axis.vertical);
    if (rotationAxis == Axis.horizontal) {
      // Around X: at phase -1 (top) the top edge recedes.
      return VisualEffectValues(
        rotationX: angle * phase.value,
        perspective: perspective,
      );
    }
    // Around Y: the leading edge recedes when leaving at the leading side.
    return VisualEffectValues(
      rotationY: -angle * phase.value * _leadingSign(Axis.horizontal, td),
      perspective: perspective,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Rotate3D &&
      other.angle == angle &&
      other.axis == axis &&
      other.perspective == perspective;
  @override
  int get hashCode => Object.hash(_Rotate3D, angle, axis, perspective);
  @override
  String toString() => 'rotate3D($angle, $axis)';
}

final class _Blur extends _EffectPart {
  const _Blur(this.sigma) : assert(sigma >= 0);
  final double sigma;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(blur: sigma * phase.magnitude);

  @override
  bool operator ==(Object other) => other is _Blur && other.sigma == sigma;
  @override
  int get hashCode => Object.hash(_Blur, sigma);
  @override
  String toString() => 'blur($sigma)';
}

final class _Slide extends _EffectPart {
  const _Slide(this.distance, this.axis);
  final double distance;
  final Axis? axis;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis scrollAxis,
    TextDirection td,
  ) {
    final slideAxis = axis ?? scrollAxis;
    final amount = distance * phase.value;
    if (slideAxis == Axis.vertical) {
      return VisualEffectValues(offset: Offset(0, amount));
    }
    return VisualEffectValues(
      offset: Offset(amount * _leadingSign(Axis.horizontal, td), 0),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _Slide && other.distance == distance && other.axis == axis;
  @override
  int get hashCode => Object.hash(_Slide, distance, axis);
  @override
  String toString() => 'slide($distance, $axis)';
}

final class _Translate extends _EffectPart {
  const _Translate(this.offset);
  final Offset offset;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(offset: offset * phase.magnitude);

  @override
  bool operator ==(Object other) =>
      other is _Translate && other.offset == offset;
  @override
  int get hashCode => Object.hash(_Translate, offset);
  @override
  String toString() => 'translate($offset)';
}

final class _Saturate extends _EffectPart {
  const _Saturate(this.saturation) : assert(saturation >= 0);
  final double saturation;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => VisualEffectValues(
    saturation: lerpDouble(1.0, saturation, phase.magnitude)!,
  );

  @override
  bool operator ==(Object other) =>
      other is _Saturate && other.saturation == saturation;
  @override
  int get hashCode => Object.hash(_Saturate, saturation);
  @override
  String toString() => 'saturate($saturation)';
}

final class _Custom extends _EffectPart {
  const _Custom(this.callback);
  final ScrollEffectCallback callback;

  @override
  VisualEffectValues resolve(
    ScrollTransitionPhase phase,
    Axis axis,
    TextDirection td,
  ) => callback(phase);

  @override
  bool operator ==(Object other) =>
      other is _Custom && other.callback == callback;
  @override
  int get hashCode => Object.hash(_Custom, callback);
  @override
  String toString() => 'custom';
}
