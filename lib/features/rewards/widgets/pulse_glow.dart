// PulseGlow: a soft coloured halo that breathes around a rounded box while it is [active] — the
// "next thing to collect" cue of the Earn board's open ladder row and the Missions board's
// milestone that is ready (their `lmGlow`).
//
// Behind the child, outside its box, so it never changes layout. Under Reduce Motion the halo is
// a still, half-strength glow instead of a pulse.

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';

class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.active,
    required this.color,
    required this.period,
    this.radius = 14,
    this.strength = .55,
    this.blur = 14,
    required this.child,
  });

  final bool active;
  final Color color;

  /// One breath (in and out).
  final Duration period;
  final double radius;

  /// The halo's opacity at its brightest, and its blur radius at its widest.
  final double strength;
  final double blur;
  final Widget child;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period ~/ 2);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.active && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = widget.active ? .5 : 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: widget.strength * t),
                blurRadius: widget.blur * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
