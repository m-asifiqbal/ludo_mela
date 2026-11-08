// The one move score every bot shares (design board B):
//
//   score = 0.5·run·to + 50 (leave yard) + 80 (reach home) + 30 (enter lane)
//         + 18·safe (land on a star) + 90·hunt (capture)
//         + 28·safe·(threat before − threat after) + noise
//
// Why one formula: Easy picks among its scores at random, Normal takes the best, Hard
// and Expert use it as a prior and as the rollout policy, and a personality is only
// a set of weights on it. `threat` is the number of rival pieces 1–6 squares behind a
// square that could land there with the next roll (Normal and below); Hard and
// Expert also count "6, then k" (7–12 squares) at 1/36 each, which is exactly
// `6 × hitChance` from the engine's analysis. The noise term is the level's
// mistake rate (personality.dart) rather than a number added here.

import '../analysis/move_insight.dart';
import '../engine/core.dart';
import '../geometry.dart';
import '../model/move.dart';
import '../state/game_state.dart';
import 'personality.dart';

/// The constants of the formula, in "squares" of progress.
abstract final class BotScore {
  static const double progress = 0.5;
  static const double leaveYard = 50;
  static const double reachHome = 80;
  static const double enterLane = 30;
  static const double landOnStar = 18;
  static const double capture = 90;
  static const double threatDelta = 28;
}

/// Scores [m], a legal move in [core]'s position, for a bot with personality [p].
///
/// With an [insight] (from `core.insightOf(m)`) the numbers are exact — Shields,
/// blocks and Teams pairs count as safe; without one it is the cheap version the
/// rollouts use (threats from the rivals' distances, safe = a star or start).
/// [deep] switches to Hard/Expert threat counting (`6 × hit chance`, which includes
/// "6, then k"); it needs an [insight].
double scoreMove(GameCore core, Move m, BotPersonality p, {MoveInsight? insight, bool deep = false}) {
  var s = BotScore.progress * p.run * GameState.effectiveProgress(m.to);
  if (m.isEnter) s += BotScore.leaveYard;
  if (m.to == Board.home) s += BotScore.reachHome;
  if (m.from <= Board.lastLoop && m.to >= Board.firstLane) s += BotScore.enterLane;
  final idx = Board.loopIndexOrNone(m.seat, m.to);
  if (idx >= 0 && !m.isEnter) {
    final safe = insight?.has(MoveTag.safe) ?? core.isSafeSquare(idx);
    if (safe) s += BotScore.landOnStar * p.safe;
  }
  s += BotScore.capture * p.hunt * m.captures.length;
  final double before;
  final double after;
  if (insight == null) {
    before = core.threatsOnPiece(m.seat, m.piece).toDouble();
    after = idx >= 0 ? core.threatsAtSquare(m.seat, idx).toDouble() : 0;
  } else if (deep) {
    before = 6 * core.hitChanceOfPiece(m.seat, m.piece);
    after = 6 * insight.hitChance;
  } else {
    before = insight.threatsBefore.toDouble();
    after = insight.threatsAfter.toDouble();
  }
  return s + BotScore.threatDelta * p.safe * (before - after);
}

/// The exact score of every move in [moves] (each analysed once with `insightOf`).
List<double> scoreMoves(GameCore core, List<Move> moves, BotPersonality p, {bool deep = false}) => [
  for (final m in moves) scoreMove(core, m, p, insight: core.insightOf(m), deep: deep),
];

/// The best-scoring move by the cheap formula — the rollout policy (no cloning).
/// Ties go to the first move.
Move pickByScore(GameCore core, List<Move> moves, BotPersonality p) {
  var best = moves.first;
  var bestScore = double.negativeInfinity;
  for (final m in moves) {
    final s = scoreMove(core, m, p);
    if (s > bestScore) {
      bestScore = s;
      best = m;
    }
  }
  return best;
}

/// One of each group of moves that look identical on the board (two pieces in the
/// yard, two on one square) — the choices that actually differ.
List<Move> distinctMoves(List<Move> moves) {
  final out = <Move>[];
  for (final m in moves) {
    if (!out.any((o) => o.looksLike(m))) out.add(m);
  }
  return out;
}
