// PuzzleRun: one attempt at a puzzle — what the puzzle screen talks to.
//
// The screen shows the rolls as dice and the board from `state`; when the player taps a
// die and then a piece it calls `apply(rollIndex, piece)` and plays the returned
// `move` (path, captures) as an animation; the result also says whether the attempt is
// now solved or failed and why, which rival could hit the piece ("Green could reach that
// square"), and the move's tags ("Safe star", "In your home lane"). `movesFor` lists the
// destinations of a die before a piece is chosen, `dangerSquares` is the SHOW DANGER
// overlay, `hint` the next step of a winning play, and `reset` is START OVER.
//
// A run is a small mutable object (like a game session): after an accepted step
// read `state`, `used`, `status` again. It never throws on misuse — an impossible step
// is simply not `accepted` and changes nothing.

import '../analysis/move_insight.dart';
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'puzzle.dart';
import 'puzzle_play.dart';
import 'puzzle_solver.dart';

/// What `PuzzleRun.apply` did.
class PuzzleStepResult {
  const PuzzleStepResult._({
    required this.accepted,
    required this.status,
    required this.failure,
    required this.move,
    required this.insight,
    required this.threatenedBy,
    required this.captured,
    required this.state,
  });

  /// False when the step was not possible (roll already used, piece cannot move with it, run over);
  /// then nothing changed and the other fields describe the unchanged run.
  final bool accepted;

  /// Playing, solved or failed after the step.
  final PuzzleStatus status;

  /// Why the run failed, when it did.
  final PuzzleFailure? failure;

  /// The move played (its `path` and `captures` drive the animation); null when not accepted.
  final Move? move;

  /// Tags of the move (SAFE, RISKY, CAPTURE, LANE, HOME …) and its hit chance; null when not accepted.
  final MoveInsight? insight;

  /// Rival seats that could hit the moved piece where it stopped (empty when it is safe).
  final List<Seat> threatenedBy;

  /// Rival pieces this move sent back.
  final int captured;

  /// The board after the step.
  final GameState state;

  bool get solved => status == PuzzleStatus.solved;
  bool get failed => status == PuzzleStatus.failed;

  factory PuzzleStepResult.rejected(PuzzleRun run) => PuzzleStepResult._(
    accepted: false,
    status: run.status,
    failure: run.failure,
    move: null,
    insight: null,
    threatenedBy: const [],
    captured: 0,
    state: run.state,
  );
}

/// One attempt at [puzzle].
class PuzzleRun {
  PuzzleRun(this.puzzle) : _pos = PuzzlePosition.start(puzzle);

  /// Replays [steps] (for example a saved attempt); steps that are not possible are skipped.
  factory PuzzleRun.replay(Puzzle puzzle, Iterable<PuzzleStep> steps) {
    final run = PuzzleRun(puzzle);
    for (final s in steps) {
      run.apply(s.rollIndex, s.piece);
    }
    return run;
  }

  final Puzzle puzzle;
  PuzzlePosition _pos;
  final List<PuzzleStep> _steps = [];
  PuzzleStatus _status = PuzzleStatus.playing;
  PuzzleFailure? _failure;

  /// The board now.
  GameState get state => _pos.state;

  PuzzleStatus get status => _status;
  bool get solved => _status == PuzzleStatus.solved;
  bool get failed => _status == PuzzleStatus.failed;
  PuzzleFailure? get failure => _failure;

  /// The accepted steps so far.
  List<PuzzleStep> get steps => List.unmodifiable(_steps);

  /// Which rolls are used, in the puzzle's display order.
  List<bool> get used => [for (var i = 0; i < puzzle.rolls.length; i++) _pos.isUsed(i)];

  /// The rolls still to play (indices into `puzzle.rolls`).
  List<int> get remaining => [
    for (var i = 0; i < puzzle.rolls.length; i++)
      if (!_pos.isUsed(i)) i,
  ];

  /// Rival pieces sent back so far.
  int get captures => _pos.captures;

  /// The legal moves roll [rollIndex] has right now (one per piece that can use it) — the
  /// destinations to show once a die is picked. Empty when the die is used or the run is over.
  List<Move> movesFor(int rollIndex) => _status == PuzzleStatus.playing ? movesOfRoll(puzzle, _pos, rollIndex) : const [];

  /// Plays roll [rollIndex] on piece [piece].
  PuzzleStepResult apply(int rollIndex, int piece) {
    if (_status != PuzzleStatus.playing) return PuzzleStepResult.rejected(this);
    final out = playDie(puzzle, _pos, rollIndex, piece);
    if (out == null) return PuzzleStepResult.rejected(this);
    _pos = out.position;
    _steps.add(PuzzleStep(rollIndex, piece));
    final (status, failure) = judge(puzzle, _pos);
    _status = status;
    _failure = failure;
    return PuzzleStepResult._(
      accepted: true,
      status: status,
      failure: failure,
      move: out.move,
      insight: out.insight,
      threatenedBy: threateningSeats(_pos.state, puzzle.hero, piece),
      captured: out.move.captures.length,
      state: _pos.state,
    );
  }

  /// The next step of a winning play from here, or null when solved, failed or no longer winnable.
  PuzzleStep? hint() {
    if (_status != PuzzleStatus.playing) return null;
    final win = firstWin(puzzle, _pos);
    return win == null || win.isEmpty ? null : win.first;
  }

  /// False once no winning play is left (the screen can offer START OVER before the last roll is wasted).
  bool get canStillWin => _status == PuzzleStatus.playing && firstWin(puzzle, _pos) != null;

  /// Non-safe loop squares a rival could land on with its next roll (the SHOW DANGER overlay),
  /// by loop index, with a seat that could do it.
  Map<int, Seat> dangerSquares() => dangerSquaresOf(_pos.state, puzzle.hero);

  /// START OVER.
  void reset() {
    _pos = PuzzlePosition.start(puzzle);
    _steps.clear();
    _status = PuzzleStatus.playing;
    _failure = null;
  }
}
