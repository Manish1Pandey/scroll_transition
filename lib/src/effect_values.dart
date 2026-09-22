import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A set of paint-time visual adjustments: opacity, transform, blur and
/// saturation. They never affect layout. Mirrors the modifiers SwiftUI
/// allows inside `.visualEffect` and `.scrollTransition`.
@immutable
class VisualEffectValues {
  /// Creates visual effect values. Every default is the identity.
  const VisualEffectValues({
    this.opacity = 1.0,
    this.offset = Offset.zero,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.rotationX = 0.0,
    this.rotationY = 0.0,
    this.blur = 0.0,
    this.saturation = 1.0,
    this.alignment,
    this.perspective,
  }) : assert(blur >= 0),
       assert(saturation >= 0);

  /// Values that leave the child unchanged.
  static const VisualEffectValues identity = VisualEffectValues();

  /// The default perspective depth used when [perspective] is null.
  static const double defaultPerspective = 0.0015;

  /// Opacity from 0 (invisible) to 1 (opaque). Values outside that range
  /// are clamped when painting.
  final double opacity;

  /// Translation in logical pixels, applied after scale and rotations.
  final Offset offset;

  /// Uniform scale factor around [alignment].
  final double scale;

  /// Rotation around the Z axis in radians (2D rotation), around
  /// [alignment].
  final double rotation;

  /// Rotation around the X axis in radians (3D tilt, top/bottom edge
  /// moving away).
  final double rotationX;

  /// Rotation around the Y axis in radians (3D tilt, left/right edge
  /// moving away).
  final double rotationY;

  /// Gaussian blur sigma in logical pixels.
  final double blur;

  /// Colour saturation: 1 is unchanged, 0 is greyscale, above 1 boosts it.
  final double saturation;

  /// Origin of scale and rotations. Null means [Alignment.center].
  final Alignment? alignment;

  /// Perspective depth for 3D rotations (the Matrix4 entry (3, 2)). Null
  /// means [defaultPerspective].
  final double? perspective;

  /// Whether these values leave the child untouched.
  bool get isIdentity =>
      opacity >= 1.0 && !hasTransform && blur <= 0 && saturation == 1.0;

  /// Whether a transform matrix is needed.
  bool get hasTransform =>
      offset != Offset.zero ||
      scale != 1.0 ||
      rotation != 0.0 ||
      rotationX != 0.0 ||
      rotationY != 0.0;

  /// Combines these values with [other], as if [other] were applied inside
  /// this effect. Opacities, scales and saturations multiply. Offsets and
  /// rotations add. Blur sigmas combine as `sqrt(a² + b²)`, which is exact
  /// for stacked Gaussian blurs. [other]'s alignment and perspective win
  /// when set.
  VisualEffectValues merge(VisualEffectValues other) {
    if (identical(other, identity)) return this;
    if (identical(this, identity)) return other;
    return VisualEffectValues(
      opacity: opacity * other.opacity,
      offset: offset + other.offset,
      scale: scale * other.scale,
      rotation: rotation + other.rotation,
      rotationX: rotationX + other.rotationX,
      rotationY: rotationY + other.rotationY,
      blur: math.sqrt(blur * blur + other.blur * other.blur),
      saturation: saturation * other.saturation,
      alignment: other.alignment ?? alignment,
      perspective: other.perspective ?? perspective,
    );
  }

  /// Returns a copy with the given fields replaced.
  VisualEffectValues copyWith({
    double? opacity,
    Offset? offset,
    double? scale,
    double? rotation,
    double? rotationX,
    double? rotationY,
    double? blur,
    double? saturation,
    Alignment? alignment,
    double? perspective,
  }) {
    return VisualEffectValues(
      opacity: opacity ?? this.opacity,
      offset: offset ?? this.offset,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      rotationX: rotationX ?? this.rotationX,
      rotationY: rotationY ?? this.rotationY,
      blur: blur ?? this.blur,
      saturation: saturation ?? this.saturation,
      alignment: alignment ?? this.alignment,
      perspective: perspective ?? this.perspective,
    );
  }

  /// The paint transform for a child of [size]:
  /// `translate(offset) · perspective · rotX · rotY · rotZ · scale`, taken
  /// around [alignment].
  Matrix4 transformFor(Size size) {
    final origin = (alignment ?? Alignment.center).alongSize(size);
    final matrix = Matrix4.identity()
      ..translateByDouble(offset.dx + origin.dx, offset.dy + origin.dy, 0, 1);
    if (rotationX != 0 || rotationY != 0) {
      matrix.multiply(
        Matrix4.identity()..setEntry(3, 2, perspective ?? defaultPerspective),
      );
      if (rotationX != 0) matrix.rotateX(rotationX);
      if (rotationY != 0) matrix.rotateY(rotationY);
    }
    if (rotation != 0) matrix.rotateZ(rotation);
    if (scale != 1.0) matrix.scaleByDouble(scale, scale, 1, 1);
    matrix.translateByDouble(-origin.dx, -origin.dy, 0, 1);
    return matrix;
  }

  /// A colour filter for [saturation], or null when it is 1. Uses Rec. 709
  /// luminance weights.
  ColorFilter? get saturationFilter {
    if (saturation == 1.0) return null;
    const r = 0.2126, g = 0.7152, b = 0.0722;
    final s = saturation;
    final inv = 1 - s;
    return ColorFilter.matrix(<double>[
      r * inv + s, g * inv, b * inv, 0, 0, //
      r * inv, g * inv + s, b * inv, 0, 0, //
      r * inv, g * inv, b * inv + s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// The blur image filter, or null when [blur] is 0.
  ui.ImageFilter? get blurFilter => blur > 0
      ? ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        )
      : null;

  @override
  bool operator ==(Object other) {
    return other is VisualEffectValues &&
        other.opacity == opacity &&
        other.offset == offset &&
        other.scale == scale &&
        other.rotation == rotation &&
        other.rotationX == rotationX &&
        other.rotationY == rotationY &&
        other.blur == blur &&
        other.saturation == saturation &&
        other.alignment == alignment &&
        other.perspective == perspective;
  }

  @override
  int get hashCode => Object.hash(
    opacity,
    offset,
    scale,
    rotation,
    rotationX,
    rotationY,
    blur,
    saturation,
    alignment,
    perspective,
  );

  @override
  String toString() =>
      'VisualEffectValues(opacity: $opacity, offset: $offset, scale: $scale, '
      'rotation: $rotation, rotationX: $rotationX, rotationY: $rotationY, '
      'blur: $blur, saturation: $saturation)';
}
