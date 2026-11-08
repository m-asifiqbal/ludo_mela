// PieceCoin: the game piece — a thick coin with an emblem — in all its states,
// plus the move-preview ghost / tag and the hop & capture motion curves.
//
// Idle: a 22–24 pt coin with a 3 pt side band. Movable: a white dashed ring turns
// once per 2.4 s and the coin bobs (Reduce Motion: a still ring). Ghost: the
// dashed navy circle on gold that previews a destination. Stacked: two or more
// pieces on one square shrink to 86 % and show a count chip from three up.
// Shielded / frozen are the Mayhem power-card looks. Waiting players' pieces are
// never dimmed ("dim the avatar, not the pucks").
//
// The widget is a 44 pt hit box (extent) with the coin at its centre: position it
// by its centre on the board cell. Semantics: give every piece a [semanticLabel]
// ("Your piece 2, in the yard. Tap to move").

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'engine_geometry.dart';

import '../motion/motion.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'emblems.dart';
import 'piece_painter.dart';
import 'piece_skin.dart';

/// What a [PieceCoin] looks like.
enum PieceState {
  /// A plain coin.
  idle,

  /// Can move this turn: dashed ring + bob.
  movable,

  /// A destination preview (not a coin): dashed navy circle on gold.
  ghost,

  /// A Mayhem shield is up (can't be captured or swapped).
  shielded,

  /// Frozen by a Mayhem card: inside an ice block.
  frozen,
}

class PieceCoin extends StatefulWidget {
  const PieceCoin({
    super.key,
    required this.seat,
    this.size = 22,
    this.skin = PieceSkins.lotus,
    this.state = PieceState.idle,
    this.count = 1,
    this.hinted = false,
    this.mark,
    this.unit = 1,
    this.extent,
    this.semanticLabel,
    this.onTap,
  });

  /// The player colour (fixed by seat).
  final Seat seat;

  /// Coin edge in logical pt (22 on the road, 29 in the yard, 15 at home).
  final double size;
  final PieceSkin skin;
  final PieceState state;

  /// How many pieces share this square: 2+ scales the coin to 86 %, 3+ shows a chip.
  final int count;

  /// The piece the hint suggests glows teal.
  final bool hinted;

  /// Colour-blind help: a seat shape instead of the emblem.
  final SeatMark? mark;

  /// cell / 25: scales the fixed design constants (ring padding, band depth).
  final double unit;

  /// Hit box edge; defaults to 44 × [unit].
  final double? extent;
  final String? semanticLabel;

  /// Makes the coin tappable (plain tap, no sound: the screen decides).
  final VoidCallback? onTap;

  @override
  State<PieceCoin> createState() => _PieceCoinState();
}

class _PieceCoinState extends State<PieceCoin> with SingleTickerProviderStateMixin {
  /// 14.4 s = the least common multiple of the ring turn (2.4 s), the bob (0.9 s)
  /// and the shield breath (1.6 s), so the loop never jumps.
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 14400));

  bool get _animated => widget.state == PieceState.movable || widget.state == PieceState.shielded || widget.hinted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PieceCoin old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = _animated && !Motion.reduced(context);
    if (run && !_c.isAnimating) {
      _c.repeat();
    } else if (!run && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final extent = w.extent ?? 44 * w.unit;
    Widget body = SizedBox.square(
      dimension: extent,
      child: CustomPaint(
        painter: _CoinPainter(
          seat: w.seat,
          size: w.size,
          skin: w.skin,
          state: w.state,
          count: w.count,
          hinted: w.hinted,
          mark: w.mark,
          u: w.unit,
          still: Motion.reduced(context),
          clock: _c,
        ),
      ),
    );
    if (w.semanticLabel != null || w.onTap != null) {
      body = Semantics(
        button: w.onTap != null,
        label: w.semanticLabel,
        excludeSemantics: w.semanticLabel != null,
        onTap: w.onTap,
        child: w.onTap == null ? body : GestureDetector(behavior: HitTestBehavior.opaque, onTap: w.onTap, child: body),
      );
    } else {
      body = ExcludeSemantics(child: body);
    }
    return body;
  }
}

class _CoinPainter extends CustomPainter {
  _CoinPainter({
    required this.seat,
    required this.size,
    required this.skin,
    required this.state,
    required this.count,
    required this.hinted,
    required this.mark,
    required this.u,
    required this.still,
    required this.clock,
  }) : super(repaint: clock);

  final Seat seat;
  final double size;
  final PieceSkin skin;
  final PieceState state;
  final int count;
  final bool hinted;
  final SeatMark? mark;
  final double u;
  final bool still;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size box) {
    // The face sits 1 pt above the box centre: the side band makes the coin's
    // visual centre ≈ the cell centre.
    var c = Offset(box.width / 2, box.height / 2 - 1 * u);
    if (state == PieceState.ghost) {
      lmPaintTargetGhost(canvas, box.center(Offset.zero), size, u: u);
      return;
    }
    final t = still ? 0.0 : clock.value; // 0 → 1 over 14.4 s
    final colors = LmColors.seat(seat);
    final s = count > 1 ? size * .86 : size;
    if (state == PieceState.movable && !still) {
      c = c.translate(0, -4 * u * (1 - math.cos(2 * math.pi * (t * 16))) / 2); // 0.9 s bob
    }
    if (state == PieceState.shielded) lmPaintShield(canvas, c, s, u: u, phase: still ? 0 : (1 - math.cos(2 * math.pi * t * 9)) / 2);
    if (state == PieceState.movable) lmPaintMovableRing(canvas, c, s, u: u, turn: 2 * math.pi * t * 6);
    if (hinted) lmPaintHintGlow(canvas, c, s, u: u);
    lmPaintCoin(canvas, c, s, colors, skin, u: u, mark: mark);
    if (state == PieceState.frozen) lmPaintIce(canvas, c, s, u: u);
    if (count > 2) lmPaintCountChip(canvas, c.translate(s * .46, -s * .46), count, u: u);
  }

  @override
  bool shouldRepaint(_CoinPainter o) =>
      o.seat != seat ||
      o.size != size ||
      o.skin != skin ||
      o.state != state ||
      o.count != count ||
      o.hinted != hinted ||
      o.mark != mark ||
      o.u != u ||
      o.still != still;
}

/// The destination preview alone (a dashed navy circle on gold): [PieceCoin]
/// with `state: PieceState.ghost`, sized for a cell.
class TargetGhost extends StatelessWidget {
  const TargetGhost({super.key, this.size = 22, this.unit = 1});

  final double size;
  final double unit;

  @override
  Widget build(BuildContext context) => PieceCoin(seat: Seat.red, size: size, unit: unit, state: PieceState.ghost, extent: size + 6 * unit);
}

/// The CAPTURE / HOME / SAFE / RISKY pill above (or, on the top row, below) a
/// preview destination.
class MoveTag extends StatelessWidget {
  const MoveTag({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  /// Tag colours by meaning.
  static const capture = LmColors.tagCapture;
  static const home = LmColors.tagHome;
  static const safe = LmColors.tagSafe;
  static const risky = LmColors.tagRisky;

  @override
  Widget build(BuildContext context) => Container(
        height: 19,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Text(text, style: LmText.outlined(10.5, height: 1.0), maxLines: 1, softWrap: false),
      );
}

/// One frame of a piece animation: a lift (design px, up is negative), a scale
/// per axis and a rotation in radians.
class PieceFrame {
  const PieceFrame({this.dy = 0, this.sx = 1, this.sy = 1, this.turn = 0});

  final double dy;
  final double sx;
  final double sy;
  final double turn;

  /// The transform about the coin centre for a board with `unit` = cell / 25.
  Matrix4 matrix(double unit) => Matrix4.identity()
    ..translateByDouble(0.0, dy * unit, 0.0, 1.0)
    ..rotateZ(turn)
    ..scaleByDouble(sx, sy, 1.0, 1.0);
}

/// The motion curves of the Motion board, as pure functions of t ∈ [0, 1] so a
/// screen can drive them with any controller (and tests can sample them).
abstract final class PieceMotion {
  static double _seg(double t, double a, double b) => Motion.standardCurve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// One square hop (170 ms): arc 13 pt, squash .9 / 1.12 at the top, land 1.14 / .84.
  static PieceFrame hop(double t) {
    if (t <= .45) {
      final k = _seg(t, 0, .45);
      return PieceFrame(dy: _lerp(0, -13, k), sx: _lerp(1, .9, k), sy: _lerp(1, 1.12, k));
    }
    if (t <= .85) {
      final k = _seg(t, .45, .85);
      return PieceFrame(dy: _lerp(-13, 0, k), sx: _lerp(.9, 1.14, k), sy: _lerp(1.12, .84, k));
    }
    final k = _seg(t, .85, 1);
    return PieceFrame(sx: _lerp(1.14, 1, k), sy: _lerp(.84, 1, k));
  }

  /// A captured piece (760 ms): swells to 1.5 while spinning, then spins 720° home.
  static PieceFrame knock(double t) {
    if (t <= .3) {
      final k = _seg(t, 0, .3);
      final s = _lerp(1, 1.5, k);
      return PieceFrame(sx: s, sy: s, turn: lmRad(_lerp(0, 180, k)));
    }
    final k = _seg(t, .3, 1);
    final s = _lerp(1.5, 1, k);
    return PieceFrame(sx: s, sy: s, turn: lmRad(_lerp(180, 720, k)));
  }

  /// Leaving the yard (260 ms): pops from 40 % with the spring.
  static PieceFrame pop(double t) {
    final k = Motion.popCurve.transform(t.clamp(0.0, 1.0));
    final s = _lerp(.4, 1, k);
    return PieceFrame(sx: s, sy: s);
  }
}
