// The player's helpers: the Hint button and the "smart moves %" in the match report.
//
// `hintFor` is what a Hard bot with the plain formula would play (expectimax, no
// slips) — deterministic, a few milliseconds typically, never past the 300 ms deadline.
// `rateMove` compares the move a player actually made with the Expert search's choice
// for the same position: did it match, and how much equity (0 … 1, i.e. percentage
// points / 100) did the choice cost? The
// search uses a fixed rollout count and a seed derived from the position, so the same
// position and move always get the same rating, on every device — which also lets the
// app rate a whole match afterwards (in an isolate) without anything drifting.

import 'dart:math';

import '../analysis/analysis.dart';
import '../config/game_mode.dart';
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'bot_brain.dart';
import 'move_score.dart';

/// The best move for the seat on turn in [s] by the Hard evaluation. Throws
/// [StateError] when there is nothing to play (not awaiting a move, or no legal
/// move) — check `legalMovesOf(s)` first.
Move hintFor(GameState s) {
  final legal = legalMovesOf(s);
  if (legal.isEmpty) throw StateError('There is no move to hint at');
  return BotBrain(BotLevel.hard).bestMove(s, legal, Random(_fingerprint(s)));
}

/// How good a played move was against the Expert search.
class MoveRating {
  const MoveRating({
    required this.chosen,
    required this.expert,
    required this.matchedExpert,
    required this.scoreGap,
    required this.forced,
  });

  /// The move that was rated.
  final Move chosen;

  /// What the Expert search would have played.
  final Move expert;

  /// True when [chosen] and [expert] are the same play (or look identical on the board).
  final bool matchedExpert;

  /// Equity lost against the expert's choice, 0 … 1 (0.05 = 5 percentage points). 0 when matched.
  final double scoreGap;

  /// True when there was nothing to decide (one distinct legal move): leave it out of "smart moves %".
  final bool forced;

  /// Counts as a smart move: matched the expert, or lost less than one percentage point.
  bool get smart => matchedExpert || scoreGap < smartGap;

  /// The equity loss below which a move still counts as smart. Measured on seeded matches: a uniformly random mover
  /// scores 61 % smart, Hard 71 %, Expert 82 % (2 points would give 71 % / 80 % / 86 %, a scale too flat to mean much).
  static const double smartGap = 0.01;

  Map<String, Object?> toJson() => {
    'chosen': chosen.toJson(),
    'expert': expert.toJson(),
    'matchedExpert': matchedExpert,
    'scoreGap': scoreGap,
    'forced': forced,
  };

  factory MoveRating.fromJson(Map<String, Object?> j) => MoveRating(
    chosen: Move.fromJson((j['chosen'] as Map).cast<String, Object?>()),
    expert: Move.fromJson((j['expert'] as Map).cast<String, Object?>()),
    matchedExpert: j['matchedExpert'] as bool,
    scoreGap: (j['scoreGap'] as num).toDouble(),
    forced: j['forced'] as bool,
  );

  @override
  String toString() =>
      'MoveRating(${forced ? 'forced' : matchedExpert ? 'matched' : 'gap ${(scoreGap * 100).toStringAsFixed(1)} pp'})';
}

/// Rates [chosen], a legal move in [s], against the Expert search with [rollouts] per
/// candidate (the default is a third of a normal Expert decision and takes a few
/// milliseconds). Throws [ArgumentError] when [chosen] is not legal in [s].
MoveRating rateMove(GameState s, Move chosen, {int rollouts = 64}) {
  final legal = legalMovesOf(s);
  final played = legal.where((m) => m.sameAs(chosen)).toList();
  if (played.isEmpty) throw ArgumentError('That move is not legal here: $chosen');
  final options = distinctMoves(legal);
  if (options.length == 1) {
    return MoveRating(chosen: played.first, expert: options.first, matchedExpert: true, scoreGap: 0, forced: true);
  }
  final brain = BotBrain(BotLevel.expert);
  final seed = _fingerprint(s);
  final r = brain.search(s, options, seed, maxRollouts: rollouts);
  final best = r.best;
  final chosenIdx = options.indexWhere((m) => m.looksLike(played.first));
  final matched = chosenIdx == best;
  return MoveRating(
    chosen: played.first,
    expert: options[best],
    matchedExpert: matched,
    scoreGap: matched ? 0 : max(0.0, r.values[best] - r.values[chosenIdx]),
    forced: false,
  );
}

/// A stable number for a position (FNV-1a over the pieces, the turn and the dice),
/// the same on every device — seeds the rating search so ratings are reproducible.
int _fingerprint(GameState s) {
  var h = 0xcbf29ce484222325;
  void mix(int v) {
    h = (h ^ (v & 0xffffffff)) * 0x100000001b3;
  }

  for (final seat in Seat.values) {
    for (final p in s.pieces(seat)) {
      mix(p + 2);
    }
  }
  mix(s.current.index);
  mix(s.turnNumber);
  mix(s.phase.index);
  for (final d in s.pendingDice) {
    mix(d);
  }
  return h & 0x7fffffffffffffff;
}
