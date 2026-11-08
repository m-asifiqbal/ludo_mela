// BotBrain: one bot's decisions, by level and personality.
//
//   Easy    weighted random over the move scores (a softmax), and 35 % of the time a
//           plain random move — the "mistakes".
//   Normal  the best move by the shared formula (move_score.dart); 15 % slips.
//   Hard    expectimax over the next round of rival rolls (hard_search.dart), with the
//           formula as a prior and the personality's weights on top; 5 % slips.
//   Expert  Monte-Carlo rollouts with rival modelling inside a time budget
//           (expert_search.dart); never slips. The personality only decides close calls.
//
// A slip is a uniformly random choice among the *other* moves, so a bot that "makes a
// mistake" really plays a different move. Bots never see future dice: they get a
// GameState (no dice inside) and a `Random` for their own choices, and every look-ahead
// rolls its own SeededDice or a chosen value.
//
// `chooseMove` is synchronous. Expert can take its budget (300 ms), so the app runs it
// in an isolate with the helpers in bot_json.dart.

import 'dart:math';

import '../config/game_mode.dart';
import '../dice.dart';
import '../engine/core.dart';
import '../model/cards.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'card_play.dart';
import 'expert_search.dart';
import 'hard_search.dart';
import 'move_score.dart';
import 'personality.dart';

/// Hard's expectimax value is in squares; the plain formula score joins it with this weight.
const double _hardPrior = 0.3;

/// Weight of what a personality adds to (or takes from) the plain formula's score at Hard. Measured in the
/// arena: at 0.3 the characters were indistinguishable, at 0.7 the Racer lost 8 points of win rate against
/// the plain bot; 0.5 keeps every character within noise of it and still plays visibly differently.
const double _hardStyle = 0.5;

/// Expert's equity is 0 … 1; the personality's formula difference (per 100 points) moves it by at most
/// this much — enough to decide close calls (a few points of equity) and nothing bigger.
const double _expertPrior = 0.05;

/// Softmax temperature of Easy's weighted random choice, in score points.
const double _easyTemperature = 22;

/// A bot's brain: its [level] and [personality].
class BotBrain {
  BotBrain(this.level, [this.personality = BotPersonality.neutral]);

  final BotLevel level;
  final BotPersonality personality;

  /// The think time Expert gets by default.
  static const Duration defaultBudget = defaultExpertBudget;

  /// Picks one of [legal] (the moves `LudoGame.legalMoves()` offers in [s]). The returned
  /// move is an element of [legal]. [rng] drives the bot's own randomness (slips,
  /// Easy's weighted choice, the seed of the look-ahead dice); Expert stops searching
  /// after [budget] (a laptop finishes its 200 rollouts per move well inside it).
  Move chooseMove(GameState s, List<Move> legal, Random rng, {Duration budget = defaultExpertBudget}) {
    if (legal.isEmpty) throw ArgumentError('There is no legal move to choose from');
    final options = distinctMoves(legal);
    if (options.length == 1) return legal.first;
    final index = _decide(s, options, rng, budget);
    final picked = options[index];
    return legal.firstWhere((m) => identical(m, picked));
  }

  /// The power card to play now, or null to keep the cards (Mayhem; the seat on turn,
  /// before its roll or after it). Easy slips by holding or playing at random.
  CardUse? chooseCard(GameState s, Random rng) {
    if (s.config.mode != GameMode.mayhem || s.isOver) return null;
    if (s.phase != Phase.awaitRoll && s.phase != Phase.awaitMove) return null;
    if (rng.nextDouble() < level.mistakeRate) {
      final uses = _legalUses(s);
      if (uses.isEmpty || rng.nextBool()) return null;
      return uses[rng.nextInt(uses.length)];
    }
    return planCard(s, personality, rng);
  }

  /// The best option by this brain's own judgement, without slips: what the bot would
  /// play if it never erred (used by the hint, which asks a Hard neutral brain).
  Move bestMove(GameState s, List<Move> legal, Random rng, {Duration budget = defaultExpertBudget}) {
    if (legal.isEmpty) throw ArgumentError('There is no legal move to choose from');
    final options = distinctMoves(legal);
    if (options.length == 1) return legal.first;
    final picked = options[_best(s, options, rng, budget)];
    return legal.firstWhere((m) => identical(m, picked));
  }

  // ── decisions ───────────────────────────────────────────────────────────

  int _decide(GameState s, List<Move> options, Random rng, Duration budget) {
    if (level == BotLevel.easy) {
      if (rng.nextDouble() < level.mistakeRate) return rng.nextInt(options.length);
      final core = GameCore.fromState(s, const NoDice());
      return _weightedPick(scoreMoves(core, options, personality), rng);
    }
    final best = _best(s, options, rng, budget);
    if (rng.nextDouble() < level.mistakeRate) {
      final other = rng.nextInt(options.length - 1);
      return other >= best ? other + 1 : other; // any option but the best
    }
    return best;
  }

  int _best(GameState s, List<Move> options, Random rng, Duration budget) {
    final seed = rng.nextInt(0x7fffffff);
    switch (level) {
      case BotLevel.easy || BotLevel.normal:
        final core = GameCore.fromState(s, const NoDice());
        return _argmax(scoreMoves(core, options, personality));
      case BotLevel.hard:
        final core = GameCore.fromState(s, SeededDice(seed));
        final tree = expectimaxValues(core, s.current, options, personalitiesFor(s), budget: budget);
        final plain = scoreMoves(core, options, BotPersonality.neutral, deep: true);
        final own = personality == BotPersonality.neutral ? plain : scoreMoves(core, options, personality, deep: true);
        return _argmax([
          for (var i = 0; i < options.length; i++) tree[i] + _hardPrior * plain[i] + _hardStyle * (own[i] - plain[i]),
        ]);
      case BotLevel.expert:
        return _expertBest(s, options, seed, budget);
    }
  }

  /// The Expert search itself: mean equity (0 … 1) of each of [options] for the seat on
  /// turn, from [rollouts] dice streams derived from [seed] (at most [maxRollouts] per
  /// option, fewer if [budget] runs out first). Ratings and tests use it directly.
  ExpertResult search(
    GameState s,
    List<Move> options,
    int seed, {
    Duration budget = const Duration(seconds: 30),
    int maxRollouts = defaultRollouts,
  }) {
    final core = GameCore.fromState(s, SeededDice(seed));
    return expertSearch(
      core,
      s.current,
      options,
      personalitiesFor(s),
      seed: seed,
      budget: budget,
      maxRollouts: maxRollouts,
    );
  }

  /// Expert's choice: the search, with this brain's personality as the near-tie breaker.
  int _expertBest(GameState s, List<Move> options, int seed, Duration budget) {
    final r = search(s, options, seed, budget: budget);
    if (personality == BotPersonality.neutral) return r.best;
    final core = GameCore.fromState(s, const NoDice());
    return _argmax([
      for (var i = 0; i < options.length; i++)
        r.values[i] + _expertPrior * _personalityLean(core, options[i], personality),
    ]);
  }

  /// How much more [p] likes [m] than the plain formula does, -1 … 1 (per 100 score points).
  double _personalityLean(GameCore core, Move m, BotPersonality p) =>
      ((scoreMove(core, m, p) - scoreMove(core, m, BotPersonality.neutral)) / 100).clamp(-1.0, 1.0);

  /// How each seat plays, with this brain's own seat using its own personality.
  List<BotPersonality> personalitiesFor(GameState s) {
    final out = personalitiesOf(s.config);
    out[s.current.index] = personality;
    return out;
  }

  List<CardUse> _legalUses(GameState s) => GameCore.fromState(s, const NoDice()).legalCardUses();
}

int _argmax(List<double> v) {
  var b = 0;
  for (var i = 1; i < v.length; i++) {
    if (v[i] > v[b]) b = i;
  }
  return b;
}

/// Picks an index with probability proportional to exp(score / temperature).
int _weightedPick(List<double> scores, Random rng) {
  final top = scores.reduce(max);
  final w = [for (final s in scores) exp((s - top) / _easyTemperature)];
  var r = rng.nextDouble() * w.reduce((a, b) => a + b);
  for (var i = 0; i < w.length; i++) {
    r -= w[i];
    if (r <= 0) return i;
  }
  return w.length - 1;
}
