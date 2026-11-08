// Entrance: the staggered rise every screen uses to bring its cards in.
//
// Each child fades in while rising 18 pt over 460 ms with the standard curve; item
// `index` starts `index × 50 ms` later, so a column of tiles cascades in. With
// Reduce Motion nothing moves or waits: only a 120 ms fade remains.

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';

class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.index = 0,
    this.rise = 18,
    this.duration = Motion.enter,
    this.stagger = Motion.enterStagger,
    this.enabled = true,
  });

  final Widget child;

  /// Position in the cascade: delays the start by `index × stagger`.
  final int index;

  /// How far (pt) the child rises while fading in.
  final double rise;
  final Duration duration;
  final Duration stagger;

  /// False shows the child at once (e.g. when re-entering a cached screen).
  final bool enabled;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.enabled) {
      _c.value = 1;
      return;
    }
    if (Motion.reduced(context)) {
      _c.duration = const Duration(milliseconds: 120);
    } else {
      _c.duration = widget.duration + widget.stagger * widget.index;
    }
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
    final start = reduced ? 0.0 : ((widget.stagger * widget.index).inMicroseconds / total).clamp(0.0, .99);
    final curve = reduced ? Curves.easeOut : Motion.standardCurve;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = curve.transform(((_c.value - start) / (1 - start)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, reduced ? 0 : widget.rise * (1 - t)), child: child),
        );
      },
    );
  }
}
