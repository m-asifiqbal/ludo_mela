// EnterFrom: a child that comes in from the side (or from big and tilted) after a delay — the Mela
// Tour cards sliding in from the right, the VS players flying in from both edges, the VS slam.
//
// The kit's Entrance only rises 18 pt; the setup boards also slide 30 – 180 pt sideways, turn
// ±10° and start at 3× size (`lmInL`, `lmInR`, `lmRise`, `lmSlam`). Like CSS `animation: … backwards`
// the child stays invisible during the delay. The curve is applied over the whole move, so the pop
// curve overshoots and settles. Reduce Motion: no travel and no delay, only a short fade.

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';

class EnterFrom extends StatefulWidget {
  const EnterFrom({
    super.key,
    required this.child,
    this.offset = Offset.zero,
    this.angle = 0,
    this.scale = 1,
    this.delay = Duration.zero,
    this.duration = Motion.enter,
    this.curve = Motion.standardCurve,
  });

  final Widget child;

  /// Where it starts, relative to where it ends (pt).
  final Offset offset;

  /// The tilt it starts with (radians).
  final double angle;

  /// The size it starts with (1 = none).
  final double scale;
  final Duration delay;
  final Duration duration;
  final Curve curve;

  @override
  State<EnterFrom> createState() => _EnterFromState();
}

class _EnterFromState extends State<EnterFrom> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _c.duration = Motion.reduced(context) ? const Duration(milliseconds: 120) : widget.delay + widget.duration;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = Motion.reduced(context);
    final total = (_c.duration ?? widget.duration).inMicroseconds.toDouble();
    final start = reduced || total == 0 ? 0.0 : (widget.delay.inMicroseconds / total).clamp(0.0, .99);
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final raw = ((_c.value - start) / (1 - start)).clamp(0.0, 1.0);
        if (reduced) return Opacity(opacity: raw, child: child);
        final t = widget.curve.transform(raw);
        final left = 1 - t;
        Widget moved = child!;
        if (widget.scale != 1) moved = Transform.scale(scale: 1 + (widget.scale - 1) * left, child: moved);
        if (widget.angle != 0) moved = Transform.rotate(angle: widget.angle * left, child: moved);
        if (widget.offset != Offset.zero) moved = Transform.translate(offset: widget.offset * left, child: moved);
        return Opacity(opacity: t.clamp(0.0, 1.0), child: moved);
      },
    );
  }
}
