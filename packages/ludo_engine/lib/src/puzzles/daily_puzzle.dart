// The daily puzzle: `dailyPuzzle(dayNumber)` — the same puzzle on every phone, every
// time, and always solvable.
//
// How: the day picks a goal from a fixed cycle (home-safe appears twice, it is the
// classic), then candidate positions are proposed from a SplitMix64 stream seeded by
// (day, goal, attempt) — scenarios in puzzle_scenarios.dart — and each candidate is
// *solved* with the real engine rules (puzzle_solver.dart). A candidate is kept only
// when at least one play wins, there are at least [_minPlays] different plays to choose
// from and no more than a third of them win (so guessing does not solve it, no order
// of the rolls works for everyone, and the glowing-piece-first order is not the answer).
// Home-safe puzzles must also fail when the rolls are played left to right as shown. If a
// goal finds nothing in 120 attempts, home-safe gets 120 more, and as the last resort a
// hand-checked curated puzzle is used. The tests solve every day 0 … 1095 (three years).

import '../geometry.dart';
import 'puzzle.dart';
import 'puzzle_scenarios.dart';

/// The goal of each day of the cycle.
const List<PuzzleGoalKind> _cycle = [
  PuzzleGoalKind.homeSafe,
  PuzzleGoalKind.captureSafe,
  PuzzleGoalKind.rescue,
  PuzzleGoalKind.homeSafe,
  PuzzleGoalKind.doubleCapture,
];

const int _attempts = 120;

/// A puzzle needs at least this many different complete plays, or there is nothing to decide.
const int _minPlays = 4;

/// The puzzle for day [dayNumber] (any integer; the app passes the number of days since its epoch).
/// Deterministic, solvable, and never solved by every order of the rolls.
Puzzle dailyPuzzle(int dayNumber) {
  final primary = _cycle[dayNumber % _cycle.length];
  for (final kind in {primary, PuzzleGoalKind.homeSafe}) {
    for (var attempt = 0; attempt < _attempts; attempt++) {
      final candidate = _propose(kind, PuzzleRng(_seed(dayNumber, kind, attempt)), dayNumber);
      if (candidate != null && _worthPlaying(candidate)) return candidate;
    }
  }
  return curatedPuzzle(dayNumber % curatedPuzzleCount, number: dayNumber);
}

int _seed(int day, PuzzleGoalKind kind, int attempt) {
  // One SplitMix pass over the three numbers so neighbouring days share nothing.
  var z = day * 0x9E3779B97F4A7C15 + (kind.index + 1) * 0xBF58476D1CE4E5B9 + attempt * 0x94D049BB133111EB;
  z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9;
  z = (z ^ (z >>> 27)) * 0x94D049BB133111EB;
  return z ^ (z >>> 31);
}

Puzzle? _propose(PuzzleGoalKind kind, PuzzleRng rng, int number) => switch (kind) {
  PuzzleGoalKind.homeSafe => proposeHomeSafe(rng, number),
  PuzzleGoalKind.captureSafe => proposeCaptureSafe(rng, number),
  PuzzleGoalKind.rescue => proposeRescue(rng, number),
  PuzzleGoalKind.doubleCapture => proposeDoubleCapture(rng, number),
};

/// Solvable, with real choices, and hard enough that guessing does not solve it.
bool _worthPlaying(Puzzle p) {
  final a = p.analysis;
  if (!a.solvable || a.plays < _minPlays || a.wins.length * 3 > a.plays) return false;
  if (p.goal.kind == PuzzleGoalKind.homeSafe) {
    // Playing the dice left to right (as laid out) must not be the answer.
    final leftToRight = [for (var i = 0; i < p.rolls.length; i++) PuzzleStep(i, p.heroPiece)];
    final solved = a.wins.any((w) => w.length == leftToRight.length && _same(w, leftToRight));
    if (solved) return false;
  }
  return true;
}

bool _same(List<PuzzleStep> a, List<PuzzleStep> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// How many hand-made puzzles there are.
const int curatedPuzzleCount = 3;

/// A hand-checked home-safe puzzle ([index] 0 … [curatedPuzzleCount] - 1), labelled [number].
/// Index 0 is the design's artboard (red 15 squares from home, rolls 6, 5, 4, blue just ahead).
/// These are the generator's last resort and what a tutorial or preview can show.
Puzzle curatedPuzzle(int index, {int number = 0}) {
  const goal = PuzzleGoal(PuzzleGoalKind.homeSafe);
  switch (index) {
    case 0:
      return buildPuzzle(
        number: number,
        goal: goal,
        rolls: const [6, 5, 4],
        pieces: const {
          Seat.red: [41, 56, -1, -1],
          Seat.green: [25, -1, -1, -1],
          Seat.yellow: [10, 56, -1, -1],
          Seat.blue: [4, 30, -1, -1],
        },
      );
    case 1:
      // Blue sits on its start (reaches 40-45), green on the star at 47 (reaches 48-50):
      // only 6 first — to 46 — and then into the lane is safe.
      return buildPuzzle(
        number: number,
        goal: goal,
        rolls: const [5, 6, 5],
        pieces: const {
          Seat.red: [40, 56, -1, -1],
          Seat.green: [34, -1, -1, -1],
          Seat.yellow: [-1, -1, -1, -1],
          Seat.blue: [0, -1, -1, -1],
        },
      );
    default:
      // Green at loop 40 reaches 41-46: stopping on 46 is fatal, 48 is out of reach.
      return buildPuzzle(
        number: number,
        goal: goal,
        rolls: const [4, 6, 4],
        pieces: const {
          Seat.red: [42, 56, -1, -1],
          Seat.green: [27, -1, -1, -1],
          Seat.yellow: [-1, -1, -1, -1],
          Seat.blue: [-1, -1, -1, -1],
        },
      );
  }
}
