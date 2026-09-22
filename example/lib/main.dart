import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:scroll_transition/scroll_transition.dart';

void main() => runApp(const ScrollTransitionExampleApp());

/// The example app: a catalogue of demos, one per feature.
class ScrollTransitionExampleApp extends StatelessWidget {
  /// Creates the app.
  const ScrollTransitionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'scroll_transition',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const DemoCatalogue(),
    );
  }
}

class _Demo {
  const _Demo(this.title, this.subtitle, this.builder);
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

final List<_Demo> _demos = <_Demo>[
  _Demo(
    'Fade + scale',
    'ScrollEffects.fade().scale(0.8) on a ListView',
    (_) => const FadeScaleDemo(),
  ),
  _Demo('3D drum', 'rotate3D + fade, vertical list', (_) => const DrumDemo()),
  _Demo(
    'Blur + desaturate grid',
    'GridView with blur(6).saturate(0)',
    (_) => const BlurGridDemo(),
  ),
  _Demo(
    'Carousel (VisualEffect)',
    'Horizontal, geometry-driven scale/tilt, LTR/RTL toggle',
    (_) => const CarouselDemo(),
  ),
  _Demo(
    'PageView',
    'rotate + scale + fade between pages',
    (_) => const PageViewDemo(),
  ),
  _Demo(
    'Reversed chat',
    'reverse: true with slide + fade',
    (_) => const ReversedChatDemo(),
  ),
  _Demo(
    'Animated configuration',
    'Discrete phases animated with duration/curve/threshold',
    (_) => const AnimatedConfigDemo(),
  ),
  _Demo(
    'Builder mode',
    'Arbitrary widgets from the phase; child never rebuilt',
    (_) => const BuilderDemo(),
  ),
  _Demo(
    'Pinned header + topInset',
    'CustomScrollView slivers, items fade under the header',
    (_) => const PinnedHeaderDemo(),
  ),
  _Demo(
    'Nested + keep-alive',
    'Horizontal rows inside a vertical list, state kept alive',
    (_) => const NestedDemo(),
  ),
  _Demo(
    'Live geometry',
    'VisualEffect builder showing rect, phase, centerOffset',
    (_) => const GeometryDemo(),
  ),
];

/// Lists every demo, itself animated with a scroll transition.
class DemoCatalogue extends StatelessWidget {
  /// Creates the catalogue.
  const DemoCatalogue({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('scroll_transition demos')),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _demos.length,
        itemBuilder: (context, i) {
          final demo = _demos[i];
          return ScrollTransition(
            effect: ScrollEffects.fade(0.2).scale(0.9),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                title: Text(demo.title),
                subtitle: Text(demo.subtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: Text(demo.title)),
                      body: demo.builder(context),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Color _colorFor(int i) =>
    HSLColor.fromAHSL(1, (i * 37) % 360.0, 0.6, 0.55).toColor();

class _ColorTile extends StatelessWidget {
  const _ColorTile({required this.index, this.height = 96});
  final int index;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _colorFor(index),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        'Item $index',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// fade().scale(0.8) on a plain ListView.
class FadeScaleDemo extends StatelessWidget {
  /// Creates the demo.
  const FadeScaleDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 60,
      itemBuilder: (context, i) => ScrollTransition(
        effect: ScrollEffects.fade().scale(0.8),
        child: _ColorTile(index: i),
      ),
    );
  }
}

/// A 3D drum: items tilt away as they reach the edges.
class DrumDemo extends StatelessWidget {
  /// Creates the demo.
  const DrumDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 60,
      itemBuilder: (context, i) => ScrollTransition(
        topInset: 80,
        bottomInset: 80,
        effect: ScrollEffects.rotate3D(angle: math.pi / 3).fade(0.3),
        child: _ColorTile(index: i, height: 80),
      ),
    );
  }
}

/// Blur and desaturate cells near the edges of a grid.
class BlurGridDemo extends StatelessWidget {
  /// Creates the demo.
  const BlurGridDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: 120,
      itemBuilder: (context, i) => ScrollTransition(
        topInset: 40,
        bottomInset: 40,
        effect: ScrollEffects.blur(6).saturate(0).scale(0.9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _colorFor(i),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              '$i',
              style: const TextStyle(color: Colors.white, fontSize: 28),
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal carousel driven by [VisualEffect] geometry, with an RTL
/// toggle.
class CarouselDemo extends StatefulWidget {
  /// Creates the demo.
  const CarouselDemo({super.key});

  @override
  State<CarouselDemo> createState() => _CarouselDemoState();
}

class _CarouselDemoState extends State<CarouselDemo> {
  bool _rtl = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Right-to-left'),
          subtitle: const Text('Leading edge flips to the right'),
          value: _rtl,
          onChanged: (v) => setState(() => _rtl = v),
        ),
        SizedBox(
          height: 260,
          child: Directionality(
            textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 30,
              itemBuilder: (context, i) => VisualEffect(
                effect: (g) {
                  final d = g.centerOffset.clamp(-1.0, 1.0);
                  final sign = g.textDirection == TextDirection.rtl ? -1 : 1;
                  return VisualEffectValues(
                    scale: 1 - 0.25 * d.abs(),
                    rotationY: -0.6 * d * sign,
                    opacity: 1 - 0.5 * d.abs(),
                  );
                },
                child: Container(
                  width: 180,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _colorFor(i),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Card $i',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'VisualEffect(effect: (geometry) => ...) runs at paint time. '
            'geometry.centerOffset is -1..1 from the viewport centre.',
          ),
        ),
      ],
    );
  }
}

/// Pages rotate and shrink as they are swiped away.
class PageViewDemo extends StatelessWidget {
  /// Creates the demo.
  const PageViewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      itemCount: 10,
      itemBuilder: (context, i) => ScrollTransition(
        effect: ScrollEffects.rotate(math.pi / 10).scale(0.7).fade(0.4),
        child: Container(
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _colorFor(i * 3),
            borderRadius: BorderRadius.circular(32),
          ),
          alignment: Alignment.center,
          child: Text(
            'Page $i',
            style: const TextStyle(color: Colors.white, fontSize: 40),
          ),
        ),
      ),
    );
  }
}

/// A reversed (chat-style) list: the newest message sits at the bottom.
class ReversedChatDemo extends StatelessWidget {
  /// Creates the demo.
  const ReversedChatDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      reverse: true,
      itemCount: 80,
      itemBuilder: (context, i) {
        final mine = i.isEven;
        return ScrollTransition(
          effect: ScrollEffects.slide(24).fade(),
          child: Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: mine ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Message #$i',
                style: TextStyle(
                  color: mine ? scheme.onPrimary : scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The animated configuration: items pop in once half-visible.
class AnimatedConfigDemo extends StatefulWidget {
  /// Creates the demo.
  const AnimatedConfigDemo({super.key});

  @override
  State<AnimatedConfigDemo> createState() => _AnimatedConfigDemoState();
}

class _AnimatedConfigDemoState extends State<AnimatedConfigDemo> {
  double _threshold = 0.5;
  bool _animated = true;

  @override
  Widget build(BuildContext context) {
    final config = _animated
        ? ScrollTransitionConfiguration.animated(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutBack,
            threshold: _threshold,
          )
        : const ScrollTransitionConfiguration.interactive();
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Animated configuration'),
          value: _animated,
          onChanged: (v) => setState(() => _animated = v),
        ),
        ListTile(
          title: Text('Threshold ${(_threshold * 100).round()}% visible'),
          subtitle: Slider(
            value: _threshold,
            onChanged: _animated ? (v) => setState(() => _threshold = v) : null,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: 60,
            itemBuilder: (context, i) => ScrollTransition(
              configuration: config,
              effect: ScrollEffects.fade().scale(0.6).slide(40),
              child: _ColorTile(index: i),
            ),
          ),
        ),
      ],
    );
  }
}

/// builder: arbitrary widgets from the phase.
class BuilderDemo extends StatelessWidget {
  /// Creates the demo.
  const BuilderDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 60,
      itemBuilder: (context, i) => ScrollTransition(
        builder: (context, child, phase) {
          final label = switch (phase.kind) {
            ScrollPhase.topLeading => 'leaving top',
            ScrollPhase.identity => 'fully visible',
            ScrollPhase.bottomTrailing => 'entering bottom',
          };
          return Stack(
            children: [
              child!,
              Positioned(
                right: 28,
                top: 14,
                child: Chip(
                  label: Text('$label  ${phase.value.toStringAsFixed(2)}'),
                ),
              ),
            ],
          );
        },
        child: _ColorTile(index: i),
      ),
    );
  }
}

/// Slivers with a pinned header. List items fade as they slide under it.
class PinnedHeaderDemo extends StatelessWidget {
  /// Creates the demo.
  const PinnedHeaderDemo({super.key});

  static const double _headerExtent = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedHeader(
            extent: _headerExtent,
            child: ScrollTransition(
              // The header stays pinned, so its phase stays identity.
              effect: ScrollEffects.fade(),
              child: Container(
                color: scheme.primaryContainer,
                alignment: Alignment.center,
                child: Text(
                  'Pinned header',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
        SliverList.builder(
          itemCount: 50,
          itemBuilder: (context, i) => ScrollTransition(
            topInset: _headerExtent,
            effect: ScrollEffects.fade().scale(0.9),
            child: _ColorTile(index: i),
          ),
        ),
      ],
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  _PinnedHeader({required this.extent, required this.child});
  final double extent;
  final Widget child;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(_PinnedHeader oldDelegate) =>
      oldDelegate.extent != extent || oldDelegate.child != child;
}

/// Horizontal rows inside a vertical list. Each card keeps its counter
/// alive when scrolled away.
class NestedDemo extends StatelessWidget {
  /// Creates the demo.
  const NestedDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 20,
      itemBuilder: (context, row) => ScrollTransition(
        effect: ScrollEffects.fade(0.3),
        child: SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 20,
            itemBuilder: (context, col) => ScrollTransition(
              effect: ScrollEffects.scale(0.7).rotate3D(angle: 0.8),
              child: _CounterCard(index: row * 20 + col),
            ),
          ),
        ),
      ),
    );
  }
}

class _CounterCard extends StatefulWidget {
  const _CounterCard({required this.index});
  final int index;

  @override
  State<_CounterCard> createState() => _CounterCardState();
}

class _CounterCardState extends State<_CounterCard>
    with AutomaticKeepAliveClientMixin {
  int _taps = 0;

  @override
  bool get wantKeepAlive => _taps > 0;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: () {
        setState(() => _taps++);
        updateKeepAlive();
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _colorFor(widget.index),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          _taps == 0 ? 'Tap me' : 'Taps: $_taps\n(kept alive)',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }
}

/// VisualEffect's builder shows the live geometry.
class GeometryDemo extends StatelessWidget {
  /// Creates the demo.
  const GeometryDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 40,
      itemBuilder: (context, i) => VisualEffect(
        builder: (context, child, g) {
          final phase = g.phase();
          return Container(
            height: 110,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color.lerp(
                _colorFor(i),
                Colors.black,
                phase.magnitude * 0.7,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Item $i',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'top ${g.rect.top.toStringAsFixed(1)}  '
                    'viewport ${g.viewportSize.height.toStringAsFixed(0)}',
                  ),
                  Text(
                    'phase ${phase.value.toStringAsFixed(2)} (${phase.kind.name})',
                  ),
                  Text(
                    'centerOffset ${g.centerOffset.toStringAsFixed(2)}  '
                    'visible ${(g.visibleFraction * 100).round()}%',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
