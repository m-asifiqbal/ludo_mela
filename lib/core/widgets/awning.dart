// Awning and Bunting: the shamiana stripes with scalloped edge across the top of
// the lobby (Main.dc.html) and the strings of twinkling lights (splash, venue
// cards).
//
// The awning is red and cream stripes 26 pt wide, a 3 pt shade along the bottom and
// 26 × 12 scallops hanging under it in alternating colours; optional bulbs sit at
// the scallop tips and twinkle (1.8 s, staggered). Bunting is a sagging string
// with round bulbs in the mela colours.
// Reduce Motion: bulbs stay lit.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/colors.dart';

/// Height of the stripes block for an awning of [height] (the rest is scallops).
double awningStripeHeight(double height) => height - 12;

class Awning extends StatefulWidget {
  const Awning({super.key, this.height = 58, this.bulbs = false, this.stripe = 26, this.scallop = 12});

  /// Total height: stripes plus [scallop] pt of scallops (58 in the lobby, 51 in
  /// the Collection header).
  final double height;

  /// Depth of the scalloped edge (12 in the lobby, 11 in the Collection header).
  final double scallop;

  /// Twinkling bulbs at the scallop tips.
  final bool bulbs;

  /// Width of one stripe / scallop.
  final double stripe;

  @override
  State<Awning> createState() => _AwningState();
}

class _AwningState extends State<Awning> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.bulbs && !Motion.reduced(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void didUpdateWidget(Awning old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(painter: _AwningPainter(widget.stripe, widget.scallop, widget.bulbs, _c, Motion.reduced(context))),
          ),
        ),
      );
}

class _AwningPainter extends CustomPainter {
  _AwningPainter(this.stripe, this.scallop, this.bulbs, this.clock, this.still) : super(repaint: clock);

  final double stripe;
  final double scallop;
  final bool bulbs;
  final Animation<double> clock;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final block = size.height - scallop;
    final n = (size.width / stripe).ceil();
    final red = Paint()..color = LmColors.awningRed;
    final cream = Paint()..color = LmColors.awningCream;
    for (var i = 0; i < n; i++) {
      canvas.drawRect(Rect.fromLTWH(i * stripe, 0, stripe, block), i.isEven ? red : cream);
    }
    canvas.drawRect(Rect.fromLTWH(0, block - 3, size.width, 3), Paint()..color = const Color(0x1F000000));
    for (var i = 0; i < n; i++) {
      final x = i * stripe;
      final path = Path()
        ..moveTo(x, block - 1)
        ..lineTo(x + stripe, block - 1)
        ..arcToPoint(Offset(x, block - 1), radius: Radius.elliptical(stripe / 2, scallop), clockwise: true)
        ..close();
      canvas.drawPath(path, i.isEven ? red : cream);
    }
    if (!bulbs) return;
    for (var i = 0; i < n; i++) {
      final phase = still ? 0.0 : (clock.value + (i % 5) * .13) % 1;
      final glow = .35 + .65 * (1 - math.cos(2 * math.pi * phase)) / 2;
      final c = Offset(i * stripe + stripe / 2, block + 10.5);
      final color = LmColors.bunting[i % LmColors.bunting.length];
      canvas.drawCircle(c, 5, Paint()..color = color.withValues(alpha: .35 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
      canvas.drawCircle(c, 3, Paint()..color = color.withValues(alpha: glow));
    }
  }

  @override
  bool shouldRepaint(_AwningPainter o) => o.stripe != stripe || o.scallop != scallop || o.bulbs != bulbs || o.still != still;
}

/// A string of round bulbs hanging in a curve across [height] pt (the splash
/// string: 14 bulbs, 45 pt sag).
class Bunting extends StatefulWidget {
  const Bunting({super.key, this.height = 130, this.count = 14, this.sag = 45, this.radius = 6, this.top = 20});

  final double height;
  final int count;

  /// How far the middle of the string hangs below its ends.
  final double sag;
  final double radius;

  /// Height of the string's ends from the top.
  final double top;

  @override
  State<Bunting> createState() => _BuntingState();
}

class _BuntingState extends State<Bunting> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));

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
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: RepaintBoundary(child: CustomPaint(painter: _BuntingPainter(widget, _c, Motion.reduced(context)))),
        ),
      );
}

class _BuntingPainter extends CustomPainter {
  _BuntingPainter(this.w, this.clock, this.still) : super(repaint: clock);

  final Bunting w;
  final Animation<double> clock;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final x0 = -10.0;
    final x1 = size.width + 10;
    final string = Path()
      ..moveTo(x0, w.top)
      ..quadraticBezierTo(size.width / 2, w.top + 2 * w.sag, x1, w.top);
    canvas.drawPath(
      string,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = LmColors.navy.withValues(alpha: .5),
    );
    for (var i = 0; i < w.count; i++) {
      final t = (i + .5) / w.count;
      final c = Offset(x0 + t * (x1 - x0), w.top + 4 * w.sag * t * (1 - t));
      final phase = still ? 0.0 : (clock.value + (i % 4) * .22) % 1;
      final a = .35 + .65 * (1 - math.cos(2 * math.pi * phase)) / 2;
      final color = LmColors.bunting[i % LmColors.bunting.length];
      canvas.drawCircle(c, w.radius, Paint()..color = color.withValues(alpha: a));
      canvas.drawCircle(
        c,
        w.radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
  }

  @override
  bool shouldRepaint(_BuntingPainter o) => o.w != w || o.still != still;
}
