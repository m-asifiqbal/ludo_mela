// Turning rays: the light behind the free-coins stack (Earn.dc.html, a ring of twelve short wedges
// turning once in 9 s) and behind the Day 7 Mela pot (DailyReward.dc.html, an eight-pointed star
// turning once in 10 s).
//
// Both are one painter inside [Spinning], which turns its child forever with a linear clock and
// stands still under Reduce Motion. Idle loops pause when the screen is off (TickerMode does that).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/art/glyph.dart' show lmParsePath;
import '../../../core/motion/motion.dart';
import '../rewards_motion.dart';
import '../rewards_palette.dart';

/// Turns [child] once every [period], linearly and forever (not at all with Reduce Motion).
class Spinning extends StatefulWidget {
  const Spinning({super.key, required this.period, required this.child});

  final Duration period;
  final Widget child;

  @override
  State<Spinning> createState() => _SpinningState();
}

class _SpinningState extends State<Spinning> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      _c.value = 0;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RotationTransition(turns: _c, child: widget.child);
}

/// Twelve 12° wedges every 30° inside a circle of [size]: the burst behind the free coins.
class CoinRays extends StatelessWidget {
  const CoinRays({super.key, this.size = 62});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: Spinning(
            period: RewardsMotion.coinRays,
            child: CustomPaint(size: Size.square(size), painter: const _WedgePainter()),
          ),
        ),
      );
}

class _WedgePainter extends CustomPainter {
  const _WedgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..isAntiAlias = true
      ..color = RewardsPalette.coinRays;
    for (var i = 0; i < 12; i++) {
      final start = i * 30 * math.pi / 180 - math.pi / 2;
      canvas.drawPath(
        Path()
          ..moveTo(rect.center.dx, rect.center.dy)
          ..arcTo(rect, start, 12 * math.pi / 180, false)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WedgePainter old) => false;
}

/// The eight-pointed star of light behind the Day 7 pot, drawn in a 220 × 220 box.
class PotRays extends StatelessWidget {
  const PotRays({super.key, this.size = 220});

  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: Spinning(
            period: RewardsMotion.potRays,
            child: CustomPaint(size: Size.square(size), painter: const _StarPainter()),
          ),
        ),
      );
}

class _StarPainter extends CustomPainter {
  const _StarPainter();

  static const _d = 'M0 0L-12 -110L12 -110zM0 0L110 -12L110 12zM0 0L12 110L-12 110zM0 0L-110 12L-110 -12z'
      'M0 0L70 -86L86 -70zM0 0L86 70L70 86zM0 0L-70 86L-86 70zM0 0L-86 -70L-70 -86z';

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / 220);
    canvas.drawPath(lmParsePath(_d), Paint()..color = RewardsPalette.potRays..isAntiAlias = true);
  }

  @override
  bool shouldRepaint(_StarPainter old) => false;
}
