// When does a Mayhem bot play which power card — and when does it keep it?
//
// Every legal play is given a "gain" in squares of progress and the best one is played
// when its gain clears the bot's patience threshold. Board-changing cards (Shield, Hop
// +3, Swap, Freeze) are tried on a copy of the position and valued with the same
// evaluation as the search (evaluation.dart); the two dice cards cannot be tried
// without rolling, so they use plain rules of thumb: Double is worth a bit more when
// there are pieces on the board to use it on, Reroll is worth a lot when the roll in
// hand cannot be played or only leaves pieces exposed (a 6 is never rerolled unless it
// cannot be played). A Shield counts double — it lasts two rotations of the table.
//
// Personality: `hoard` raises the threshold (Golu keeps cards until the hand is full
// or the gain is large), `swapLove` adds to every Swap (Golu loves it). A full hand
// lowers the threshold hard, because the next power tile would draw nothing.

import 'dart:math';

import '../dice.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../model/actions.dart';
import '../model/cards.dart';
import '../state/game_state.dart';
import '../state/mayhem_state.dart';
import 'evaluation.dart';
import 'move_score.dart';
import 'personality.dart';

/// The card play [p] would make in [s] (the seat on turn, before or after its roll),
/// or null to keep the cards. [rng] seeds the throw-away copies' dice.
CardUse? planCard(GameState s, BotPersonality p, Random rng) {
  final seed = rng.nextInt(0x7fffffff);
  final core = GameCore.fromState(s, SeededDice(seed));
  final uses = core.legalCardUses();
  if (uses.isEmpty) return null;
  final me = s.current;
  final base = evaluatePosition(core, me);
  final handFull = core.handOf(me).length >= MayhemState.maxHand;
  var threshold = 5 + 14 * p.hoard;
  if (handFull) threshold *= 0.4;

  CardUse? best;
  var bestGain = double.negativeInfinity;
  for (final use in uses) {
    final gain = _gain(core, me, base, use, p, seed);
    if (gain > bestGain) {
      bestGain = gain;
      best = use;
    }
  }
  return bestGain >= threshold ? best : null;
}

double _gain(GameCore core, Seat me, double base, CardUse use, BotPersonality p, int seed) {
  switch (use.card) {
    case PowerCard.double:
      var onBoard = false;
      for (var i = 0; i < 4; i++) {
        final pr = core.progressOf(me, i);
        if (pr >= 0 && pr < Board.home) onBoard = true;
      }
      return onBoard ? 13 : 8;
    case PowerCard.reroll:
      return _rerollGain(core, me);
    case PowerCard.shield:
      return 2.2 * (_after(core, use, seed, me) - base);
    case PowerCard.hop3:
      return _after(core, use, seed, me) - base;
    case PowerCard.swap:
      return _after(core, use, seed, me) - base + p.swapLove;
    case PowerCard.freeze:
      // Besides the threats it removes: a frozen leader loses its next move.
      final target = core.progressOf(use.targetSeat!, use.targetPiece!);
      return _after(core, use, seed, me) - base + 3 + 0.1 * target;
  }
}

/// The position value after playing [use] on a copy.
double _after(GameCore core, CardUse use, int seed, Seat me) {
  final c = core.clone(dice: SeededDice(seed));
  c.apply(UseCard(use));
  return evaluatePosition(c, me);
}

/// Reroll is worth it when the roll cannot be played, or the best play is poor and risky.
double _rerollGain(GameCore core, Seat me) {
  final moves = core.legalMoves();
  if (moves.isEmpty) return 40;
  if (core.pendingDice.contains(6)) return 0;
  var bestScore = double.negativeInfinity;
  var safest = 1.0;
  for (final m in distinctMoves(moves)) {
    final ins = core.insightOf(m);
    final score = scoreMove(core, m, BotPersonality.neutral, insight: ins);
    if (score > bestScore) bestScore = score;
    if (ins.hitChance < safest) safest = ins.hitChance;
  }
  // A poor roll: nothing worth doing (low score) and everything leaves a piece exposed.
  final poor = max(0.0, 24 - bestScore) * 0.6;
  return poor + (safest >= 0.3 ? 8 : 0);
}
