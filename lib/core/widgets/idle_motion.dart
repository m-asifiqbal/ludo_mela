// IdleMotion: the small looping motions that make lobby tiles feel alive —
// the wheel spinning, the gift wiggling, a tile floating, a ready pot shaking.
//
// Loops from the artboards: spin 26 s linear; wiggle 2.6 s (still for 80 %, then
// −10° / +8° / −4°); float 2.8 s (4 pt up and down, ease in-out); shake 2.2 s
// (−7° / +6° / −3° from the base); bob 0.9 s (4 pt). "Idle loops pause when
// off-screen" (TickerMode does that) and stop with Reduce Motion.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';

enum IdleKind {
  none(Duration.zero),
  spin(Duration(seconds: 26)),
  wiggle(Duration(milliseconds: 2600)),
  float(Duration(milliseconds: 2800)),
  shake(Duration(milliseconds: 2200)),
  bob(Duration(milliseconds: 900));

  const IdleKind(this.period);

  /// One loop.
  final Duration period;
}

class IdleMotion extends StatefulWidget {
  const IdleMotion({super.key, required this.kind, required this.child, this.delay = Duration.zero});

  final IdleKind kind;
  final Widget child;

  /// Offsets the loop so neighbours do not move in unison.
  final Duration delay;

  @override
  State<IdleMotion> createState() => _IdleMotionState();
}

class _IdleMotionState extends State<IdleMotion> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(IdleMotion old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.kind != IdleKind.none && !Motion.reduced(context);
    if (run) {
      _c.duration = widget.kind.period;
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double p, double a, double b, double from, double to) => from + (to - from) * Curves.ease.transform(((p - a) / (b - a)).clamp(0.0, 1.0));

  /// The wiggle angle (degrees) at loop position [p].
  static double wiggleAngle(double p) {
    if (p < .8) return 0;
    if (p < .85) return _seg(p, .8, .85, 0, -10);
    if (p < .9) return _seg(p, .85, .9, -10, 8);
    if (p < .95) return _seg(p, .9, .95, 8, -4);
    return _seg(p, .95, 1, -4, 0);
  }

  /// The shake angle (degrees) at loop position [p].
  static double shakeAngle(double p) {
    if (p < .7) return 0;
    if (p < .75) return _seg(p, .7, .75, 0, -7);
    if (p < .82) return _seg(p, .75, .82, -7, 6);
    if (p < .89) return _seg(p, .82, .89, 6, -3);
    return _seg(p, .89, 1, -3, 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.kind == IdleKind.none || Motion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final p = (_c.value + widget.delay.inMicroseconds / widget.kind.period.inMicroseconds) % 1;
        switch (widget.kind) {
          case IdleKind.spin:
            return Transform.rotate(angle: p * 2 * math.pi, child: child);
          case IdleKind.wiggle:
            return Transform.rotate(angle: wiggleAngle(p) * math.pi / 180, child: child);
          case IdleKind.shake:
            return Transform.rotate(angle: shakeAngle(p) * math.pi / 180, alignment: Alignment.bottomCenter, child: child);
          case IdleKind.float:
            return Transform.translate(offset: Offset(0, -4 * (1 - math.cos(2 * math.pi * p)) / 2), child: child);
          case IdleKind.bob:
            return Transform.translate(offset: Offset(0, -4 * (1 - math.cos(2 * math.pi * p)) / 2), child: child);
          case IdleKind.none:
            return child!;
        }
      },
    );
  }
}
