// Puzzle scenario proposals: random-but-deterministic positions for each goal.
//
// Each function builds one *candidate* from a seeded random stream: it picks the
// dice, lays out the red pieces and the rivals so that a particular play is meant to
// win, and puts rival pieces where they threaten the squares the other plays would
// stop on. A candidate is only a proposal — daily_puzzle.dart solves it (the real
// engine rules, every play) and keeps it only if it is solvable and not solved by
// most plays — so a proposal never has to be perfect, just often good.
//
// The board is the design's: red (the player) at the bottom with its pieces in the
// yard, home or on the loop, and green / yellow / blue rivals. Red's progress equals
// its loop index (red starts on loop square 0), which keeps the arithmetic readable.

import '../config/match_config.dart';
import '../geometry.dart';
import '../state/game_state.dart';
import 'puzzle.dart';

/// SplitMix64, the same recipe as `SeededDice`, giving ints instead of dice — identical
/// on every device, so every phone builds the same puzzle for a day.
class PuzzleRng {
  PuzzleRng(this._state);

  int _state;

  /// 0 … [max] - 1.
  int nextInt(int max) {
    _state += 0x9E3779B97F4A7C15;
    var z = _state;
    z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
    z ^= z >>> 31;
    return (z >>> 1) % max;
  }

  /// True with probability [percent] / 100.
  bool chance(int percent) => nextInt(100) < percent;

  T pick<T>(List<T> items) => items[nextInt(items.length)];

  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = items[i];
      items[i] = items[j];
      items[j] = t;
    }
  }
}

const List<Seat> _rivals = [Seat.green, Seat.yellow, Seat.blue];

/// The four seats' pieces while a position is being laid out. A square a piece stands
/// on is refused when it is a non-safe loop square held by another seat (an illegal board).
class _Layout {
  _Layout() : pieces = {for (final s in Seat.values) s: List.filled(4, Board.yard)};

  final Map<Seat, List<int>> pieces;
  final Map<int, Seat> _held = {};

  bool put(Seat seat, int piece, int progress) {
    final idx = Board.loopIndexOrNone(seat, progress);
    if (idx >= 0 && !Board.isSafeLoopIndex(idx)) {
      final holder = _held[idx];
      if (holder != null && holder != seat) return false;
      _held[idx] = seat;
    }
    pieces[seat]![piece] = progress;
    return true;
  }

  /// Puts [seat]'s next yard piece at [progress] (false when the seat has none left or the square is taken).
  bool putNext(Seat seat, int progress) {
    final slot = pieces[seat]!.indexOf(Board.yard);
    if (slot < 0) return false;
    final ok = put(seat, slot, progress);
    if (!ok) pieces[seat]![slot] = Board.yard;
    return ok;
  }

  /// Puts a rival piece on loop square [loopIndex], reachable from there for [room] more squares.
  bool putAtLoop(PuzzleRng rng, int loopIndex, {int room = 0}) {
    final seats = [..._rivals];
    rng.shuffle(seats);
    for (final s in seats) {
      final q = (loopIndex - Board.startIndex(s) + Board.loopLength) % Board.loopLength;
      if (q >= 1 && q + room <= Board.lastLoop && putNext(s, q)) return true;
    }
    return false;
  }

  /// Puts a rival piece 1–6 squares behind loop square [loopIndex] so it can hit it. Tries a few random seats and distances.
  bool threaten(PuzzleRng rng, int loopIndex) {
    for (var attempt = 0; attempt < 10; attempt++) {
      final s = rng.pick(_rivals);
      final d = 1 + rng.nextInt(6);
      final src = (loopIndex - d + Board.loopLength) % Board.loopLength;
      final q = (src - Board.startIndex(s) + Board.loopLength) % Board.loopLength;
      if (q + d <= Board.lastLoop && putNext(s, q)) return true;
    }
    return false;
  }

  /// A few rival pieces that matter little: home, in a yard, or somewhere on the loop.
  void clutter(PuzzleRng rng) {
    for (var n = rng.nextInt(3); n > 0; n--) {
      final s = rng.pick(_rivals);
      final roll = rng.nextInt(10);
      putNext(s, roll < 3 ? Board.home : (roll < 6 ? Board.yard : rng.nextInt(Board.lastLoop + 1)));
    }
  }

  GameState state() => puzzleBoard(pieces);
}

/// The daily board: four seats, red to play, no roll-off, pieces as given.
GameState puzzleBoard(Map<Seat, List<int>> pieces) {
  final config = MatchConfig.generic(count: 4, firstSeat: Seat.red);
  return GameState.initial(config).copyWith(pieces: pieces, rollOff: null, firstSeat: Seat.red);
}

/// A puzzle on the daily board from explicit piece positions (curated puzzles, tests).
Puzzle buildPuzzle({
  required int number,
  required Map<Seat, List<int>> pieces,
  required List<int> rolls,
  required PuzzleGoal goal,
  int heroPiece = 0,
}) => Puzzle(number: number, start: puzzleBoard(pieces), hero: Seat.red, heroPiece: heroPiece, rolls: rolls, goal: goal);

/// [n] dice (1 … 6) that sum to [total].
List<int> _split(PuzzleRng rng, int n, int total) {
  final out = <int>[];
  var left = total;
  for (var i = 0; i < n - 1; i++) {
    final rest = n - 1 - i;
    final lo = (left - 6 * rest).clamp(1, 6);
    final hi = (left - rest).clamp(1, 6);
    final v = lo + rng.nextInt(hi - lo + 1);
    out.add(v);
    left -= v;
  }
  out.add(left);
  return out;
}

/// The sums of every non-empty proper subset of [dice] — the squares (from the start) a
/// single piece could stop on while it still has a roll to play.
Set<int> _stopSums(List<int> dice) {
  final sums = <int>{};
  for (var mask = 1; mask < (1 << dice.length) - 1; mask++) {
    var s = 0;
    for (var i = 0; i < dice.length; i++) {
      if ((mask >> i) & 1 == 1) s += dice[i];
    }
    sums.add(s);
  }
  return sums;
}

bool _plainSquare(int loopIndex) => loopIndex >= 1 && loopIndex <= Board.lastLoop && !Board.isSafeLoopIndex(loopIndex);

Puzzle _make(int number, _Layout layout, List<int> rolls, PuzzleGoal goal, PuzzleRng rng) {
  final shown = List.of(rolls);
  rng.shuffle(shown);
  return Puzzle(number: number, start: layout.state(), hero: Seat.red, heroPiece: 0, rolls: shown, goal: goal);
}

/// Home in three rolls without ever stopping where a rival can hit: the design's puzzle.
Puzzle? proposeHomeSafe(PuzzleRng rng, int number) {
  final total = 8 + rng.nextInt(10); // squares to go: 8 … 17
  final dice = _split(rng, 3, total);
  final h = Board.home - total;
  final order = [0, 1, 2];
  rng.shuffle(order);
  final winStops = {h + dice[order[0]], h + dice[order[0]] + dice[order[1]]};
  final layout = _Layout()..put(Seat.red, 0, h);
  for (var i = 1; i < 4; i++) {
    layout.put(Seat.red, i, rng.chance(50) ? Board.home : Board.yard);
  }
  for (final s in _stopSums(dice)) {
    final stop = h + s;
    if (winStops.contains(stop) || !_plainSquare(stop)) continue;
    if (rng.chance(85)) layout.threaten(rng, stop);
  }
  layout.clutter(rng);
  return _make(number, layout, dice, const PuzzleGoal(PuzzleGoalKind.homeSafe), rng);
}

/// Capture a rival on the way and finish where nobody can hit the piece: the rival that
/// threatens the finishing square must be the one that is captured.
Puzzle? proposeCaptureSafe(PuzzleRng rng, int number) {
  const n = 3; // three rolls, like the design: two would leave only a coin flip
  final dice = [for (var i = 0; i < n; i++) 1 + rng.nextInt(6)];
  final total = dice.fold(0, (a, b) => a + b);
  final order = List.generate(n, (i) => i);
  rng.shuffle(order);
  final j = 1 + rng.nextInt(n - 1); // rolls played before the capture
  var prefix = 0;
  for (var i = 0; i < j; i++) {
    prefix += dice[order[i]];
  }
  final rest = total - prefix;
  if (rest < 1 || rest > 6 || 49 - total < 1) return null;
  final h = 1 + rng.nextInt(49 - total);
  final capture = h + prefix;
  final finish = h + total;
  if (!_plainSquare(capture) || !_plainSquare(finish)) return null;
  final layout = _Layout()..put(Seat.red, 0, h);
  for (var i = 1; i < 4; i++) {
    layout.put(Seat.red, i, rng.chance(50) ? Board.home : Board.yard);
  }
  if (!layout.putAtLoop(rng, capture, room: rest)) return null;
  layout.clutter(rng);
  return _make(number, layout, dice, const PuzzleGoal(PuzzleGoalKind.captureSafe, captures: 1), rng);
}

/// Two red pieces in danger and rolls to share between them so that both end where
/// nobody can hit them.
Puzzle? proposeRescue(PuzzleRng rng, int number) {
  final dice = [for (var i = 0; i < 3; i++) 1 + rng.nextInt(6)];
  // Which rolls go to piece A; the rest go to piece B.
  final mask = 1 + rng.nextInt(6);
  var sumA = 0;
  var sumB = 0;
  for (var i = 0; i < 3; i++) {
    if ((mask >> i) & 1 == 1) {
      sumA += dice[i];
    } else {
      sumB += dice[i];
    }
  }
  const safeStops = [21, 26, 34, 39, 47, 51, 52, 53, 54, 55];
  final fa = rng.pick(safeStops);
  final fb = rng.pick(safeStops);
  final a = fa - sumA;
  final b = fb - sumB;
  if (fa == fb || !_plainSquare(a) || !_plainSquare(b) || a == b) return null;
  final layout = _Layout()
    ..put(Seat.red, 0, a)
    ..put(Seat.red, 1, b);
  for (var i = 2; i < 4; i++) {
    layout.put(Seat.red, i, rng.chance(50) ? Board.home : Board.yard);
  }
  // Both pieces start in danger; other stops are threatened too, the two finishing squares are not.
  layout.threaten(rng, a);
  layout.threaten(rng, b);
  for (final base in [a, b]) {
    for (final s in _stopSums(dice)) {
      final stop = base + s;
      if (stop == fa || stop == fb || !_plainSquare(stop)) continue;
      if (rng.chance(45)) layout.threaten(rng, stop);
    }
  }
  return _make(number, layout, dice, const PuzzleGoal(PuzzleGoalKind.rescue), rng);
}

/// Two rivals stand in the path of the red piece; the rolls must be used to hit both.
Puzzle? proposeDoubleCapture(PuzzleRng rng, int number) {
  const n = 3;
  final dice = [for (var i = 0; i < n; i++) 1 + rng.nextInt(6)];
  final order = List.generate(n, (i) => i);
  rng.shuffle(order);
  final prefixes = <int>[];
  var run = 0;
  for (final i in order) {
    run += dice[i];
    prefixes.add(run);
  }
  // The two prefix sums where the captures happen.
  final first = rng.nextInt(n - 1);
  final second = first + 1 + rng.nextInt(n - 1 - first);
  final total = prefixes.last;
  if (48 - total < 1) return null;
  final h = 1 + rng.nextInt(48 - total);
  final x = h + prefixes[first];
  final y = h + prefixes[second];
  if (!_plainSquare(x) || !_plainSquare(y) || x == y) return null;
  final layout = _Layout()..put(Seat.red, 0, h);
  for (var i = 1; i < 4; i++) {
    layout.put(Seat.red, i, rng.chance(50) ? Board.home : Board.yard);
  }
  if (!layout.putAtLoop(rng, x) || !layout.putAtLoop(rng, y)) return null;
  layout.clutter(rng);
  return _make(number, layout, dice, const PuzzleGoal(PuzzleGoalKind.doubleCapture, captures: 2), rng);
}
