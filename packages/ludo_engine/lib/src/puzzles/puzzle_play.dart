// The rules of a puzzle play: how one die is played, who can hit what, and when a
// play is won or lost. The solver (puzzle_solver.dart) and `PuzzleRun` (puzzle_run.dart)
// both walk positions with these functions, so what the solver promises is exactly what
// the screen will accept.
//
// A die is played on the real engine: the position is loaded into a `GameCore`, the die
// is made pending for the hero seat, the legal move of the chosen piece is played, and
// the new piece positions are read back. Bonus rolls, turn changes and rival turns are
// deliberately ignored — the rolls of a puzzle are fixed, rivals never move, and
// "can be hit" means a rival piece 1–6 squares behind on a non-safe loop square (the
// engine's `threatsOnPiece`, the same marks the match screen shows).

import '../analysis/move_insight.dart';
import '../dice.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'puzzle.dart';

/// How a play is going.
enum PuzzleStatus { playing, solved, failed }

/// Why a play failed.
enum PuzzleFailure {
  /// A piece stopped where a rival could hit it (the end position for goals that only check the end).
  exposed,

  /// Every roll is played but the goal is not met (no capture, piece not home, …).
  missedGoal,

  /// Rolls are left but none of them can be played any more.
  stuck,
}

/// A position inside a play: the board, which rolls are used, captures so far, and
/// whether any stop was exposed (homeSafe fails on that).
class PuzzlePosition {
  const PuzzlePosition(this.state, this.used, this.captures, this.exposed);

  factory PuzzlePosition.start(Puzzle p) => PuzzlePosition(p.start, 0, 0, false);

  final GameState state;

  /// Bit r set = roll number r is used.
  final int used;

  /// Rival pieces sent back so far.
  final int captures;

  /// True once a piece has stopped on a square a rival could hit.
  final bool exposed;

  bool isUsed(int roll) => (used >> roll) & 1 == 1;

  bool allUsed(Puzzle p) => used == (1 << p.rolls.length) - 1;
}

/// What playing one die did.
class DieOutcome {
  const DieOutcome(this.position, this.move, this.insight);

  /// The position after the move.
  final PuzzlePosition position;

  /// The move that was played (path, captures, kind).
  final Move move;

  /// The move's analysis made *before* playing it: tags (SAFE, RISKY, CAPTURE, LANE, HOME) and hit chance.
  final MoveInsight insight;
}

/// The state with [die] pending for the hero, ready for a `GameCore`.
GameState _withDie(Puzzle p, GameState s, int die) => s.copyWith(
  phase: Phase.awaitMove,
  current: p.hero,
  pendingDice: [die],
  diceUsed: 0,
  sixesInRow: 0,
  extraRolls: 0,
  rollsTaken: 1,
);

/// The legal moves of roll number [roll] in [pos] (empty when it is used or cannot be played).
List<Move> movesOfRoll(Puzzle p, PuzzlePosition pos, int roll) {
  if (roll < 0 || roll >= p.rolls.length || pos.isUsed(roll)) return const [];
  return GameCore.fromState(_withDie(p, pos.state, p.rolls[roll]), const NoDice()).legalMoves();
}

/// True when at least one unused roll can be played somewhere.
bool canPlayAny(Puzzle p, PuzzlePosition pos) {
  for (var r = 0; r < p.rolls.length; r++) {
    if (pos.isUsed(r)) continue;
    if (GameCore.fromState(_withDie(p, pos.state, p.rolls[r]), const NoDice()).hasLegalMove()) return true;
  }
  return false;
}

/// Plays roll number [roll] on piece [piece]; null when that is not possible (used, or the
/// piece has no legal move with that die).
DieOutcome? playDie(Puzzle p, PuzzlePosition pos, int roll, int piece) {
  if (roll < 0 || roll >= p.rolls.length || pos.isUsed(roll)) return null;
  final core = GameCore.fromState(_withDie(p, pos.state, p.rolls[roll]), const NoDice());
  Move? move;
  for (final m in core.legalMoves()) {
    if (m.piece == piece) {
      move = m;
      break;
    }
  }
  if (move == null) return null;
  final insight = core.insightOf(move);
  core.play(move);
  final next = pos.state.copyWith(
    pieces: {
      for (final s in Seat.values) s: [for (var i = 0; i < 4; i++) core.progressOf(s, i)],
    },
    phase: Phase.awaitRoll,
    current: p.hero,
    pendingDice: const [],
    diceUsed: 0,
    sixesInRow: 0,
    extraRolls: 0,
    rollsTaken: 0,
  );
  return DieOutcome(
    PuzzlePosition(next, pos.used | (1 << roll), pos.captures + move.captures.length, pos.exposed || insight.has(MoveTag.risky)),
    move,
    insight,
  );
}

/// Won, lost or still going, with the reason for a loss.
(PuzzleStatus, PuzzleFailure?) judge(Puzzle p, PuzzlePosition pos) {
  final goal = p.goal;
  if (goal.failsOnExposure && pos.exposed) return (PuzzleStatus.failed, PuzzleFailure.exposed);
  if (!pos.allUsed(p)) {
    return canPlayAny(p, pos) ? (PuzzleStatus.playing, null) : (PuzzleStatus.failed, PuzzleFailure.stuck);
  }
  final core = GameCore.fromState(pos.state, const NoDice());
  switch (goal.kind) {
    case PuzzleGoalKind.homeSafe:
      return pos.state.pieceAt(p.hero, p.heroPiece) == Board.home
          ? (PuzzleStatus.solved, null)
          : (PuzzleStatus.failed, PuzzleFailure.missedGoal);
    case PuzzleGoalKind.captureSafe:
      if (pos.captures < goal.captures) return (PuzzleStatus.failed, PuzzleFailure.missedGoal);
      return core.threatsOnPiece(p.hero, p.heroPiece) > 0
          ? (PuzzleStatus.failed, PuzzleFailure.exposed)
          : (PuzzleStatus.solved, null);
    case PuzzleGoalKind.rescue:
      for (var i = 0; i < 4; i++) {
        if (core.threatsOnPiece(p.hero, i) > 0) return (PuzzleStatus.failed, PuzzleFailure.exposed);
      }
      return (PuzzleStatus.solved, null);
    case PuzzleGoalKind.doubleCapture:
      return pos.captures >= goal.captures
          ? (PuzzleStatus.solved, null)
          : (PuzzleStatus.failed, PuzzleFailure.missedGoal);
  }
}

/// The rival seats with a piece 1–6 squares behind [piece] of [seat] that could land on
/// it with one roll (empty for pieces off the loop or on a safe square).
List<Seat> threateningSeats(GameState s, Seat seat, int piece) {
  final idx = Board.loopIndexOrNone(seat, s.pieceAt(seat, piece));
  if (idx < 0 || Board.isSafeLoopIndex(idx)) return const [];
  final out = <Seat>[];
  for (final rival in s.seats) {
    if (rival == seat) continue;
    for (var i = 0; i < 4; i++) {
      final q = s.pieceAt(rival, i);
      if (q < 0 || q > Board.lastLoop) continue;
      final d = (idx - Board.loopIndexOrNone(rival, q) + Board.loopLength) % Board.loopLength;
      if (d >= 1 && d <= 6 && q + d <= Board.lastLoop) {
        out.add(rival);
        break;
      }
    }
  }
  return out;
}

/// Every non-safe loop square a rival piece could land on with its next roll (the
/// "SHOW DANGER" overlay), mapped to a seat that could do it.
Map<int, Seat> dangerSquaresOf(GameState s, Seat hero) {
  final out = <int, Seat>{};
  for (final rival in s.seats) {
    if (rival == hero) continue;
    for (var i = 0; i < 4; i++) {
      final q = s.pieceAt(rival, i);
      if (q < 0 || q > Board.lastLoop) continue;
      for (var d = 1; d <= 6 && q + d <= Board.lastLoop; d++) {
        final idx = Board.loopIndexOrNone(rival, q + d);
        if (!Board.isSafeLoopIndex(idx)) out.putIfAbsent(idx, () => rival);
      }
    }
  }
  return out;
}
