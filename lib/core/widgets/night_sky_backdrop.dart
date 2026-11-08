// NightSkyBackdrop: the lobby's night (design board Main): a deep gradient,
// twinkling stars and a faint turning Ferris wheel.
//
// Why a file of its own: it is the only backdrop with its own animation loop and
// two dedicated painters; the other backdrops live in backdrops.dart.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';

/// The lobby's night: gradient, twinkling stars and a faint Ferris wheel.
class NightSkyBackdrop extends StatefulWidget {
  const NightSkyBackdrop({super.key, this.child});

  final Widget? child;

  @override
  State<NightSkyBackdrop> createState() => _NightSkyState();
}

class _NightSkyState extends State<NightSkyBackdrop> with SingleTickerProviderStateMixin {
  // Wheel: 26 s per turn; stars: 1.8 s twinkle → 46.8 s is a whole number of both.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 46800));

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
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          const RepaintBoundary(child: CustomPaint(painter: _NightGradientPainter())),
          RepaintBoundary(child: CustomPaint(painter: _NightSkyPainter(_c))),
          if (widget.child != null) widget.child!,
        ],
      );
}

class _NightGradientPainter extends CustomPainter {
  const _NightGradientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = const LmGradient([LmColors.night0, LmColors.night1, LmColors.night2, LmColors.night3], stops: [0, .4, .7, 1]).shader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_NightGradientPainter o) => false;
}

class _NightSkyPainter extends CustomPainter {
  _NightSkyPainter(this.clock) : super(repaint: clock);

  final Animation<double> clock;

  static const _stars = [
    Offset(22, 120), Offset(70, 180), Offset(120, 136), Offset(212, 158), Offset(262, 124), Offset(352, 144),
    Offset(40, 270), Offset(96, 340), Offset(196, 290), Offset(372, 270), Offset(20, 420), Offset(150, 440),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 844;
    final secs = clock.value * 46.8;
    for (var i = 0; i < _stars.length; i++) {
      final phase = ((secs - i * .23) / 1.8) % 1;
      final a = .35 + .65 * (1 - math.cos(2 * math.pi * phase)) / 2;
      canvas.drawCircle(
        Offset(_stars[i].dx * sx, _stars[i].dy * sy),
        (i % 3 == 0 ? 1.8 : 1.2) * sx,
        Paint()..color = const Color(0xFFFFF3C4).withValues(alpha: a),
      );
    }
    // The Ferris wheel: a rim and four spokes turning once per 26 s, at 22 % opacity.
    final c = Offset(330 * sx, 330 * sy);
    final r = 90 * sx;
    canvas.saveLayer(Offset.zero & size, Paint()..color = const Color(0x38FFFFFF));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(secs / 26 * 2 * math.pi);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..color = const Color(0xFF8FB6FF)
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(Offset.zero, r, line..strokeWidth = 3);
    line.strokeWidth = 2;
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(Offset(math.cos(a), math.sin(a)) * -r, Offset(math.cos(a), math.sin(a)) * r, line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NightSkyPainter o) => false;
}
