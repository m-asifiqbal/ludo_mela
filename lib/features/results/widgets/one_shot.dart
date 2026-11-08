// OneShot: an animation that plays once after a delay and hands its progress to a builder.
//
// Why: the Win board is built from one-off entrances that differ only in curve, delay and what
// they move (the headline slams in, avatars drop, podium blocks grow, cards rise). One widget
// serves them all. With Reduce Motion the builder is called with 1 straight away: nothing moves
// or waits.

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';

class OneShot extends StatefulWidget {
  const OneShot({
    super.key,
    required this.builder,
    this.delay = Duration.zero,
    this.duration = Motion.enter,
    this.curve = Motion.standardCurve,
    this.child,
  });

  /// Gets the curved progress: 0 before the delay is over, 1 at the end (springy curves may
  /// overshoot 1 on the way).
  final Widget Function(BuildContext context, double t, Widget? child) builder;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  /// Passed through to [builder] untouched, so it is not rebuilt every frame.
  final Widget? child;

  @override
  State<OneShot> createState() => _OneShotState();
}

class _OneShotState extends State<OneShot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    _c.duration = widget.delay + widget.duration;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.delay + widget.duration;
    final start = total.inMicroseconds == 0 ? 0.0 : widget.delay.inMicroseconds / total.inMicroseconds;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final raw = start >= 1 ? 1.0 : ((_c.value - start) / (1 - start)).clamp(0.0, 1.0);
        return widget.builder(context, widget.curve.transform(raw), child);
      },
    );
  }
}
