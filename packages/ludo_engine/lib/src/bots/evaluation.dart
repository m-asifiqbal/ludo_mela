// How good is a position for one seat? The leaf value of Hard's expectimax, the
// horizon value of Expert's rollouts and the yardstick for power-card plays.
//
// Units are squares of progress. The core is "my progress minus the rivals'" (for the
// rivals: half the strongest plus half the average, so a 4-player table is not
// reduced to one opponent); Quick counts only the pieces that matter for its target,
// Rush counts points. On top of that sits risk: each piece that can be captured
// loses what it has travelled plus the wait for a 6, weighted by its hit chance from
// the engine's analysis — my exposed pieces count against me, rival pieces that I am
// about to roll at count for me, and whoever moves next can still fix part of its own
// exposure. Terminal positions are decided outright.

import 'dart:math' as math;

import '../config/game_mode.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../state/game_state.dart';

/// Squares a captured piece loses on top of its progress: the wait for a 6 to re-enter.
const double _reentryCost = 6;

/// Value of [c] for [me] in squares: positive = [me] (or its team) is ahead.
double evaluatePosition(GameCore c, Seat me) {
  final teams = c.config.isTeams;
  int sideOf(Seat s) => teams ? s.index & 1 : s.index;
  final mySide = sideOf(me);
  if (c.isOver) return _terminal(c, me, sideOf);

  final totals = [0.0, 0.0, 0.0, 0.0];
  final present = [false, false, false, false];
  for (final s in c.seats) {
    totals[sideOf(s)] += _progress(c, s);
    present[sideOf(s)] = true;
  }
  var rivalBest = 0.0;
  var rivalSum = 0.0;
  var rivals = 0;
  for (var side = 0; side < 4; side++) {
    if (!present[side] || side == mySide) continue;
    rivals++;
    rivalSum += totals[side];
    if (totals[side] > rivalBest) rivalBest = totals[side];
  }
  var v = totals[mySide] - (rivals == 0 ? 0 : 0.5 * rivalBest + 0.5 * rivalSum / rivals);

  // Whoever moves next can still rescue part of its exposure and is first to strike.
  final myTurn = sideOf(c.current) == mySide;
  final wMine = myTurn ? 0.5 : 1.0;
  final wTheirs = myTurn ? 1.0 : 0.5;
  for (final seat in c.seats) {
    final mine = sideOf(seat) == mySide;
    for (var i = 0; i < 4; i++) {
      final p = c.progressOf(seat, i);
      if (p < 0 || (p > Board.lastLoop && p != Board.wrap)) continue; // yard, lane, home
      if (c.isProtected(seat, i)) continue;
      final hit = c.hitChanceOfPiece(seat, i);
      if (hit == 0) continue;
      final loss = (GameState.effectiveProgress(p) + 1) + _reentryCost;
      v += mine ? -wMine * hit * loss : wTheirs * hit * loss;
    }
  }

  if (c.mode == GameMode.mayhem) {
    var mineCards = 0;
    var theirCards = 0;
    for (final s in c.seats) {
      final n = c.handOf(s).length;
      if (sideOf(s) == mySide) {
        mineCards += n;
      } else {
        theirCards += n;
      }
    }
    v += 4.0 * (mineCards - (rivals == 0 ? 0 : theirCards / rivals));
  }
  if (c.rules.captureBeforeLane) {
    // Master: the first capture unlocks the home lane.
    for (final s in c.seats) {
      if (c.hasCapturedBy(s)) v += sideOf(s) == mySide ? 12 : -12;
    }
  }
  return v;
}

/// What a seat has to show in the current mode.
double _progress(GameCore c, Seat s) {
  switch (c.mode) {
    case GameMode.rush:
      return c.rushScoreOf(s).toDouble();
    case GameMode.quick:
      // Only the pieces that must get home count (the rest barely matter).
      final p = [for (var i = 0; i < 4; i++) GameState.effectiveProgress(c.progressOf(s, i)) + 1]
        ..sort((a, b) => b.compareTo(a));
      final target = c.rules.quickTarget.clamp(1, 4);
      var sum = 0.0;
      for (var i = 0; i < 4; i++) {
        sum += p[i] * (i < target ? 1.0 : 0.15);
      }
      return sum;
    case GameMode.classic || GameMode.master || GameMode.mayhem || GameMode.teams:
      return c.totalProgressOf(s).toDouble();
  }
}

double _terminal(GameCore c, Seat me, int Function(Seat) sideOf) {
  final order = c.placements;
  if (order.isEmpty) return 0; // time up / stalemate without a finisher
  if (sideOf(order.first) == sideOf(me)) return 1000;
  final rank = order.indexOf(me);
  final n = c.seats.length;
  if (rank < 0 || n < 2) return -1000;
  return 1000 - 2000 * rank / (n - 1);
}

/// Squares → a 0 … 1 chance-like value (logistic). 30 squares ahead is about 73 %.
double winEquity(double value) => 1 / (1 + math.exp(-value / 30));
