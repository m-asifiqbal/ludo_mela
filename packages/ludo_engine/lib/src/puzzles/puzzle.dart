// The daily puzzle's data: a hand-built position, the rolls to use, and the goal.
//
// A puzzle is a small plan-your-moves problem on the real engine (design screen
// "Puzzle"): the player's red pieces sit on a position with rivals around, a few dice
// values are given up front, and every roll must be played — in any order, on any
// piece — so that the goal holds at the end. Positions are deterministic functions of
// the day number (daily_puzzle.dart) and always solvable; `analysis` proves it by
// searching every play.
//
// Goals (`PuzzleGoalKind`):
//   homeSafe       "Get your glowing red piece home using these rolls — without
//                  stopping where someone can hit you."
//   captureSafe    "Send a rival home with your glowing piece and finish where
//                  nobody can hit it."
//   rescue         "Your pieces are in danger: use every roll so that none of them
//                  can be hit."
//   doubleCapture  "Send two rival pieces home using these rolls."

import '../geometry.dart';
import '../state/game_state.dart';
import 'puzzle_solver.dart';

/// What the player has to achieve.
enum PuzzleGoalKind { homeSafe, captureSafe, rescue, doubleCapture }

/// A goal and its numbers.
class PuzzleGoal {
  const PuzzleGoal(this.kind, {this.captures = 0});

  final PuzzleGoalKind kind;

  /// Rival pieces that must be sent back (1 for captureSafe, 2 for doubleCapture, else 0).
  final int captures;

  /// True when intermediate stops must not be hittable (the run fails the moment one is).
  bool get failsOnExposure => kind == PuzzleGoalKind.homeSafe;

  @override
  bool operator ==(Object other) => other is PuzzleGoal && other.kind == kind && other.captures == captures;

  @override
  int get hashCode => Object.hash(kind, captures);

  @override
  String toString() => 'PuzzleGoal(${kind.name}${captures > 0 ? ' x$captures' : ''})';
}

/// One play: use roll number [rollIndex] (position in `Puzzle.rolls`) on piece [piece].
class PuzzleStep {
  const PuzzleStep(this.rollIndex, this.piece);

  final int rollIndex;
  final int piece;

  @override
  bool operator ==(Object other) => other is PuzzleStep && other.rollIndex == rollIndex && other.piece == piece;

  @override
  int get hashCode => Object.hash(rollIndex, piece);

  @override
  String toString() => 'roll #$rollIndex → piece $piece';
}

/// Every complete play of a puzzle, searched exhaustively.
class PuzzleSolution {
  const PuzzleSolution(this.wins, this.plays);

  /// The winning plays (each a full sequence of steps).
  final List<List<PuzzleStep>> wins;

  /// How many distinct complete plays exist (including those that lose).
  final int plays;

  bool get solvable => wins.isNotEmpty;

  /// The share of plays that win — what a player picking at random would score.
  double get winShare => plays == 0 ? 0 : wins.length / plays;
}

/// A puzzle: the start position, the rolls and the goal.
class Puzzle {
  Puzzle({
    required this.number,
    required this.start,
    required this.hero,
    required this.heroPiece,
    required List<int> rolls,
    required this.goal,
  }) : rolls = List.unmodifiable(rolls);

  /// The number shown in the title ("PUZZLE #128"): the day number it was made for.
  final int number;

  /// The position, with the hero seat to play (phase `awaitRoll`, no roll-off).
  final GameState start;

  /// The player's seat (always red on the daily board).
  final Seat hero;

  /// The glowing piece the goal is about.
  final int heroPiece;

  /// The dice to use, in display order. Every one must be played exactly once.
  final List<int> rolls;

  final PuzzleGoal goal;

  /// The exhaustive search of every play, computed on first use (a few milliseconds).
  late final PuzzleSolution analysis = solvePuzzle(this);

  /// One winning play (the first found). Throws [StateError] if the puzzle is unsolvable.
  List<PuzzleStep> get solution {
    if (!analysis.solvable) throw StateError('Puzzle #$number has no solution');
    return analysis.wins.first;
  }

  @override
  String toString() => 'Puzzle #$number(${goal.kind.name}, rolls $rolls)';
}
