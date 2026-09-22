import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'effect_values.dart';
import 'geometry.dart';

/// Computes paint-time [VisualEffectValues] from the current geometry.
typedef VisualEffectCallback =
    VisualEffectValues Function(VisualEffectGeometry geometry);

/// Called during paint with the measured geometry. Returns whether the
/// child should be painted this frame.
typedef PaintGeometryCallback = bool Function(VisualEffectGeometry geometry);

/// The render widget shared by `ScrollTransition` and `VisualEffect`.
class VisualEffectRenderWidget extends SingleChildRenderObjectWidget {
  /// Creates the render widget.
  const VisualEffectRenderWidget({
    super.key,
    required this.position,
    required this.repaint,
    required this.axisDirection,
    required this.textDirection,
    required this.effect,
    required this.onPaintGeometry,
    required this.configuration,
    super.child,
  });

  /// The scroll position to listen to, or null outside a scrollable.
  final Listenable? position;

  /// Another listenable that triggers repaints (for example an animation).
  final Listenable? repaint;

  /// Axis direction of the nearest scrollable.
  final AxisDirection axisDirection;

  /// Ambient text direction.
  final TextDirection textDirection;

  /// Paint-time effect, or null for none.
  final VisualEffectCallback? effect;

  /// Geometry report hook.
  final PaintGeometryCallback? onPaintGeometry;

  /// Any object whose change must trigger a repaint (the widget's effect
  /// configuration).
  final Object? configuration;

  @override
  RenderVisualEffect createRenderObject(BuildContext context) {
    return RenderVisualEffect(
      position: position,
      repaint: repaint,
      axisDirection: axisDirection,
      textDirection: textDirection,
      effect: effect,
      onPaintGeometry: onPaintGeometry,
      configuration: configuration,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderVisualEffect renderObject,
  ) {
    renderObject
      ..position = position
      ..repaint = repaint
      ..axisDirection = axisDirection
      ..textDirection = textDirection
      ..effect = effect
      ..onPaintGeometry = onPaintGeometry
      ..configuration = configuration;
  }
}

/// Measures its own rect relative to the nearest viewport on every paint,
/// then paints its child through transform, opacity, colour-filter and
/// image-filter layers computed from that geometry.
///
/// It repaints whenever [position] or [repaint] notifies. It never
/// triggers a rebuild and never changes layout.
class RenderVisualEffect extends RenderProxyBox {
  /// Creates the render object.
  RenderVisualEffect({
    Listenable? position,
    Listenable? repaint,
    AxisDirection axisDirection = AxisDirection.down,
    TextDirection textDirection = TextDirection.ltr,
    VisualEffectCallback? effect,
    PaintGeometryCallback? onPaintGeometry,
    Object? configuration,
    RenderBox? child,
  }) : _position = position,
       _repaint = repaint,
       _axisDirection = axisDirection,
       _textDirection = textDirection,
       _effect = effect,
       _onPaintGeometry = onPaintGeometry,
       _configuration = configuration,
       super(child);

  /// The scroll position this object listens to.
  Listenable? get position => _position;
  Listenable? _position;
  set position(Listenable? value) {
    if (identical(value, _position)) return;
    if (attached) {
      _position?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _position = value;
    markNeedsPaint();
  }

  /// An extra listenable that triggers repaints.
  Listenable? get repaint => _repaint;
  Listenable? _repaint;
  set repaint(Listenable? value) {
    if (identical(value, _repaint)) return;
    if (attached) {
      _repaint?.removeListener(markNeedsPaint);
      value?.addListener(markNeedsPaint);
    }
    _repaint = value;
    markNeedsPaint();
  }

  /// Axis direction of the nearest scrollable.
  AxisDirection get axisDirection => _axisDirection;
  AxisDirection _axisDirection;
  set axisDirection(AxisDirection value) {
    if (value == _axisDirection) return;
    _axisDirection = value;
    markNeedsPaint();
  }

  /// Ambient text direction.
  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (value == _textDirection) return;
    _textDirection = value;
    markNeedsPaint();
  }

  /// Paint-time effect callback.
  VisualEffectCallback? get effect => _effect;
  VisualEffectCallback? _effect;
  set effect(VisualEffectCallback? value) {
    if (value == _effect) return;
    final compositingChanged = (value == null) != (_effect == null);
    _effect = value;
    if (compositingChanged) markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  /// Geometry report hook.
  PaintGeometryCallback? get onPaintGeometry => _onPaintGeometry;
  PaintGeometryCallback? _onPaintGeometry;
  set onPaintGeometry(PaintGeometryCallback? value) {
    if (value == _onPaintGeometry) return;
    _onPaintGeometry = value;
    markNeedsPaint();
  }

  /// Opaque configuration token. A change triggers a repaint.
  Object? get configuration => _configuration;
  Object? _configuration;
  set configuration(Object? value) {
    if (value == _configuration) return;
    _configuration = value;
    markNeedsPaint();
  }

  /// The geometry measured during the last paint, or null if not painted
  /// yet.
  VisualEffectGeometry? get lastGeometry => _lastGeometry;
  VisualEffectGeometry? _lastGeometry;

  /// The effect values applied during the last paint, or null when the
  /// child was painted unmodified or not painted.
  VisualEffectValues? get lastValues => _lastValues;
  VisualEffectValues? _lastValues;

  Matrix4? _paintTransform;
  final LayerHandle<OpacityLayer> _opacityLayer = LayerHandle<OpacityLayer>();
  final LayerHandle<ColorFilterLayer> _colorFilterLayer =
      LayerHandle<ColorFilterLayer>();
  final LayerHandle<ImageFilterLayer> _imageFilterLayer =
      LayerHandle<ImageFilterLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position?.addListener(markNeedsPaint);
    _repaint?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _position?.removeListener(markNeedsPaint);
    _repaint?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _clearLayers();
    super.dispose();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _effect != null;

  /// Measures this box against the nearest [RenderAbstractViewport].
  VisualEffectGeometry measureGeometry() {
    if (_position == null) {
      return VisualEffectGeometry.standalone(
        size,
        textDirection: _textDirection,
      );
    }
    final viewport = RenderAbstractViewport.maybeOf(this);
    if (viewport is! RenderBox || !(viewport as RenderBox).hasSize) {
      return VisualEffectGeometry.standalone(
        size,
        textDirection: _textDirection,
      );
    }
    final viewportBox = viewport as RenderBox;
    final transform = getTransformTo(viewportBox);
    final rect = MatrixUtils.transformRect(transform, Offset.zero & size);
    return VisualEffectGeometry(
      rect: rect,
      viewportSize: viewportBox.size,
      axisDirection: _axisDirection,
      textDirection: _textDirection,
    );
  }

  void _clearLayers() {
    _opacityLayer.layer = null;
    _colorFilterLayer.layer = null;
    _imageFilterLayer.layer = null;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) {
      _clearLayers();
      return;
    }
    final geometry = measureGeometry();
    _lastGeometry = geometry;
    final shouldPaint = _onPaintGeometry?.call(geometry) ?? true;
    final values = _effect?.call(geometry);
    _paintTransform = values != null && values.hasTransform
        ? values.transformFor(size)
        : null;
    if (!shouldPaint) {
      _lastValues = null;
      _clearLayers();
      layer = null;
      return;
    }
    if (values == null || values.isIdentity) {
      _lastValues = null;
      _clearLayers();
      layer = null;
      context.paintChild(child, offset);
      return;
    }
    _lastValues = values;
    final opacity = values.opacity.clamp(0.0, 1.0);
    if (opacity <= 0) {
      _clearLayers();
      layer = null;
      return;
    }

    void paintFiltered(PaintingContext context, Offset offset) {
      final blur = values.blurFilter;
      if (blur == null) {
        _imageFilterLayer.layer = null;
        context.paintChild(child, offset);
        return;
      }
      final filterLayer = _imageFilterLayer.layer ??= ImageFilterLayer();
      filterLayer.imageFilter = blur;
      context.pushLayer(
        filterLayer,
        (context, offset) => context.paintChild(child, offset),
        offset,
      );
    }

    void paintColored(PaintingContext context, Offset offset) {
      final colorFilter = values.saturationFilter;
      if (colorFilter == null) {
        _colorFilterLayer.layer = null;
        paintFiltered(context, offset);
        return;
      }
      _colorFilterLayer.layer = context.pushColorFilter(
        offset,
        colorFilter,
        paintFiltered,
        oldLayer: _colorFilterLayer.layer,
      );
    }

    void paintFaded(PaintingContext context, Offset offset) {
      if (opacity >= 1.0) {
        _opacityLayer.layer = null;
        paintColored(context, offset);
        return;
      }
      _opacityLayer.layer = context.pushOpacity(
        offset,
        Color.getAlphaFromOpacity(opacity),
        paintColored,
        oldLayer: _opacityLayer.layer,
      );
    }

    final transform = _paintTransform;
    if (transform == null) {
      layer = null;
      paintFaded(context, offset);
    } else {
      layer = context.pushTransform(
        needsCompositing,
        offset,
        transform,
        paintFaded,
        oldLayer: layer is TransformLayer ? layer! as TransformLayer : null,
      );
    }
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final paintTransform = _paintTransform;
    if (paintTransform != null) transform.multiply(paintTransform);
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_paintTransform == null) {
      return super.hitTest(result, position: position);
    }
    // Like RenderTransform: the transformed child may be painted outside
    // this box's own bounds, so skip the bounds check.
    return hitTestChildren(result, position: position);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final paintTransform = _paintTransform;
    if (paintTransform == null) {
      return super.hitTestChildren(result, position: position);
    }
    return result.addWithPaintTransform(
      transform: paintTransform,
      position: position,
      hitTest: (result, position) =>
          super.hitTestChildren(result, position: position),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(EnumProperty<AxisDirection>('axisDirection', _axisDirection))
      ..add(EnumProperty<TextDirection>('textDirection', _textDirection))
      ..add(
        DiagnosticsProperty<VisualEffectGeometry>('geometry', _lastGeometry),
      )
      ..add(DiagnosticsProperty<VisualEffectValues>('values', _lastValues));
  }
}
