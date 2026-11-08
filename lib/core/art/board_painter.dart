// BoardPainter: draws the whole board — wooden frame, grey grid, flat yards with
// darker inner squares, the 52-square loop, the home lanes and the four flat
// home triangles — from a BoardSkin and a BoardLayout (board A §6, Match.png).
//
// The board is static, so it is recorded once into a `ui.Picture` per skin +
// size + option set ([BoardPictureCache]) and every frame only replays it; the
// pieces, tags and bursts are widgets on top (see BoardView). Squares are C − 1
// at +0.5 so 1 pt of grey grid shows between them; start squares are the seat
// colour with a darker star, safe squares #CFCFCF with a grey star, and the
// square before each lane carries an arrow in the seat colour pointing home.
//
// Options: the Mela Mayhem tile overlay (arrow / power / chest tiles), the
// colour-blind marks (● ▲ ■ ◆ on yards and lanes) and the star squares (the
// Monsoon event moves them one square at a time).

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'engine_geometry.dart';

import '../theme/box_paint.dart';
import 'board_layout.dart';
import 'board_skin.dart';
import 'emblems.dart';
import 'glyph.dart';

/// What to draw on top of the plain board.
class BoardPaintOptions {
  const BoardPaintOptions({
    this.mayhem = false,
    this.patterns = false,
    this.stars = Board.stars,
    this.powerIcons = true,
  });

  /// Arrow, power and chest tiles of Mela Mayhem.
  final bool mayhem;

  /// Colour-blind marks on yards and lanes.
  final bool patterns;

  /// Loop indices drawn as star (safe) squares; the four starts are always safe.
  final List<int> stars;

  /// Draw the lightning bolts of power tiles (false when an animated overlay draws them).
  final bool powerIcons;

  String get key => '${mayhem ? 'M' : '-'}${patterns ? 'P' : '-'}${powerIcons ? 'I' : '-'}${stars.join(',')}';

  @override
  bool operator ==(Object other) => other is BoardPaintOptions && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

const _lipLight = Color(0x80FFFFFF);

/// Paints the board described by [skin] into [canvas] at [l] (origin = the
/// board's top-left; shadows spill outside [BoardLayout.bounds]).
void paintBoard(Canvas canvas, BoardLayout l, BoardSkin skin, [BoardPaintOptions o = const BoardPaintOptions()]) {
  final k = l.unit;
  _paintFrame(canvas, l, skin);

  final inner = RRect.fromRectAndRadius(l.inner, Radius.circular(l.innerRadius));
  canvas.drawRRect(inner.inflate(1.5 * k), Paint()..color = skin.frameRim ?? skin.frameLine..isAntiAlias = true);
  canvas.drawRRect(inner, Paint()..color = skin.ground..isAntiAlias = true);
  canvas.save();
  canvas.clipRRect(inner);

  for (final seat in Seat.values) {
    final c = skin.seat(seat);
    canvas.drawRect(l.yardRect(seat), Paint()..color = c.main);
    lmPaintBox(
      canvas,
      RRect.fromRectAndRadius(l.yardInnerRect(seat), Radius.circular(18 * k)),
      color: c.dark,
      shadows: [LmShadow(const Color(0x2E000000), dy: 3 * k, blur: 5 * k, inset: true), LmShadow(const Color(0x40FFFFFF), dy: 1 * k)],
    );
    if (o.patterns) {
      SeatMark.forSeatIndex(seat.index).paint(canvas, l.yardInnerRect(seat).center, 1.1 * l.cell, fill: const Color(0x2EFFFFFF));
    }
  }

  // The 52-square loop.
  for (var g = 0; g < Board.loopLength; g++) {
    final (row, col) = Board.track[g];
    final r = l.cellRect(row, col);
    final startSeat = g % 13 == 0 ? Seat.values[g ~/ 13] : null;
    final isStar = startSeat == null && o.stars.contains(g);
    final Color fill = startSeat != null ? skin.seat(startSeat).main : (isStar ? skin.safeCell : skin.cell);
    final special = o.mayhem && startSeat == null && !isStar && _mayhemTile(canvas, r, g, k, o);
    if (!special) {
      canvas.drawRect(r, Paint()..color = fill);
      if (skin.cellEdge != null) _edge(canvas, r, skin.cellEdge!, k);
    }
    if (startSeat != null) {
      _icon(canvas, LmEmblems.boardStar, r, skin.seat(startSeat).dark, k);
    } else if (isStar) {
      _icon(canvas, LmEmblems.boardStar, r, skin.safeStar, k);
    } else if (!special) {
      for (final seat in Seat.values) {
        if (Board.entryIndex(seat) == g) _icon(canvas, LmEmblems.laneArrow, r, skin.seat(seat).main, k, rotation: Board.seatRotation(seat).toDouble());
      }
    }
  }

  // Home lanes: the seat colour, 5 squares each.
  for (final seat in Seat.values) {
    final c = skin.seat(seat);
    for (final (row, col) in Board.lane(seat)) {
      final r = l.cellRect(row, col);
      canvas.drawRect(r, Paint()..color = c.main);
      if (o.patterns) SeatMark.forSeatIndex(seat.index).paint(canvas, r.center, .26 * l.cell, fill: c.dark.withValues(alpha: .6));
    }
  }

  _paintCenter(canvas, l, skin);
  canvas.restore();
}

void _paintFrame(Canvas canvas, BoardLayout l, BoardSkin skin) {
  final k = l.unit;
  final outer = RRect.fromRectAndRadius(l.bounds, Radius.circular(l.frameRadius));
  final colors = skin.frameMid == null ? [skin.frameHi, skin.frameLo] : [skin.frameHi, skin.frameMid!, skin.frameLo];
  final gradient = LmGradient(colors, stops: skin.frameMid == null ? null : const [0, .45, 1], angle: skin.frameAngle);
  final rim = skin.frameRim;
  lmPaintBox(canvas, outer, gradient: gradient, shadows: [
    LmShadow.rim(rim ?? skin.frameLine, (rim != null ? 2 : 1.5) * k),
    LmShadow(rim != null ? const Color(0x59FFFFFF) : _lipLight, dy: (rim != null ? 3 : 2) * k, inset: true),
    if (rim != null) LmShadow(const Color(0x40000000), dy: -3 * k, inset: true),
    LmShadow(skin.frameLip, dy: l.lipOverride ?? skin.frameLipDepth * k),
    LmShadow(const Color(0x73001428), dy: (rim != null ? 18 : 12) * k, blur: (rim != null ? 30 : 20) * k),
  ]);
}

void _edge(Canvas canvas, Rect r, Color c, double k) => canvas.drawRect(
      r.deflate(.5 * k),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = k
        ..color = c,
    );

/// Draws a 24-box [d] icon 17 k wide centred in [cell], rotated by [rotation]°.
void _icon(Canvas canvas, String d, Rect cell, Color color, double k, {double rotation = 0, bool stroke = false, Color? ink, double strokeWidth = 1.6}) {
  final s = 17 * k;
  canvas.save();
  canvas.translate(cell.center.dx, cell.center.dy);
  if (rotation != 0) canvas.rotate(rotation * math.pi / 180);
  canvas.scale(s / 24);
  canvas.translate(-12, -12);
  final path = lmParsePath(d);
  if (stroke) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color
        ..isAntiAlias = true,
    );
  } else {
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
    if (ink != null) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = ink
          ..isAntiAlias = true,
      );
    }
  }
  canvas.restore();
}

/// Paints the Mayhem tile at loop square [g] (if it is one) and returns true.
bool _mayhemTile(Canvas canvas, Rect r, int g, double k, BoardPaintOptions o) {
  Paint grad(Color a, Color b) => Paint()..shader = LmGradient([a, b]).shader(r);
  if (Board.arrowTiles.contains(g)) {
    canvas.drawRect(r, grad(const Color(0xFFFFEC8F), const Color(0xFFF59E00)));
    _icon(canvas, LmEmblems.chevrons, r, const Color(0xFF5A2E00), k, rotation: loopHeading(g), stroke: true);
    return true;
  }
  if (Board.powerTiles.contains(g)) {
    canvas.drawRect(r, grad(const Color(0xFFD9B8FF), const Color(0xFF8B55F0)));
    if (o.powerIcons) _icon(canvas, LmEmblems.bolt, r, const Color(0xFFFFFFFF), k, ink: const Color(0xFF3E1A8E));
    return true;
  }
  if (Board.chestTiles.contains(g)) {
    canvas.drawRect(r, grad(const Color(0xFFFFE27A), const Color(0xFFE89A00)));
    _icon(canvas, LmEmblems.chest, r, const Color(0xFFB5651D), k, ink: const Color(0xFF5A2E05));
    return true;
  }
  return false;
}

void _paintCenter(Canvas canvas, BoardLayout l, BoardSkin skin) {
  final r = l.centerRect;
  final c = r.center;
  Path tri(Offset a, Offset b) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..close();
  final parts = <(Seat, Path)>[
    (Seat.yellow, tri(r.topLeft, r.topRight)),
    (Seat.blue, tri(r.topRight, r.bottomRight)),
    (Seat.red, tri(r.bottomLeft, r.bottomRight)),
    (Seat.green, tri(r.topLeft, r.bottomLeft)),
  ];
  canvas.save();
  canvas.clipRect(r);
  for (final (seat, path) in parts) {
    final color = skin.seat(seat).main;
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
    // A hair of overlap hides the anti-aliasing seam between triangles.
    canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..strokeWidth = .6 * l.unit..color = color..isAntiAlias = true);
  }
  canvas.restore();
  final e = skin.centerEmblem;
  if (e != null) {
    final s = 1.3 * l.cell;
    for (final pass in [0, 1]) {
      canvas.save();
      canvas.translate(c.dx - s / 2, c.dy - s / 2 + (pass == 0 ? l.unit : 0));
      canvas.scale(s / 24);
      canvas.drawPath(
        lmParsePath(e),
        Paint()
          ..color = pass == 0 ? const Color(0x59000000) : skin.centerEmblemColor.withValues(alpha: .95)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }
  }
}

/// Recorded boards, one per skin + size + options (small LRU).
abstract final class BoardPictureCache {
  static final Map<String, Picture> _cache = {};

  static Picture get(BoardSkin skin, BoardLayout l, BoardPaintOptions o) {
    final key = '${skin.id}|${l.size}|${l.cell}|${l.frame}|${l.lipOverride}|${o.key}';
    var p = _cache.remove(key);
    if (p == null) {
      if (_cache.length >= 16) _cache.remove(_cache.keys.first);
      final rec = PictureRecorder();
      paintBoard(Canvas(rec, l.bounds.inflate(48 * l.unit)), l, skin, o);
      p = rec.endRecording();
    }
    _cache[key] = p; // most recently used goes last
    return p;
  }

  /// Number of cached pictures (tests).
  static int get length => _cache.length;

  static void clear() => _cache.clear();
}

/// Replays the cached board picture; repaints only when the skin, size or
/// options change.
class BoardPainter extends CustomPainter {
  const BoardPainter(this.skin, this.layout, [this.options = const BoardPaintOptions()]);

  final BoardSkin skin;
  final BoardLayout layout;
  final BoardPaintOptions options;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPicture(BoardPictureCache.get(skin, layout, options));

  @override
  bool shouldRepaint(BoardPainter o) => o.skin != skin || o.layout != layout || o.options != options;
}

/// The pulsing lightning bolts of Mayhem power tiles (1.4 s: scale 1 → 1.2 and
/// 10° of turn at the midpoint). [t] is 0 – 1 over one loop.
class PowerSparkPainter extends CustomPainter {
  PowerSparkPainter(this.layout, this.t, {super.repaint});

  final BoardLayout layout;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final k = layout.unit;
    final e = Curves.easeInOut.transform((1 - math.cos(2 * math.pi * t)) / 2);
    for (final g in Board.powerTiles) {
      final (row, col) = Board.track[g];
      final r = layout.cellRect(row, col);
      canvas.save();
      canvas.translate(r.center.dx, r.center.dy);
      canvas.rotate(10 * e * math.pi / 180);
      canvas.scale((1 + .2 * e) * 17 * k / 24);
      canvas.translate(-12, -12);
      final path = lmParsePath(LmEmblems.bolt);
      canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF)..isAntiAlias = true);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..color = const Color(0xFF3E1A8E)
          ..isAntiAlias = true,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PowerSparkPainter o) => o.t != t || o.layout != layout;
}
