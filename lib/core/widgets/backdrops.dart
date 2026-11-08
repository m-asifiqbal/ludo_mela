// Screen backdrops: the "mela" grounds every screen sits on.
//
// * [RoyalBackdrop] — the blue radial ground with the faint jali lattice (match,
//   menus), and its colour siblings: the purple Mayhem ground, the green tabletop
//   felt and the Mela Cup blue ([BackdropSpec]).
// * [PurpleRaysBackdrop] — the lucky wheel's purple with slowly turning light
//   rays; [SunRaysBackdrop] is the blue burst of the splash, VS intro and win.
// * [NightSkyBackdrop] — the lobby's night: a blue gradient, twinkling stars and
//   a faint Ferris wheel turning in the corner.
//
// All ground colours are CSS radial gradients (an ellipse of 90–130 % × 45–70 %
// of the screen) so they stretch to any phone. Everything animated stops with
// Reduce Motion (rays and wheel still, stars lit).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';

/// A radial ground: gradient colours, the ellipse radii as fractions of the
/// screen, its centre, and the optional jali lattice / light rays on top.
class BackdropSpec {
  const BackdropSpec({
    required this.colors,
    required this.stops,
    required this.rx,
    required this.ry,
    this.cx = .5,
    this.cy = .5,
    this.jali = true,
    this.rays = 0,
    this.rayAlpha = .07,
    this.raySpin = const Duration(seconds: 24),
    this.rayColor = const Color(0xFFFFFFFF),
  });

  final List<Color> colors;
  final List<double> stops;

  /// Ellipse radii as a fraction of the width / height (1.1 = 110 %).
  final double rx;
  final double ry;

  /// Ellipse centre as a fraction of the width / height.
  final double cx;
  final double cy;
  final bool jali;

  /// Number of light rays (0 = none), their opacity and the time of one turn.
  final int rays;
  final double rayAlpha;
  final Duration raySpin;
  final Color rayColor;

  /// The match / menu ground (Match.dc.html).
  static const royal = BackdropSpec(
    colors: [Color(0xFF3EA2FF), Color(0xFF1F78E6), Color(0xFF1659C4), Color(0xFF0F45A6)],
    stops: [0, .4, .72, 1],
    rx: 1.1,
    ry: .6,
    cy: .48,
  );

  /// The plain screen ground (pause, settings, profile).
  static const screen = BackdropSpec(
    colors: [Color(0xFF3E9CFA), Color(0xFF1F6EE0), Color(0xFF1250C2), Color(0xFF0B3592)],
    stops: [0, .4, .7, 1],
    rx: 1.2,
    ry: .6,
  );

  /// Mela Mayhem purple.
  static const mayhem = BackdropSpec(
    colors: [Color(0xFF9B6BFF), Color(0xFF6A35D6), Color(0xFF4A22A8), Color(0xFF2A0F6E)],
    stops: [0, .4, .7, 1],
    rx: 1.2,
    ry: .6,
  );

  /// The lucky wheel: purple with 18 turning rays.
  static const wheel = BackdropSpec(
    colors: [Color(0xFFB98BFF), Color(0xFF7A45E6), Color(0xFF4A22A8), Color(0xFF2A0F6E)],
    stops: [0, .35, .65, 1],
    rx: .9,
    ry: .55,
    cy: .45,
    jali: false,
    rays: 18,
    raySpin: Duration(seconds: 30),
  );

  /// The win screen: bright blue with 16 rays behind the podium.
  static const win = BackdropSpec(
    colors: [Color(0xFF9AD6FF), Color(0xFF2F8BF0), Color(0xFF1250C2), Color(0xFF0A2C80)],
    stops: [0, .35, .65, 1],
    rx: .9,
    ry: .45,
    cy: .26,
    jali: false,
    rays: 16,
    rayAlpha: .08,
  );

  /// The splash: the dice and logo in a burst of light.
  static const splash = BackdropSpec(
    colors: [Color(0xFF9AD6FF), Color(0xFF2F8BF0), Color(0xFF1250C2), Color(0xFF0A2C80)],
    stops: [0, .32, .62, 1],
    rx: .9,
    ry: .5,
    cy: .4,
    jali: false,
    rays: 18,
    rayAlpha: .08,
    raySpin: Duration(seconds: 30),
  );

  /// The VS intro.
  static const vsIntro = BackdropSpec(
    colors: [Color(0xFF7CC8FF), Color(0xFF2A82EE), Color(0xFF1250C2), Color(0xFF0A2C80)],
    stops: [0, .35, .65, 1],
    rx: .9,
    ry: .55,
    cy: .47,
    jali: false,
    rays: 16,
  );

  /// The tabletop's green felt.
  static const felt = BackdropSpec(
    colors: [Color(0xFF3FAF5A), Color(0xFF1F8A3E), Color(0xFF0E5A2E), Color(0xFF083A1C)],
    stops: [0, .4, .75, 1],
    rx: 1.1,
    ry: .6,
  );

  /// The Mela Cup: gold rays over the blue.
  static const cup = BackdropSpec(
    colors: [Color(0xFF3E9CFA), Color(0xFF1F6EE0), Color(0xFF1250C2), Color(0xFF0B3592)],
    stops: [0, .4, .7, 1],
    rx: 1.3,
    ry: .7,
    cy: .3,
    rays: 12,
    rayAlpha: .16,
    raySpin: Duration(seconds: 16),
    rayColor: Color(0xFFFFE27A),
  );
}

/// Paints a [BackdropSpec]'s ground (and jali) into [size].
void lmPaintBackdrop(Canvas canvas, Size size, BackdropSpec s) {
  final r = Offset.zero & size;
  canvas.drawRect(
    r,
    Paint()..shader = lmEllipticalRadialShader(Offset(size.width * s.cx, size.height * s.cy), size.width * s.rx, size.height * s.ry, s.colors, s.stops),
  );
  if (s.jali) lmPaintJali(canvas, size);
}

/// The jali lattice: 44 pt tiles of a diamond inside a square, white at 7 %.
void lmPaintJali(Canvas canvas, Size size) {
  final path = Path();
  for (var y = 0.0; y < size.height; y += 44) {
    for (var x = 0.0; x < size.width; x += 44) {
      path
        ..moveTo(x + 22, y + 8)
        ..lineTo(x + 36, y + 22)
        ..lineTo(x + 22, y + 36)
        ..lineTo(x + 8, y + 22)
        ..close()
        ..addRect(Rect.fromLTWH(x + 12.5, y + 12.5, 19, 19));
    }
  }
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = LmColors.jali
      ..isAntiAlias = true,
  );
}

class _GroundPainter extends CustomPainter {
  const _GroundPainter(this.spec);

  final BackdropSpec spec;

  @override
  void paint(Canvas canvas, Size size) => lmPaintBackdrop(canvas, size, spec);

  @override
  bool shouldRepaint(_GroundPainter o) => o.spec != spec;
}

/// Paints [count] rays fanning out from [center] and turned by [turn] radians.
void lmPaintRays(Canvas canvas, Offset center, double length, int count, double turn, Color color) {
  final path = Path();
  final half = length * .08;
  for (var i = 0; i < count; i++) {
    final a = turn + i * 2 * math.pi / count;
    final dir = Offset(math.sin(a), -math.cos(a));
    final side = Offset(math.cos(a), math.sin(a));
    path
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + dir.dx * length - side.dx * half, center.dy + dir.dy * length - side.dy * half)
      ..lineTo(center.dx + dir.dx * length + side.dx * half, center.dy + dir.dy * length + side.dy * half)
      ..close();
  }
  canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
}

class _RaysPainter extends CustomPainter {
  _RaysPainter(this.spec, this.clock) : super(repaint: clock);

  final BackdropSpec spec;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) => lmPaintRays(
        canvas,
        Offset(size.width * spec.cx, size.height * spec.cy),
        size.longestSide * 1.3,
        spec.rays,
        clock.value * 2 * math.pi,
        spec.rayColor.withValues(alpha: spec.rayAlpha),
      );

  @override
  bool shouldRepaint(_RaysPainter o) => o.spec != spec;
}

/// A [BackdropSpec] ground with the child on top.
class ScreenBackdrop extends StatefulWidget {
  const ScreenBackdrop({super.key, this.spec = BackdropSpec.royal, this.child});

  final BackdropSpec spec;
  final Widget? child;

  @override
  State<ScreenBackdrop> createState() => _ScreenBackdropState();
}

class _ScreenBackdropState extends State<ScreenBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ScreenBackdrop old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    _c.duration = widget.spec.raySpin;
    if (widget.spec.rays > 0 && !Motion.reduced(context)) {
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

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: CustomPaint(painter: _GroundPainter(widget.spec))),
          if (widget.spec.rays > 0) RepaintBoundary(child: CustomPaint(painter: _RaysPainter(widget.spec, _c))),
          if (widget.child != null) widget.child!,
        ],
      );
}

/// The blue radial ground with the jali lattice.
class RoyalBackdrop extends StatelessWidget {
  const RoyalBackdrop({super.key, this.spec = BackdropSpec.royal, this.child});

  final BackdropSpec spec;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(spec: spec, child: child);
}

/// The lucky wheel's purple with turning rays.
class PurpleRaysBackdrop extends StatelessWidget {
  const PurpleRaysBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(spec: BackdropSpec.wheel, child: child);
}

/// The blue burst of light (splash, VS intro, win): pick the spec that fits.
class SunRaysBackdrop extends StatelessWidget {
  const SunRaysBackdrop({super.key, this.spec = BackdropSpec.win, this.child});

  final BackdropSpec spec;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(spec: spec, child: child);
}

/// The tabletop's green felt.
class FeltBackdrop extends StatelessWidget {
  const FeltBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) => ScreenBackdrop(spec: BackdropSpec.felt, child: child);
}
