import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'geometry.dart';
import 'render_visual_effect.dart';

/// Shared machinery for widgets driven by their viewport geometry.
///
/// * Subscribes to the nearest [Scrollable]'s position.
/// * Receives the exact geometry from [RenderVisualEffect] on every paint
///   and caches it with the scroll offset it was measured at.
/// * When the scroll offset changes (before the next frame's build),
///   predicts the new geometry by shifting the cached rect by the
///   learned ratio of item movement to scroll delta. Builder-based
///   widgets can then rebuild in the same frame, and the next paint
///   corrects any error.
abstract class GeometryHostState<T extends StatefulWidget> extends State<T> {
  ScrollPosition? _position;
  AxisDirection _axisDirection = AxisDirection.down;
  TextDirection _textDirection = TextDirection.ltr;

  VisualEffectGeometry? _lastPainted;
  double? _lastPaintedPixels;
  double _movementRatio = 1.0;
  bool _hasPainted = false;
  bool _flushScheduled = false;

  /// The nearest scroll position, if any.
  ScrollPosition? get position => _position;

  /// Axis direction of the nearest scrollable.
  AxisDirection get axisDirection => _axisDirection;

  /// Ambient text direction.
  TextDirection get textDirection => _textDirection;

  /// Whether the render object has painted the child at least once.
  bool get hasPainted => _hasPainted;

  /// Whether scroll-time prediction is needed (for rebuild-driven or
  /// animated modes).
  bool get wantsPrediction;

  /// Handles a new geometry. [fromPaint] is true when called from the
  /// paint phase, so no state may change synchronously; use
  /// [scheduleFlush]. Returns whether the child should be painted this
  /// frame (only used when [fromPaint] is true).
  bool handleGeometry(VisualEffectGeometry geometry, {required bool fromPaint});

  /// Applies deferred updates after the current frame.
  void flushPending();

  /// Schedules [flushPending] after the current frame (coalesced).
  void scheduleFlush() {
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      if (mounted) flushPending();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Whether it is currently unsafe to change widget state synchronously
  /// (build, layout or paint in progress).
  bool get inFramePipeline =>
      SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.persistentCallbacks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollable = Scrollable.maybeOf(context);
    final newPosition = scrollable?.position;
    if (!identical(newPosition, _position)) {
      _position?.removeListener(_handleScroll);
      _position = newPosition;
      _position?.addListener(_handleScroll);
      _lastPainted = null;
      _lastPaintedPixels = null;
      _movementRatio = 1.0;
    }
    _axisDirection = scrollable?.axisDirection ?? AxisDirection.down;
    _textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
  }

  @override
  void dispose() {
    _position?.removeListener(_handleScroll);
    _position = null;
    super.dispose();
  }

  static double _physicalSign(AxisDirection direction) {
    switch (direction) {
      case AxisDirection.down:
      case AxisDirection.right:
        return -1.0;
      case AxisDirection.up:
      case AxisDirection.left:
        return 1.0;
    }
  }

  double _mainAxisPosition(VisualEffectGeometry g) =>
      g.axis == Axis.vertical ? g.rect.top : g.rect.left;

  void _handleScroll() {
    if (!wantsPrediction) return;
    final last = _lastPainted;
    final lastPixels = _lastPaintedPixels;
    final position = _position;
    if (last == null ||
        lastPixels == null ||
        position == null ||
        !position.hasPixels ||
        !last.hasViewport) {
      return;
    }
    final delta = position.pixels - lastPixels;
    final predicted = last.shiftedPhysical(
      _physicalSign(last.axisDirection) * delta * _movementRatio,
    );
    handleGeometry(predicted, fromPaint: inFramePipeline);
  }

  /// Paint-phase hook passed to [RenderVisualEffect.onPaintGeometry].
  bool onPaintGeometry(VisualEffectGeometry geometry) {
    final position = _position;
    final pixels = position != null && position.hasPixels
        ? position.pixels
        : null;
    final last = _lastPainted;
    final lastPixels = _lastPaintedPixels;
    if (last != null &&
        lastPixels != null &&
        pixels != null &&
        geometry.hasViewport &&
        last.hasViewport &&
        last.axisDirection == geometry.axisDirection &&
        last.viewportSize == geometry.viewportSize) {
      final delta = pixels - lastPixels;
      if (delta.abs() > 1e-6) {
        final expected = _physicalSign(geometry.axisDirection) * delta;
        final actual = _mainAxisPosition(geometry) - _mainAxisPosition(last);
        _movementRatio = (actual / expected).clamp(0.0, 2.0);
      }
    }
    _lastPainted = geometry;
    _lastPaintedPixels = pixels;
    final shouldPaint = handleGeometry(geometry, fromPaint: true);
    if (shouldPaint) _hasPainted = true;
    return shouldPaint;
  }
}
