import 'package:flutter/widgets.dart';

import 'geometry.dart';
import 'geometry_host.dart';
import 'render_visual_effect.dart';

/// Builds a widget from the current [VisualEffectGeometry].
typedef VisualEffectWidgetBuilder =
    Widget Function(
      BuildContext context,
      Widget? child,
      VisualEffectGeometry geometry,
    );

/// Applies an arbitrary visual effect computed from the widget's geometry
/// in its scroll viewport, like SwiftUI's `.visualEffect`.
///
/// ```dart
/// VisualEffect(
///   // Shrink cards as they move away from the centre of a carousel.
///   effect: (g) => VisualEffectValues(
///     scale: 1 - 0.2 * g.centerOffset.abs().clamp(0.0, 1.0),
///   ),
///   child: card,
/// )
/// ```
///
/// * [effect] runs **at paint time** with the exact geometry of the
///   current frame. It never causes rebuilds.
/// * [builder] builds arbitrary widgets from the geometry. The geometry
///   changes on every scroll frame, so it rebuilds on every scroll frame.
///   Prefer [effect] where you can.
///
/// Outside a scrollable the geometry has
/// [VisualEffectGeometry.hasViewport] set to false, and the widget is its
/// own viewport.
class VisualEffect extends StatefulWidget {
  /// Creates a visual effect. At least one of [effect] and [builder] is
  /// required.
  const VisualEffect({super.key, this.effect, this.builder, this.child})
    : assert(
        effect != null || builder != null,
        'Provide an effect, a builder, or both.',
      );

  /// Paint-time effect.
  final VisualEffectCallback? effect;

  /// Optional geometry-driven builder.
  final VisualEffectWidgetBuilder? builder;

  /// The widget to affect. It is passed through [builder] without being
  /// rebuilt.
  final Widget? child;

  @override
  State<VisualEffect> createState() => _VisualEffectState();
}

class _VisualEffectState extends GeometryHostState<VisualEffect> {
  final ValueNotifier<VisualEffectGeometry> _geometry =
      ValueNotifier<VisualEffectGeometry>(
        VisualEffectGeometry.standalone(Size.zero),
      );
  VisualEffectGeometry? _pending;
  VisualEffectGeometry? _built;

  @override
  bool get wantsPrediction => widget.builder != null;

  @override
  void dispose() {
    _geometry.dispose();
    super.dispose();
  }

  @override
  bool handleGeometry(
    VisualEffectGeometry geometry, {
    required bool fromPaint,
  }) {
    if (widget.builder == null) return true;
    final current = _pending ?? _geometry.value;
    if (!geometry.closeTo(current)) {
      if (fromPaint) {
        _pending = geometry;
        scheduleFlush();
      } else {
        _pending = null;
        _geometry.value = geometry;
      }
    }
    if (fromPaint && !hasPainted) {
      final built = _built;
      if (built == null || !geometry.closeTo(built)) return false;
    }
    return true;
  }

  @override
  void flushPending() {
    final pending = _pending;
    _pending = null;
    if (pending != null) _geometry.value = pending;
  }

  @override
  Widget build(BuildContext context) {
    Widget? content = widget.child;
    final builder = widget.builder;
    if (builder != null) {
      content = ValueListenableBuilder<VisualEffectGeometry>(
        valueListenable: _geometry,
        builder: (context, geometry, child) {
          _built = geometry;
          return builder(context, child, geometry);
        },
        child: widget.child,
      );
    }
    return VisualEffectRenderWidget(
      position: position,
      repaint: widget.builder != null ? _geometry : null,
      axisDirection: axisDirection,
      textDirection: textDirection,
      effect: widget.effect,
      onPaintGeometry: onPaintGeometry,
      configuration: widget.effect,
      child: content,
    );
  }
}
