// Hard's brain: expectimax over the next round of rival rolls.
//
// For each candidate move: play it on a copy of the position, then walk the dice —
// every roll 1 … 6 with probability 1/6 (`GameCore.rollValue`, so no randomness is
// consumed and nothing about future dice is known) — letting each rival answer with
// the move its own personality would pick, until the turn is back with the bot, and
// score the position there (evaluation.dart). The bot's own bonus rolls (a 6, a
// capture) are searched too: the first one exhaustively, any later one with the move
// formula's choice, so a lucky chain of sixes cannot blow the tree up. The score of a
// candidate is that expectation; the caller adds a share of the move formula so the
// personality still shapes close calls.
//
// Cost: ≈ 4 moves × 6³ rival rolls × a rival answer — a few milliseconds, tens in the
// worst positions. A deadline (the caller's budget) is the safety net: once it passes,
// the lines still open are valued where they stand instead of searched further.

import '../engine/core.dart';
import 'expert_search.dart' show defaultExpertBudget;
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'evaluation.dart';
import 'move_score.dart';
import 'personality.dart';

/// The most roll nodes (rival rolls and the bot's own bonus rolls) one line may pass.
const int _chanceDepth = 4;

/// The bot's own moves are searched over every option only while at least this many roll
/// nodes are left (its first bonus roll); later ones play the formula's favourite.
const int _fullSearchChances = 3;

/// Expectimax value of each of [options] for [me], in squares (see evaluation.dart).
/// [root] must have dice of its own: Mayhem tiles draw cards while a line is played.
/// After [budget] the open lines are valued as they stand (see the header).
List<double> expectimaxValues(
  GameCore root,
  Seat me,
  List<Move> options,
  List<BotPersonality> persons, {
  Duration budget = defaultExpertBudget,
}) {
  final search = _Expectimax(me, persons, budget.inMicroseconds);
  return [
    for (final m in options)
      () {
        final c = root.clone();
        c.play(m);
        return search.value(c, _chanceDepth, false);
      }(),
  ];
}

class _Expectimax {
  _Expectimax(this.me, this.persons, this._deadlineUs) : _team = me.index & 1 {
    _clock.start();
  }

  final Seat me;
  final List<BotPersonality> persons;
  final int _team;
  final int _deadlineUs;
  final Stopwatch _clock = Stopwatch();

  bool _mine(GameCore c, Seat s) => c.config.isTeams ? (s.index & 1) == _team : s == me;

  /// Value of [c] where it stands. [rivalSeen] is true once a rival has had a turn —
  /// the position is a leaf when the turn is back with the bot.
  double value(GameCore c, int chances, bool rivalSeen) {
    if (c.isOver || _clock.elapsedMicroseconds >= _deadlineUs) return evaluatePosition(c, me);
    final myTurn = _mine(c, c.current);
    if (c.phase == Phase.awaitRoll) {
      if ((myTurn && c.rollsTaken == 0 && rivalSeen) || chances <= 0) return evaluatePosition(c, me);
      var sum = 0.0;
      for (var v = 1; v <= 6; v++) {
        final n = c.clone();
        n.rollValue(v);
        sum += value(n, chances - 1, rivalSeen || !myTurn);
      }
      return sum / 6;
    }
    // awaitMove
    final moves = c.legalMoves();
    if (moves.isEmpty) {
      c.pass();
      return value(c, chances, rivalSeen || !myTurn);
    }
    if (myTurn && chances < _fullSearchChances) {
      c.play(pickByScore(c, moves, persons[c.current.index]));
      return value(c, chances, rivalSeen);
    }
    if (myTurn) {
      var best = double.negativeInfinity;
      for (final m in distinctMoves(moves)) {
        final n = c.clone();
        n.play(m);
        final v = value(n, chances, rivalSeen);
        if (v > best) best = v;
      }
      return best;
    }
    final m = pickByScore(c, moves, persons[c.current.index]);
    c.play(m);
    return value(c, chances, true);
  }
}
