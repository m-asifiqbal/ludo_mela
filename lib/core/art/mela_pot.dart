// MelaPot: the clay / silver / gold pots of the lobby shelf (Main.dc.html) —
// with a coloured cloth tied on top, a ready-to-open shake and a crack-open
// animation with flying shards.
//
// Pots are earned, never bought: clay (3 h), silver (8 h), gold (12 h) and the
// event "Mela pot". The cloth colour tells the timer's state / rarity (red ready,
// blue waiting, purple big). A pot that is ready shakes (rotate −7° / +6° / −3°
// around its base every 2.2 s) and glows; tapping opens it: the pot wobbles, a
// jagged crack flashes, the body splits in two and falls away, the cloth pops
// off and shards fly out in front of a golden burst (1.1 s).
// Reduce Motion: no shake; opening is a short flash and fade.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui show Gradient;

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import 'glyph.dart';

/// The pot's material.
enum PotKind {
  clay,
  silver,
  gold,

  /// The festive event pot (magenta with gold trim).
  mela;

  /// Body fill gradient (left → right) and outline.
  (List<Color>, Color) get paint => switch (this) {
        PotKind.clay => (const [Color(0xFF9A4418), Color(0xFFE07A3A), Color(0xFF8A3A12)], const Color(0xFF5A2006)),
        PotKind.silver => (const [Color(0xFFF4F6FA), Color(0xFFB7C0D0), Color(0xFF8A94A8)], const Color(0xFF4A5468)),
        PotKind.gold => (const [Color(0xFFFFEC8F), Color(0xFFFFC21F), Color(0xFFC98A00)], const Color(0xFF6B4300)),
        PotKind.mela => (const [Color(0xFFB02A86), Color(0xFFFF6CC0), Color(0xFF8A1E66)], const Color(0xFF4A0A34)),
      };
}

const _body = 'M14 14q14-4 28 0l-2 6q10 6 10 18q0 16-22 18q-22-2-22-18q0-12 10-18z';
const _cloth = 'M12 6q16-6 32 0l-2 9q-14-4-28 0z';
const _band = 'M13 14q15-4 30 0';
const _dots = 'M9 34q19 6 38 0';

/// Paints a pot in the 56 × 58 design box scaled to [size]. [shake] is the
/// rotation in degrees about the base; [open] (0 – 1) is the crack-open progress.
void lmPaintPot(Canvas canvas, Size size, PotKind kind, Color cloth, {double shake = 0, double open = 0, double glow = 0}) {
  canvas.save();
  canvas.scale(size.width / 56, size.height / 58);
  final (fill, edge) = kind.paint;
  if (glow > 0 && open == 0) {
    canvas.drawCircle(const Offset(28, 36), 26, Paint()..color = const Color(0xFFFFD65A).withValues(alpha: .8 * glow)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
  }
  canvas.translate(28, 56);
  canvas.rotate(shake * math.pi / 180);
  canvas.translate(-28, -56);
  final bodyPaint = Paint()
    ..isAntiAlias = true
    ..shader = ui.Gradient.linear(const Offset(6, 0), const Offset(50, 0), fill, const [0, .45, 1]);

  void drawBody() {
    final p = lmParsePath(_body);
    canvas.drawPath(p, bodyPaint);
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..strokeJoin = StrokeJoin.round..color = edge..isAntiAlias = true);
    final dots = Path();
    for (final m in lmParsePath(_dots).computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        dots.addPath(m.extractPath(d, math.min(d + 3, m.length)), Offset.zero);
        d += 6;
      }
    }
    canvas.drawPath(dots, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = const Color(0xFFFFE1A8)..isAntiAlias = true);
  }

  void drawCloth() {
    final c = lmParsePath(_cloth);
    canvas.drawPath(c, Paint()..color = cloth..isAntiAlias = true);
    canvas.drawPath(c, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeJoin = StrokeJoin.round..color = edge..isAntiAlias = true);
    canvas.drawPath(lmParsePath(_band), Paint()..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..color = const Color(0xFFFFC61F)..isAntiAlias = true);
  }

  if (open <= 0) {
    drawBody();
    drawCloth();
    canvas.restore();
    return;
  }
  _paintOpening(canvas, open, drawBody, drawCloth, fill[1], edge);
  canvas.restore();
}

// The jagged crack down the middle of the body (design box).
const _crack = [Offset(28, 12), Offset(24, 22), Offset(31, 30), Offset(25, 40), Offset(29, 52)];

void _paintOpening(Canvas canvas, double t, VoidCallback drawBody, VoidCallback drawCloth, Color clay, Color edge) {
  double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);
  // Golden burst behind everything.
  final burst = math.sin(math.pi * seg(.3, 1));
  if (burst > 0) {
    canvas.drawCircle(const Offset(28, 34), 8 + 40 * seg(.3, .8), Paint()..color = const Color(0xFFFFE27A).withValues(alpha: .85 * burst)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
  }
  final split = Curves.easeIn.transform(seg(.4, 1));
  final fade = 1 - seg(.75, 1);
  Path half(bool left) {
    final edgeX = left ? -20.0 : 76.0;
    final p = Path()..moveTo(edgeX, -20)..lineTo(28, -20);
    for (final c in _crack) {
      p.lineTo(c.dx, c.dy);
    }
    return p..lineTo(29, 80)..lineTo(edgeX, 80)..close();
  }

  if (t < .4) {
    // Wobble: three swings that grow, with a swell.
    final w = seg(0, .4);
    canvas.save();
    canvas.translate(28, 56);
    canvas.rotate(math.sin(w * math.pi * 6) * (4 + 10 * w) * math.pi / 180);
    canvas.scale(1 + .08 * w);
    canvas.translate(-28, -56);
    drawBody();
    drawCloth();
    final k = seg(.25, .4);
    if (k > 0) {
      final path = Path()..moveTo(_crack.first.dx, _crack.first.dy);
      for (final c in _crack.skip(1)) {
        path.lineTo(c.dx, c.dy);
      }
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round..color = const Color(0xFFFFFFFF).withValues(alpha: k)..isAntiAlias = true);
    }
    canvas.restore();
    return;
  }
  for (final left in [true, false]) {
    final dir = left ? -1.0 : 1.0;
    canvas.save();
    canvas.translate(28 + dir * 16 * split, 56 + 26 * split * split);
    canvas.rotate(dir * 22 * split * math.pi / 180);
    canvas.translate(-28, -56);
    canvas.saveLayer(const Rect.fromLTWH(-40, -40, 140, 140), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
    canvas.clipPath(half(left));
    drawBody();
    canvas.restore();
    canvas.restore();
  }
  // The cloth pops off.
  final lid = Curves.easeOut.transform(seg(.4, 1));
  canvas.save();
  canvas.translate(28, 10 - 44 * lid + 30 * lid * lid);
  canvas.rotate(26 * lid * math.pi / 180);
  canvas.translate(-28, -10);
  canvas.saveLayer(const Rect.fromLTWH(-40, -80, 140, 160), Paint()..color = Color.fromRGBO(0, 0, 0, fade));
  drawCloth();
  canvas.restore();
  canvas.restore();
  // Shards: deterministic arcs under gravity.
  final ts = seg(.4, 1);
  for (var i = 0; i < 8; i++) {
    final a = (i / 8) * math.pi * 2 + .4;
    final vx = math.cos(a) * (30 + 14 * (i % 3));
    final vy = -34 - 26 * ((i * 5) % 4) / 3;
    final x = 28 + vx * ts * 1.1;
    final y = 34 + vy * ts * 1.1 + 70 * ts * ts;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(a + ts * (i.isEven ? 5 : -5));
    final s = 3.2 + (i % 3);
    final shard = Path()..moveTo(-s, s)..lineTo(0, -s * 1.3)..lineTo(s, s * .8)..close();
    canvas.drawPath(shard, Paint()..color = (i % 3 == 2 ? edge : clay).withValues(alpha: fade)..isAntiAlias = true);
    canvas.restore();
  }
}

/// lmShake: the "ready" wobble of a pot over one loop [p] (0 – 1): still for 70 %,
/// then −7° / +6° / −3° / 0 (ease per segment).
double lmPotShakeAngle(double p) {
  if (p < .7) return 0;
  double seg(double a, double b, double from, double to) => from + (to - from) * Curves.ease.transform((p - a) / (b - a));
  if (p < .75) return seg(.7, .75, 0, -7);
  if (p < .82) return seg(.75, .82, -7, 6);
  if (p < .89) return seg(.82, .89, 6, -3);
  return seg(.89, 1, -3, 0);
}

/// Drives a [MelaPot] from outside: open it (crack + shards) or put it back.
class MelaPotController {
  _MelaPotState? _state;

  /// True once the pot has burst (until [reset]).
  bool get isOpen => _state?._opened ?? false;

  /// Plays the crack-open animation; completes when it ends.
  Future<void> open() => _state?._open() ?? Future<void>.value();

  /// Puts the pot back together (for the next one in the slot).
  void reset() => _state?._reset();
}

class MelaPot extends StatefulWidget {
  const MelaPot({
    super.key,
    this.kind = PotKind.clay,
    this.cloth = const Color(0xFFE8322B),
    this.ready = false,
    this.controller,
    this.size = 48,
    this.semanticLabel,
  });

  final PotKind kind;

  /// The cloth tied over the mouth.
  final Color cloth;

  /// Shakes and glows ("Tap to open").
  final bool ready;
  final MelaPotController? controller;

  /// Width in pt (the pot is 56 : 58).
  final double size;
  final String? semanticLabel;

  @override
  State<MelaPot> createState() => _MelaPotState();
}

class _MelaPotState extends State<MelaPot> with TickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _openC = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MelaPot old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    _sync();
  }

  void _sync() {
    final run = widget.ready && !_opened && !Motion.reduced(context);
    if (run && !_shake.isAnimating) {
      _shake.repeat();
    } else if (!run && _shake.isAnimating) {
      _shake.stop();
      _shake.value = 0;
    }
  }

  Future<void> _open() {
    if (_opened) return Future<void>.value();
    _opened = true;
    _shake.stop();
    final done = Completer<void>();
    _openC.duration = Motion.reduced(context) ? const Duration(milliseconds: 220) : const Duration(milliseconds: 1100);
    _openC.forward(from: 0).whenComplete(() {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  void _reset() {
    _opened = false;
    _openC.value = 0;
    _sync();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _shake.dispose();
    _openC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final h = w.size * 58 / 56;
    final art = AnimatedBuilder(
      animation: Listenable.merge([_shake, _openC]),
      builder: (context, _) {
        final reduced = Motion.reduced(context);
        if (_opened && reduced) {
          final f = 1 - Curves.easeIn.transform(_openC.value);
          return Opacity(opacity: f, child: CustomPaint(size: Size(w.size, h), painter: _PotPainter(w.kind, w.cloth, 0, 0, 1)));
        }
        return CustomPaint(
          size: Size(w.size, h),
          painter: _PotPainter(w.kind, w.cloth, _opened ? 0 : lmPotShakeAngle(_shake.value), _opened ? _openC.value : 0, w.ready && !_opened ? 1 : 0),
        );
      },
    );
    // The glow, wobble and shards paint outside this box (nothing here clips).
    final box = SizedBox(width: w.size, height: h, child: art);
    if (w.semanticLabel == null) return ExcludeSemantics(child: box);
    return Semantics(label: w.semanticLabel, image: true, child: ExcludeSemantics(child: box));
  }
}

class _PotPainter extends CustomPainter {
  const _PotPainter(this.kind, this.cloth, this.shake, this.open, this.glow);

  final PotKind kind;
  final Color cloth;
  final double shake;
  final double open;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) => lmPaintPot(canvas, size, kind, cloth, shake: shake, open: open, glow: glow);

  @override
  bool shouldRepaint(_PotPainter o) => o.kind != kind || o.cloth != cloth || o.shake != shake || o.open != open || o.glow != glow;
}

/// The dashed outline of an empty pot slot on the shelf (50 × 38, "Empty").
class EmptyPotSlot extends StatelessWidget {
  const EmptyPotSlot({super.key, this.size = const Size(50, 38)});

  final Size size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CustomPaint(size: size, painter: const _SlotPainter()));
}

class _SlotPainter extends CustomPainter {
  const _SlotPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndCorners(
      (Offset.zero & size).deflate(1),
      topLeft: Radius.circular(size.width / 2),
      topRight: Radius.circular(size.width / 2),
      bottomLeft: const Radius.circular(8),
      bottomRight: const Radius.circular(8),
    );
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x73FFE7A8)
      ..isAntiAlias = true;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, math.min(d + 5, m.length)), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_SlotPainter o) => false;
}
