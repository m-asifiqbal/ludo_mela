// Canvas painters for the pieces: the thick coin, its movable ring, the hint
// glow, the target ghost, the Mayhem shield / ice and the stack-count chip.
//
// Why functions: the same coin is drawn by the board overlay (22 pt), the yard
// (29 pt), the Collection preview (36 pt) and the splash (46 pt), and by tests.
// Every measurement below is the artboards' CSS in "design px" (a 25 pt square
// board); pass [u] = cell / 25 to scale a mini board or a bigger phone.
//
// The coin (Match.dc.html): a flat side band in the seat's `side` colour sits
// 3.5 pt below the face and carries a soft shadow; the face is a radial gradient
// (light → main 58 % → dark) with a light ring and a darker ring just inside the
// edge and a faint top highlight; the emblem is stamped in white.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan, TextDirection, TextAlign;

import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'emblems.dart';
import 'glyph.dart';
import 'piece_skin.dart';

/// How far the side band hangs below the face of a coin of edge [s] (design px).
double lmCoinDepth(double s) => s <= 20 ? 2.5 : (s <= 30 ? 3.5 : math.max(3.5, s * .14));

/// Width of the light ring (and, in [lmCoinDarkRing], the darker one) of a coin.
double lmCoinRing(double s) => s > 40 ? 3.5 : (s > 30 ? 3 : 2);
double lmCoinDarkRing(double s) => lmCoinRing(s) + (s > 30 ? 2 : 1.5);

/// Paints a coin of edge [s] with its face centred on [c]. [u] scales the
/// design-px constants (side band, rings); [mark] replaces the emblem with a
/// seat shape (colour-blind help).
void lmPaintCoin(
  Canvas canvas,
  Offset c,
  double s,
  LmSeatColors colors,
  PieceSkin skin, {
  double u = 1,
  SeatMark? mark,
  bool shadow = true,
}) {
  final d = s / u; // size in design px, to pick the proportions
  final th = lmCoinDepth(d) * u;
  final face = skin.shape.radius(s).toRRect(Rect.fromCenter(center: c, width: s, height: s));
  if (shadow) {
    canvas.drawRRect(
      face.shift(Offset(0, th * 2)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * u),
    );
  }
  canvas.drawRRect(face.shift(Offset(0, th)), Paint()..color = colors.side..isAntiAlias = true);
  canvas.drawRRect(
    face,
    Paint()
      ..isAntiAlias = true
      ..shader = lmRadialShader(face.outerRect, .5, .32, [colors.light, colors.main, colors.dark], const [0, .58, 1]),
  );
  final ring = lmCoinRing(d) * u;
  lmPaintInsetShadows(canvas, face, [
    LmShadow.rim(skin.ring, ring),
    LmShadow.rim(colors.dark, lmCoinDarkRing(d) * u),
    LmShadow(const Color(0x59FFFFFF), dy: (d * .135).clamp(2.5, 4.0) * u, blur: (d * .09).clamp(2.0, 4.0) * u, inset: true),
  ]);

  final es = (s * .6).roundToDouble();
  if (mark != null) {
    mark.paint(canvas, c, es * .44, fill: const Color(0xF2FFFFFF), edge: colors.dark, edgeWidth: math.max(1, s * .06));
    return;
  }
  canvas.save();
  canvas.translate(c.dx - es / 2, c.dy - es / 2);
  canvas.scale(es / 24);
  canvas.drawPath(
    lmParsePath(skin.emblem),
    Paint()
      ..color = Color.fromRGBO(255, 255, 255, skin.emblemOpacity)
      ..isAntiAlias = true,
  );
  canvas.restore();
}

/// Strokes a dashed circle: [dash] / [gap] along the circumference, started
/// at 3 o'clock and rotated by [turn] radians.
void lmDashedCircle(Canvas canvas, Offset c, double r, Paint paint, {required double dash, required double gap, double turn = 0, bool fit = false}) {
  final circ = 2 * math.pi * r;
  var dd = dash;
  var gg = gap;
  if (fit) {
    final n = math.max(1, (circ / (dash + gap)).round());
    final k = circ / (n * (dash + gap));
    dd *= k;
    gg *= k;
  }
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(turn);
  final path = Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: r));
  for (final m in path.computeMetrics()) {
    var at = 0.0;
    while (at < m.length) {
      canvas.drawPath(m.extractPath(at, math.min(at + dd, m.length)), paint);
      at += dd + gg;
    }
  }
  canvas.restore();
}

/// The white dashed ring of a piece that can move (6 / 4.4 dashes, 2.8 pt
/// stroke, 22 % white fill) around a coin of edge [s] whose face is at [c].
void lmPaintMovableRing(Canvas canvas, Offset c, double s, {double u = 1, double turn = 0}) {
  final rs = s + 14 * u;
  final ctr = c.translate(0, 1.5 * u);
  final r = .4375 * rs;
  canvas.drawCircle(ctr, r, Paint()..color = const Color(0x38FFFFFF)..isAntiAlias = true);
  lmDashedCircle(
    canvas,
    ctr,
    r,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .07 * rs
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = true,
    dash: .15 * rs,
    gap: .11 * rs,
    turn: turn,
  );
}

/// The glow around the piece the hint suggests: a 3 pt ring and a soft halo.
void lmPaintHintGlow(Canvas canvas, Offset c, double s, {double u = 1}) {
  final ctr = c.translate(0, 1.75 * u);
  final r = (s + 6 * u) / 2;
  canvas.drawCircle(
    ctr,
    r + 5 * u,
    Paint()
      ..color = LmColors.hintGlow.withValues(alpha: .85)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * u),
  );
  canvas.drawCircle(
    ctr,
    r + 1.5 * u,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u
      ..color = LmColors.hintGlow
      ..isAntiAlias = true,
  );
}

/// The target preview: a dashed navy circle on 55 % gold, edge [s].
void lmPaintTargetGhost(Canvas canvas, Offset c, double s, {double u = 1}) {
  canvas.drawCircle(c, s / 2, Paint()..color = const Color(0x8CFFC61F)..isAntiAlias = true);
  final w = 2.5 * u;
  lmDashedCircle(
    canvas,
    c,
    s / 2 - w / 2,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..color = const Color(0xFF0C2C6A)
      ..isAntiAlias = true,
    dash: w * 2.2,
    gap: w * 1.5,
    fit: true,
  );
}

/// The Mayhem shield: a faint teal disc and a ring whose glow breathes with
/// [phase] (0 → 1 → 0, 1.6 s loop).
void lmPaintShield(Canvas canvas, Offset c, double s, {double u = 1, double phase = 0}) {
  final r = s / 2 + 6 * u;
  canvas.drawCircle(c, r, Paint()..color = LmColors.shieldGlow.withValues(alpha: .22)..isAntiAlias = true);
  final t = phase.clamp(0.0, 1.0);
  double lerp(double a, double b) => a + (b - a) * t;
  canvas.drawCircle(
    c,
    r + lerp(4, 8) * u,
    Paint()
      ..color = LmColors.shieldGlow.withValues(alpha: lerp(.55, .25))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, lerp(5, 9) * u),
  );
  canvas.drawCircle(
    c,
    r + lerp(1, 1.5) * u,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerp(2, 3) * u
      ..color = Color.lerp(LmColors.shieldGlow.withValues(alpha: .95), const Color(0xFFFFFFFF), t)!
      ..isAntiAlias = true,
  );
}

/// The ice block over a frozen piece (Mayhem freeze card): a glassy rounded
/// square with a snowflake.
void lmPaintIce(Canvas canvas, Offset c, double s, {double u = 1}) {
  final box = RRect.fromRectAndRadius(
    Rect.fromCenter(center: c.translate(0, 1.5 * u), width: s + 8 * u, height: s + 8 * u),
    Radius.circular(7 * u),
  );
  lmPaintBox(
    canvas,
    box,
    gradient: const LmGradient([Color(0xD9E6F8FF), Color(0x9996D2FF)], angle: 135),
    shadows: [
      LmShadow.rim(const Color(0xFFFFFFFF), 1.5 * u),
      LmShadow(const Color(0x4D000000), dy: 2 * u, blur: 4 * u),
    ],
  );
  final f = math.min(16 * u, s * .8);
  canvas.save();
  canvas.translate(box.center.dx - f / 2, box.center.dy - f / 2);
  canvas.scale(f / 24);
  canvas.drawPath(
    lmParsePath(LmEmblems.snowflake),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round
      ..color = LmColors.freezeInk
      ..isAntiAlias = true,
  );
  canvas.restore();
}

/// The "×3" chip on a stack of three or more pieces.
void lmPaintCountChip(Canvas canvas, Offset anchor, int count, {double u = 1}) {
  final r = 6.5 * u;
  canvas.drawCircle(anchor, r + 1.2 * u, Paint()..color = const Color(0xFFFFFFFF)..isAntiAlias = true);
  canvas.drawCircle(anchor, r, Paint()..color = LmColors.navy..isAntiAlias = true);
  final tp = TextPainter(
    text: TextSpan(text: '$count', style: LmText.plain(9.5 * u, height: 1.0, shadows: const [])),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout();
  tp.paint(canvas, anchor - Offset(tp.width / 2, tp.height / 2));
}
