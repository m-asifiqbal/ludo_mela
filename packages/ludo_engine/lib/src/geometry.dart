// Board geometry: the 15 × 15 grid, the 52-square loop, the four home lanes,
// yards and goals, and the special squares. Pure numbers, shared by the rules
// (which only think in "progress" per piece) and the app's board painter
// (which needs grid cells to draw and animate on).
//
// Why one place: the painter, the hop animation, tap targets, the puzzle
// generator and the bots must agree on every square. Coordinates here are the
// ones on the design board (design/artboards/project/Match.dc.html).
//
// Orientation (as drawn, row 0 at the top):
//   green yard top-left · yellow yard top-right
//   red yard bottom-left · blue yard bottom-right
// Pieces travel clockwise; turn order is clockwise too: red → green → yellow → blue.

/// A player colour and corner of the board, in clockwise turn order.
enum Seat {
  red,
  green,
  yellow,
  blue;

  /// The next seat clockwise.
  Seat get next => Seat.values[(index + 1) % 4];

  /// The seat across the board (partner in Teams).
  Seat get opposite => Seat.values[(index + 2) % 4];
}

/// A grid cell (row, col). Fractional values are used for spots inside
/// yards and the goal triangle; loop and lane cells are whole numbers.
class GridPoint {
  const GridPoint(this.row, this.col);
  final double row;
  final double col;

  @override
  bool operator ==(Object other) => other is GridPoint && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
  @override
  String toString() => 'GridPoint($row, $col)';
}

/// Static board facts. "Progress" is a piece's distance along its own route:
///   [yard] (-1)  in the yard;
///   0 … 50       on the shared loop (0 = its start square);
///   51 … 55      in its home lane (5 squares);
///   56 ([home])  finished, in the centre.
abstract final class Board {
  static const gridSize = 15;
  static const loopLength = 52;
  static const yard = -1;
  static const lastLoop = 50;
  static const firstLane = 51;
  static const laneLength = 5;
  static const home = 56;
  static const piecesPerSeat = 4;

  /// A seventh position code, used only by the Master rule "capture before
  /// the lane": a piece that may not turn into its lane keeps circling, and
  /// the one loop square that has no code of its own (the square just before its
  /// own start, loop index start + 51) is written [wrap]. From [wrap] a roll of
  /// r lands on progress r - 1 (r = 1 is its own start square).
  static const wrap = 57;

  /// The 52 loop squares in travel order; index 0 is red's start square.
  static const List<(int, int)> track = [
    (13, 6),
    (12, 6),
    (11, 6),
    (10, 6),
    (9, 6),
    (8, 5),
    (8, 4),
    (8, 3),
    (8, 2),
    (8, 1),
    (8, 0),
    (7, 0),
    (6, 0),
    (6, 1),
    (6, 2),
    (6, 3),
    (6, 4),
    (6, 5),
    (5, 6),
    (4, 6),
    (3, 6),
    (2, 6),
    (1, 6),
    (0, 6),
    (0, 7),
    (0, 8),
    (1, 8),
    (2, 8),
    (3, 8),
    (4, 8),
    (5, 8),
    (6, 9),
    (6, 10),
    (6, 11),
    (6, 12),
    (6, 13),
    (6, 14),
    (7, 14),
    (8, 14),
    (8, 13),
    (8, 12),
    (8, 11),
    (8, 10),
    (8, 9),
    (9, 8),
    (10, 8),
    (11, 8),
    (12, 8),
    (13, 8),
    (14, 8),
    (14, 7),
    (14, 6),
  ];

  /// Loop index of each seat's start square (progress 0). Starts are safe.
  static int startIndex(Seat s) => const [0, 13, 26, 39][s.index];

  /// Loop index of the square a seat turns off into its lane from (progress 50).
  static int entryIndex(Seat s) => (startIndex(s) + lastLoop) % loopLength;

  /// The star squares (safe for everyone).
  static const stars = [8, 21, 34, 47];

  /// Every safe loop square: the four starts and the four stars.
  static const safeSquares = [0, 8, 13, 21, 26, 34, 39, 47];

  static bool isSafeLoopIndex(int loopIndex) => safeSquares.contains(loopIndex);

  /// True when [progress] puts a piece on the shared loop (0 … 50, or [wrap]).
  static bool onLoop(int progress) => (progress >= 0 && progress <= lastLoop) || progress == wrap;

  /// True when [progress] is one of the five home-lane squares.
  static bool inLane(int progress) => progress >= firstLane && progress < home;

  /// Loop index for [seat] at [progress], or -1 when the piece is not on the
  /// loop (yard, lane or home). Unlike [loopIndexOf] it never asserts and it
  /// understands [wrap].
  static int loopIndexOrNone(Seat seat, int progress) {
    if (progress >= 0 && progress <= lastLoop) return (startIndex(seat) + progress) % loopLength;
    if (progress == wrap) return (startIndex(seat) + lastLoop + 1) % loopLength;
    return -1;
  }

  /// Home lane cells per seat, from the first lane square (progress 51) inwards.
  static List<(int, int)> lane(Seat s) => const [
    [(13, 7), (12, 7), (11, 7), (10, 7), (9, 7)],
    [(7, 1), (7, 2), (7, 3), (7, 4), (7, 5)],
    [(1, 7), (2, 7), (3, 7), (4, 7), (5, 7)],
    [(7, 13), (7, 12), (7, 11), (7, 10), (7, 9)],
  ][s.index];

  /// Top-left cell of each seat's 6 × 6 yard.
  static (int, int) yardOrigin(Seat s) => const [(9, 0), (0, 0), (0, 9), (9, 9)][s.index];

  /// The goal cell of each seat (the centre triangle that faces its lane).
  static (int, int) goalCell(Seat s) => const [(8, 7), (7, 6), (6, 7), (7, 8)][s.index];

  /// Where the four pieces rest inside the yard, in cells from the yard origin
  /// (the centres of the darker inner square's quarters).
  static const yardSpots = [(1.7, 1.7), (1.7, 3.3), (3.3, 1.7), (3.3, 3.3)];

  /// Small offsets so finished pieces don't sit exactly on top of each other.
  static const goalSpots = [(-0.3, -0.3), (-0.3, 0.3), (0.3, -0.3), (0.3, 0.3)];

  /// Clockwise rotation of each seat's lane arrow / goal triangle, in degrees.
  static int seatRotation(Seat s) => const [0, 90, 180, 270][s.index];

  /// Loop index for [seat] at [progress] (0 … 50). Throws for lane/yard/home.
  static int loopIndexOf(Seat seat, int progress) {
    assert(progress >= 0 && progress <= lastLoop, 'progress $progress is not on the loop');
    return (startIndex(seat) + progress) % loopLength;
  }

  /// Progress of [seat] at [loopIndex] (the inverse of [loopIndexOf]).
  static int progressAt(Seat seat, int loopIndex) => (loopIndex - startIndex(seat) + loopLength) % loopLength;

  /// The cell a piece occupies. [piece] (0 … 3) picks its yard spot or goal
  /// offset; on the loop and in the lane every piece of a seat shares the cell.
  static GridPoint cellOf(Seat seat, int progress, int piece) {
    if (progress == wrap) {
      final c = track[loopIndexOrNone(seat, wrap)];
      return GridPoint(c.$1.toDouble(), c.$2.toDouble());
    }
    if (progress == yard) {
      final o = yardOrigin(seat);
      final s = yardSpots[piece];
      return GridPoint(o.$1 + s.$1, o.$2 + s.$2);
    }
    if (progress <= lastLoop) {
      final c = track[loopIndexOf(seat, progress)];
      return GridPoint(c.$1.toDouble(), c.$2.toDouble());
    }
    if (progress < home) {
      final c = lane(seat)[progress - firstLane];
      return GridPoint(c.$1.toDouble(), c.$2.toDouble());
    }
    final g = goalCell(seat);
    final o = goalSpots[piece];
    return GridPoint(g.$1 + o.$1, g.$2 + o.$2);
  }

  /// Cells visited when a piece moves from [from] to [to] (exclusive of
  /// [from], inclusive of [to]) — the hop animation path. Leaving the yard
  /// is a single step onto the start square. Assumes progress only counts up:
  /// for a legal move (Master's circling, an arrow) use `Move.path` instead.
  static List<GridPoint> path(Seat seat, int from, int to, int piece) {
    if (from == yard) return [cellOf(seat, 0, piece)];
    return [for (var p = from + 1; p <= to; p++) cellOf(seat, p, piece)];
  }

  // ── Mela Mayhem tiles (loop indices; none is a start or a star) ─────────

  /// Arrow tiles: land exactly and zip 4 squares ahead.
  static const arrowTiles = [3, 16, 29, 42];

  /// How far an arrow zips.
  static const arrowZip = 4;

  /// Power tiles: land to draw a power card.
  static const powerTiles = [6, 11, 19, 24, 32, 37, 45, 50];

  /// Chest tiles: land for 50–300 coins (kept only if you finish the match).
  static const chestTiles = [30, 4];
}
