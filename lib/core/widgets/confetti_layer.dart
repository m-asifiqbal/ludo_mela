// ConfettiLayer: paper bits falling over the win screen (Win.dc.html).
//
// 24 rounded paper strips in the mela colours, each 6 – 10 pt wide and 10 – 19 pt
// tall, fall from above the screen turning one and a half times; every strip
// repeats on its own period (3 – 5.4 s) and start delay, and the whole shower
// runs for [duration] (3 – 6 s) before the last strips drift out. Reduce Motion
// shows nothing ("no confetti"). The layer ignores touches.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/colors.dart';

class ConfettiLayer extends StatefulWidget {
  const ConfettiLayer({super.key, this.count = 24, this.duration = const Duration(seconds: 5)});

  /// Number of paper strips.
  final int count;

  /// How long new strips keep falling.
  final Duration duration;

  @override
  State<ConfettiLayer> createState() => _ConfettiLayerState();
}

class _ConfettiLayerState extends State<ConfettiLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
      return;
    }
    if (!_c.isAnimating && !_c.isCompleted) {
      // The last strip starts at most 3 s late and falls for up to 5.4 s.
      _c.duration = widget.duration + const Duration(milliseconds: 5400);
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_c, widget.count, widget.duration.inMilliseconds / 1000),
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.clock, this.count, this.runFor) : super(repaint: clock);

  final AnimationController clock;
  final int count;
  final double runFor;

  @override
  void paint(Canvas canvas, Size size) {
    final secs = clock.value * clock.duration!.inMilliseconds / 1000;
    for (var i = 0; i < count; i++) {
      final period = 3 + (i % 5) * .6;
      final delay = (i * .37) % 3;
      final local = secs - delay;
      if (local < 0) continue;
      final cycle = (local / period).floor();
      if (delay + cycle * period >= runFor) continue; // no new fall after the run
      final p = (local % period) / period;
      final w = 6.0 + (i % 3) * 2;
      final h = 10.0 + (i % 4) * 3;
      final x = ((i * 61) % 380) / 380 * (size.width - w);
      final y = -40 + p * (size.height + 80);
      canvas.save();
      canvas.translate(x + w / 2, y + h / 2);
      canvas.rotate(p * 540 * math.pi / 180);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), const Radius.circular(2)),
        Paint()..color = LmColors.confetti[i % LmColors.confetti.length],
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter o) => o.count != count || o.runFor != runFor;
}
