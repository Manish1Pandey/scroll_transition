/// SwiftUI-style scroll transitions and visual effects for Flutter.
///
/// * [ScrollTransition]: fade, scale, rotate, blur or slide children from
///   their phase in the nearest scroll viewport.
/// * [VisualEffect]: arbitrary paint-time effects from a child's
///   viewport geometry.
/// * [ScrollEffects]: composable ready-made effects.
library;

export 'src/effect_values.dart';
export 'src/effects.dart';
export 'src/geometry.dart';
export 'src/phase.dart';
export 'src/render_visual_effect.dart'
    show RenderVisualEffect, VisualEffectCallback, PaintGeometryCallback;
export 'src/scroll_transition.dart';
export 'src/visual_effect.dart';
