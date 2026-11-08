// Expert's brain: Monte-Carlo rollouts with rival modelling, cut off by a time budget.
//
// For every candidate move the position is cloned once per rollout, the move is
// played, and every seat (the bot included) plays on with the cheap formula policy —
// rivals with their own personality weights when they are bots, the plain formula for
// humans — for a fixed horizon of turns; the end position is valued (evaluation.dart)
// and squashed into a 0 … 1 equity. The candidate's score is its mean equity.
//
// Two things make a few hundred rollouts enough: all candidates see the *same* dice
// stream in rollout r (common random numbers, so luck cancels out of the comparison),
// and the horizon is short (30 turns, ≈ 20–60 µs on a laptop). The dice are
// `SeededDice` streams derived from the caller's seed — never the match's own dice —
// so the bot cannot see what is about to be rolled. The search stops at the rollout
// cap or when the time budget would be exceeded by one more round, whichever comes
// first, but always plays a minimum number of rounds.

import '../dice.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'evaluation.dart';
import 'move_score.dart';
import 'personality.dart';

/// Rollouts per candidate move (design board B: "200 Monte-Carlo rollouts per move").
const int defaultRollouts = 200;

/// Turns each rollout plays before the position is valued.
const int rolloutHorizon = 30;

/// The default think budget (design board B: "≤ 0.3 s").
const Duration defaultExpertBudget = Duration(milliseconds: 300);

/// The outcome of one Expert search.
class ExpertResult {
  const ExpertResult(this.values, this.rollouts);

  /// Mean equity (0 … 1) of each option, in the order given.
  final List<double> values;

  /// Rollouts played per option.
  final int rollouts;

  /// Index of the best option (the first on ties).
  int get best {
    var b = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[b]) b = i;
    }
    return b;
  }
}

/// Runs the rollouts for [options] (distinct legal moves of [root]'s position) and
/// returns their mean equities for [me]. [seed] fixes the dice streams, so the same
/// seed and rollout count give the same answer on every device.
ExpertResult expertSearch(
  GameCore root,
  Seat me,
  List<Move> options,
  List<BotPersonality> persons, {
  required int seed,
  Duration budget = defaultExpertBudget,
  int maxRollouts = defaultRollouts,
  int minRollouts = 8,
  int horizon = rolloutHorizon,
}) {
  final clock = Stopwatch()..start();
  final budgetUs = budget.inMicroseconds;
  final totals = List<double>.filled(options.length, 0);
  final cap = maxRollouts < 1 ? 1 : maxRollouts; // always one round, so the means below are never 0 / 0
  var done = 0;
  var round = 0; // smoothed cost of one round (all options), µs
  while (done < cap) {
    final t0 = clock.elapsedMicroseconds;
    final diceSeed = seed + done * 0x9E3779B1;
    for (var i = 0; i < options.length; i++) {
      final c = root.clone(dice: SeededDice(diceSeed));
      c.play(options[i]);
      _playOut(c, persons, horizon);
      totals[i] += winEquity(evaluatePosition(c, me));
    }
    done++;
    final t1 = clock.elapsedMicroseconds;
    round = round == 0 ? t1 - t0 : (round * 3 + (t1 - t0)) ~/ 4;
    if (done >= minRollouts && t1 + round > budgetUs) break;
  }
  return ExpertResult([for (final t in totals) t / done], done);
}

/// Plays [c] on with the formula policy for [horizon] turns (or until the match ends).
void _playOut(GameCore c, List<BotPersonality> persons, int horizon) {
  final end = c.turnNumber + horizon;
  while (!c.isOver && c.turnNumber < end) {
    if (c.phase == Phase.awaitRoll) {
      c.roll();
    } else if (c.phase == Phase.awaitMove) {
      final moves = c.legalMoves();
      if (moves.isEmpty) {
        c.pass();
      } else {
        c.play(moves.length == 1 ? moves.first : pickByScore(c, moves, persons[c.current.index]));
      }
    } else {
      return; // roll-off: nothing to simulate
    }
  }
}
