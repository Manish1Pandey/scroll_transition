import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'effect_values.dart';
import 'effects.dart';
import 'geometry.dart';
import 'geometry_host.dart';
import 'phase.dart';
import 'render_visual_effect.dart';

/// Builds a widget from the current [ScrollTransitionPhase].
///
/// [child] is the `child` passed to [ScrollTransition]. It is never
/// rebuilt by the transition, so put expensive subtrees there.
typedef ScrollTransitionWidgetBuilder =
    Widget Function(
      BuildContext context,
      Widget? child,
      ScrollTransitionPhase phase,
    );

/// Animates [child] from its position inside the nearest scroll viewport,
/// like SwiftUI's `.scrollTransition`.
///
/// ```dart
/// ListView.builder(
///   itemBuilder: (context, i) => ScrollTransition(
///     effect: ScrollEffects.fade().scale(0.8),
///     child: Card(child: ListTile(title: Text('Item $i'))),
///   ),
/// )
/// ```
///
/// There are two ways to react to the phase, and you can use both at
/// once:
///
/// * [effect]: a [ScrollEffect] resolved and applied **at paint time**
///   from the exact geometry of the current frame. Nothing is rebuilt
///   while scrolling. Prefer this one.
/// * [builder]: builds arbitrary widgets from the phase. It reruns only
///   when the phase changes, and [child] is passed through untouched.
///
/// The phase is measured against the nearest [Scrollable] (ListView,
/// GridView, CustomScrollView, PageView, SingleChildScrollView), in any
/// direction, reversed or not. Outside a scrollable the phase is always
/// [ScrollTransitionPhase.identity].
class ScrollTransition extends StatefulWidget {
  /// Creates a scroll transition. At least one of [effect] and [builder]
  /// is required.
  const ScrollTransition({
    super.key,
    this.effect,
    this.builder,
    this.configuration = const ScrollTransitionConfiguration.interactive(),
    this.topInset = 0,
    this.bottomInset = 0,
    this.child,
  }) : assert(
         effect != null || builder != null,
         'Provide an effect, a builder, or both.',
       ),
       assert(topInset >= 0 && bottomInset >= 0);

  /// Paint-time effect, applied without rebuilding.
  final ScrollEffect? effect;

  /// Optional builder, called when the phase changes.
  final ScrollTransitionWidgetBuilder? builder;

  /// Interactive (continuous) or animated (discrete) phase.
  final ScrollTransitionConfiguration configuration;

  /// Distance from the top (vertical) or leading (horizontal) edge of the
  /// viewport where the transition region starts. For example, the height
  /// of a pinned header.
  final double topInset;

  /// Distance from the bottom/trailing edge of the viewport where the
  /// transition region ends.
  final double bottomInset;

  /// The widget to transform.
  final Widget? child;

  @override
  State<ScrollTransition> createState() => _ScrollTransitionState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<ScrollEffect>('effect', effect))
      ..add(
        DiagnosticsProperty<ScrollTransitionConfiguration>(
          'configuration',
          configuration,
        ),
      )
      ..add(DoubleProperty('topInset', topInset, defaultValue: 0))
      ..add(DoubleProperty('bottomInset', bottomInset, defaultValue: 0));
  }
}

@immutable
class _EffectConfigKey {
  const _EffectConfigKey(
    this.effect,
    this.configuration,
    this.top,
    this.bottom,
  );
  final ScrollEffect? effect;
  final ScrollTransitionConfiguration configuration;
  final double top;
  final double bottom;

  @override
  bool operator ==(Object other) =>
      other is _EffectConfigKey &&
      other.effect == effect &&
      other.configuration == configuration &&
      other.top == top &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(effect, configuration, top, bottom);
}

class _ScrollTransitionState extends GeometryHostState<ScrollTransition>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _animationInitialized = false;
  ScrollTransitionPhase? _target;
  ScrollTransitionPhase? _pendingTarget;

  final ValueNotifier<ScrollTransitionPhase> _phase =
      ValueNotifier<ScrollTransitionPhase>(ScrollTransitionPhase.identity);
  ScrollTransitionPhase? _pendingPhase;
  ScrollTransitionPhase _builtPhase = ScrollTransitionPhase.identity;

  bool get _animated => widget.configuration.isAnimated;

  @override
  bool get wantsPrediction => widget.builder != null || _animated;

  @override
  void initState() {
    super.initState();
    _syncController();
  }

  @override
  void didUpdateWidget(ScrollTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.configuration != widget.configuration ||
        oldWidget.topInset != widget.topInset ||
        oldWidget.bottomInset != widget.bottomInset) {
      _syncController();
      _target = null;
      _pendingTarget = null;
      _pendingPhase = null;
    }
  }

  void _syncController() {
    if (_animated) {
      _controller ??= AnimationController(
        vsync: this,
        lowerBound: -1,
        upperBound: 1,
        value: 0,
      );
      _animationInitialized = false;
    } else {
      _controller?.dispose();
      _controller = null;
    }
    _repaint = _controller == null
        ? _phase
        : Listenable.merge(<Listenable>[_controller!, _phase]);
  }

  // Repaints the render object when the animation ticks or the builder
  // phase changes. That covers a first frame skipped in builder mode
  // whose rebuilt output is identical.
  late Listenable _repaint;

  @override
  void dispose() {
    _controller?.dispose();
    _phase.dispose();
    super.dispose();
  }

  ScrollTransitionPhase _continuous(VisualEffectGeometry geometry) {
    return ScrollTransitionPhase.fromGeometry(
      geometry,
      topInset: widget.topInset,
      bottomInset: widget.bottomInset,
    ).curved(widget.configuration.curve);
  }

  ScrollTransitionPhase _discrete(VisualEffectGeometry geometry) {
    return ScrollTransitionPhase.discreteFromGeometry(
      geometry,
      topInset: widget.topInset,
      bottomInset: widget.bottomInset,
      threshold: widget.configuration.threshold,
    );
  }

  /// The phase that should be displayed for [geometry] right now.
  ScrollTransitionPhase _displayPhase(VisualEffectGeometry geometry) {
    if (!_animated) return _continuous(geometry);
    if (!_animationInitialized) return _target ?? _discrete(geometry);
    return ScrollTransitionPhase(_controller!.value);
  }

  VisualEffectValues _resolveEffect(VisualEffectGeometry geometry) {
    return widget.effect!.resolve(
      _displayPhase(geometry),
      axis: geometry.axis,
      textDirection: geometry.textDirection,
    );
  }

  void _applyTarget(ScrollTransitionPhase target) {
    final controller = _controller;
    if (controller == null) return;
    if (!_animationInitialized) {
      _animationInitialized = true;
      controller.value = target.value;
      return;
    }
    if (controller.value == target.value && !controller.isAnimating) return;
    final config = widget.configuration;
    if (config.duration == Duration.zero) {
      controller.value = target.value;
    } else {
      controller.animateTo(
        target.value,
        duration: config.duration,
        curve: config.curve,
      );
    }
  }

  @override
  bool handleGeometry(
    VisualEffectGeometry geometry, {
    required bool fromPaint,
  }) {
    var shouldPaint = true;
    if (_animated) {
      final target = _discrete(geometry);
      if (target != _target) {
        _target = target;
        if (fromPaint) {
          _pendingTarget = target;
          scheduleFlush();
        } else {
          _pendingTarget = null;
          _applyTarget(target);
        }
      }
      if (fromPaint && widget.builder != null && !hasPainted) {
        final desired = _animationInitialized
            ? ScrollTransitionPhase(_controller!.value)
            : target;
        if (!desired.closeTo(_builtPhase)) shouldPaint = false;
      }
    } else if (widget.builder != null) {
      final phase = _continuous(geometry);
      final current = _pendingPhase ?? _phase.value;
      if (!phase.closeTo(current)) {
        if (fromPaint) {
          _pendingPhase = phase;
          scheduleFlush();
        } else {
          _pendingPhase = null;
          _phase.value = phase;
        }
      }
      if (fromPaint && !hasPainted && !phase.closeTo(_builtPhase)) {
        shouldPaint = false;
      }
    }
    return shouldPaint;
  }

  @override
  void flushPending() {
    final target = _pendingTarget;
    _pendingTarget = null;
    if (target != null) _applyTarget(target);
    final phase = _pendingPhase;
    _pendingPhase = null;
    if (phase != null) _phase.value = phase;
  }

  Widget _callBuilder(
    BuildContext context,
    ScrollTransitionPhase phase,
    Widget? child,
  ) {
    _builtPhase = phase;
    return widget.builder!(context, child, phase);
  }

  @override
  Widget build(BuildContext context) {
    Widget? content = widget.child;
    if (widget.builder != null) {
      if (_animated) {
        content = AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) => _callBuilder(
            context,
            ScrollTransitionPhase(_controller!.value),
            child,
          ),
          child: widget.child,
        );
      } else {
        content = ValueListenableBuilder<ScrollTransitionPhase>(
          valueListenable: _phase,
          builder: (context, phase, child) =>
              _callBuilder(context, phase, child),
          child: widget.child,
        );
      }
    }
    return VisualEffectRenderWidget(
      position: position,
      repaint: _repaint,
      axisDirection: axisDirection,
      textDirection: textDirection,
      effect: widget.effect != null ? _resolveEffect : null,
      onPaintGeometry: onPaintGeometry,
      configuration: _EffectConfigKey(
        widget.effect,
        widget.configuration,
        widget.topInset,
        widget.bottomInset,
      ),
      child: content,
    );
  }
}
