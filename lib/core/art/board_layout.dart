// BoardLayout: every measurement of a drawn board and the maps between the
// engine's grid and screen points (design board A §6).
//
// One rule sizes the board on any phone: C = ⌊(width − 10) ÷ 15⌋ points per
// square with a 5 pt wooden frame, so the 390 pt reference phone gets
// 15 × 25 + 2 × 5 = 385. Everything else is a multiple of C: a drawn square is
// C − 1 at +0.5 (1 pt of grey grid shows between squares), a yard is 6 C, the
// darker inner yard square is 4.72 C at +0.64 C, the centre is 3 C.
//
// Mini boards (Collection cards, the lobby PLAY tile) use [BoardLayout.scaled]:
// the same drawing scaled proportionally instead of snapped to whole points.
//
// Coordinates here are relative to the board's top-left corner (the frame's
// outer edge). [centerOf] / [pieceCenter] give the centre of a square, which is
// where a piece's hit box is centred (the coin's face sits 1 pt above it).

import 'dart:math' as math;
import 'dart:ui';

import 'engine_geometry.dart';

/// What a piece is standing on, for sizing: the road, its yard spot, a stack or home.
enum PieceSpot { road, yard, stacked, home }

class BoardLayout {
  const BoardLayout._(this.size, this.frame, this.cell, [this._frameRadius, this._innerRadius, this._lip]);

  /// The full-size board for a [width] (e.g. 385 on a 390 pt phone): whole-point
  /// squares and a 5 pt frame. The board is `15 C + 10` wide (≤ [width]).
  factory BoardLayout.forWidth(double width) {
    final c = math.max(1.0, ((width - 10) / 15).floorToDouble());
    return BoardLayout._(15 * c + 10, 5, c);
  }

  /// The 385 pt drawing scaled to exactly [width] (previews and tilted tiles).
  factory BoardLayout.scaled(double width) {
    final k = width / 385;
    return BoardLayout._(width, 5 * k, 25 * k);
  }

  /// A small illustration of the board (Collection card, lobby PLAY tile): a
  /// chunkier frame, rounder corners and a deeper lip than the scaled-down match
  /// board, so it still reads as a wooden board at 80 – 120 pt.
  factory BoardLayout.mini(double width) {
    final f = width * .04;
    return BoardLayout._(width, f, (width - 2 * f) / 15, width * .09, width * .055, width * .06);
  }

  final double? _frameRadius;
  final double? _innerRadius;
  final double? _lip;

  /// Outer edge of the board (frame included).
  final double size;

  /// Thickness of the wooden frame.
  final double frame;

  /// C: the size of one square.
  final double cell;

  /// cell / 25: scales every fixed design constant (coin sizes, shadows).
  double get unit => cell / 25;

  /// The 15 C square inside the frame.
  Rect get inner => Rect.fromLTWH(frame, frame, 15 * cell, 15 * cell);

  Rect get bounds => Rect.fromLTWH(0, 0, size, size);

  /// Frame corner radius (16 at C = 25) and the inner board's (11).
  double get frameRadius => _frameRadius ?? 16 * unit;
  double get innerRadius => _innerRadius ?? 11 * unit;

  /// The lip depth under the frame when this layout overrides the skin's (mini boards).
  double? get lipOverride => _lip;

  /// The square (row, col) as drawn: C − 1 at +0.5 (scaled).
  Rect cellRect(int row, int col) {
    final k = unit;
    return Rect.fromLTWH(frame + col * cell + .5 * k, frame + row * cell + .5 * k, cell - k, cell - k);
  }

  /// The full 6 C yard square of the seat's corner.
  Rect yardRect(Seat seat) {
    final o = Board.yardOrigin(seat);
    return Rect.fromLTWH(frame + o.$2 * cell, frame + o.$1 * cell, 6 * cell, 6 * cell);
  }

  /// The darker inner yard square (118 of 150 at +16, radius 18).
  Rect yardInnerRect(Seat seat) {
    final y = yardRect(seat);
    final k = unit;
    return Rect.fromLTWH(y.left + 16 * k, y.top + 16 * k, 118 * k, 118 * k);
  }

  /// The centre 3 C square holding the four home triangles.
  Rect get centerRect => Rect.fromLTWH(frame + 6 * cell, frame + 6 * cell, 3 * cell, 3 * cell);

  /// Centre of a (possibly fractional) grid point, in board coordinates.
  Offset centerOf(GridPoint p) => Offset(frame + (p.col + .5) * cell, frame + (p.row + .5) * cell);

  /// Centre of the whole square (row, col).
  Offset centerOfCell(int row, int col) => Offset(frame + (col + .5) * cell, frame + (row + .5) * cell);

  /// Where the piece [piece] of [seat] at [progress] stands (engine progress).
  Offset pieceCenter(Seat seat, int progress, int piece) => centerOf(Board.cellOf(seat, progress, piece));

  /// The grid point under [p] (inverse of [centerOf]; fractional).
  GridPoint pointAt(Offset p) => GridPoint((p.dy - frame) / cell - .5, (p.dx - frame) / cell - .5);

  /// The whole square containing [p], or null outside the 15 × 15 grid.
  ({int row, int col})? cellAt(Offset p) {
    final r = ((p.dy - frame) / cell).floor();
    final c = ((p.dx - frame) / cell).floor();
    if (r < 0 || c < 0 || r >= Board.gridSize || c >= Board.gridSize) return null;
    return (row: r, col: c);
  }

  /// Coin edge for a piece on [spot]: 22 on the road, 29 in the yard, 19 in a
  /// stack, 15 at home (at C = 25).
  double pieceSize(PieceSpot spot) => unit *
      switch (spot) {
        PieceSpot.road => 22,
        PieceSpot.yard => 29,
        PieceSpot.stacked => 19,
        PieceSpot.home => 15,
      };

  /// Horizontal offsets of [n] pieces sharing a square (±8 pt steps, centred).
  List<double> stackOffsets(int n) => [for (var j = 0; j < n; j++) n > 1 ? (j - (n - 1) / 2) * 8 * unit : 0.0];

  /// The hit box edge of a piece (44 pt minimum tap target at C = 25).
  double get hitSize => 44 * unit;

  /// The centre of a move tag for a destination at [dest]: clamped inside the
  /// board and flipped below the square on the top row.
  Offset tagAnchor(Offset dest) {
    final x = math.min(math.max(dest.dx, frame + 30 * unit), size - frame - 30 * unit);
    final above = dest.dy - frame >= 40 * unit;
    return Offset(x, above ? dest.dy - 33 * unit + 9.5 * unit : dest.dy + 13 * unit + 9.5 * unit);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardLayout && other.size == size && other.frame == frame && other.cell == cell && other._lip == _lip && other._frameRadius == _frameRadius;

  @override
  int get hashCode => Object.hash(size, frame, cell, _lip, _frameRadius);

  @override
  String toString() => 'BoardLayout(size: $size, cell: $cell, frame: $frame)';
}

/// Bearing in degrees (0 = east, clockwise on screen) from loop square [g] to
/// the next one: the direction a Mayhem arrow tile points.
double loopHeading(int g) {
  final a = Board.track[g % Board.loopLength];
  final b = Board.track[(g + 1) % Board.loopLength];
  return math.atan2((b.$1 - a.$1).toDouble(), (b.$2 - a.$2).toDouble()) * 180 / math.pi;
}
