## 0.1.0

* Initial release.
* `ScrollTransition` gives each child a phase (-1..0..1) from its position
  in the nearest scroll viewport, with `topInset` / `bottomInset`.
* Interactive (continuous, optional curve) and animated (discrete, with
  duration, curve and threshold) configurations.
* Paint-time `effect:` with zero rebuilds: `ScrollEffects.fade`, `scale`,
  `rotate`, `rotate3D`, `blur`, `slide`, `translate`, `saturate`, `custom`,
  all chainable.
* `builder:` API that reruns only on phase changes and never rebuilds
  `child`.
* `VisualEffect` gets the raw viewport geometry, as a paint-time effect or
  a builder.
* Supports ListView, GridView, slivers (pinned headers), PageView,
  SingleChildScrollView, reversed, horizontal, RTL, keep-alive and nested
  scrollables.
