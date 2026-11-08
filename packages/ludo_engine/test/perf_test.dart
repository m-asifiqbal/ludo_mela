// Speed of the simulation path. The Expert bot runs ~200 Monte-Carlo rollouts
// per candidate move inside a 300 ms budget, so the core must play thousands of
// simulated turns in a few hundred milliseconds: `GameCore.clone` + `roll` /
// `legalMoves` / `play` / `pass`, with no events and no snapshots.
//
// The bounds below are deliberately generous (a loaded CI box is 5-10x slower
// than a laptop); the printed numbers are the real measurement.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Plays [core] with random moves for at most [turns] turns; returns the turns played.
int playout(GameCore core, Random rng, int turns) {
  final start = core.turnNumber;
  while (!core.isOver && core.turnNumber - start < turns) {
    if (core.phase == Phase.awaitRoll) {
      core.roll();
    } else {
      final moves = core.legalMoves();
      if (moves.isEmpty) {
        core.pass();
      } else {
        core.play(moves[rng.nextInt(moves.length)]);
      }
    }
  }
  return core.turnNumber - start;
}

/// A 4-player position a couple of hundred turns in, with pieces all over the board.
GameCore midGame(GameMode mode, int seed) {
  var s = seed;
  while (true) {
    final core = GameCore(cfg(mode: mode, count: 4), SeededDice(s++));
    playout(core, Random(s), 220);
    if (!core.isOver) return core;
  }
}

void main() {
  for (final mode in [GameMode.classic, GameMode.mayhem]) {
    test('${mode.name}: random playouts run at thousands of turns per 100 ms', () {
      final base = midGame(mode, 1);
      final rng = Random(2);
      var turns = 0;
      final sw = Stopwatch()..start();
      var rollouts = 0;
      while (sw.elapsedMilliseconds < 400) {
        final c = base.clone(dice: SeededDice(rollouts));
        turns += playout(c, rng, 30);
        rollouts++;
      }
      final perSecond = turns * 1000 / sw.elapsedMilliseconds;
      // ignore: avoid_print
      print(
        '${mode.name}: $rollouts rollouts, $turns turns in ${sw.elapsedMilliseconds} ms '
        '= ${perSecond.round()} turns/s (${(rollouts * 1000 / sw.elapsedMilliseconds).round()} rollouts/s)',
      );
      expect(perSecond, greaterThan(15000), reason: 'Expert needs ~20,000 simulated turns per move decision in 300 ms');
    });
  }

  test('a full Expert-sized decision: 4 candidate moves x 200 rollouts x 25 turns', () {
    final base = midGame(GameMode.classic, 5);
    final rng = Random(6);
    // find a position with several legal moves
    while (base.phase == Phase.awaitRoll || base.legalMoves().length < 2) {
      if (base.isOver) break;
      if (base.phase == Phase.awaitRoll) {
        base.roll();
      } else if (base.legalMoves().isEmpty) {
        base.pass();
      } else {
        base.play(base.legalMoves().first);
      }
    }
    final moves = base.legalMoves();
    final sw = Stopwatch()..start();
    var turns = 0;
    for (final m in moves) {
      for (var i = 0; i < 200; i++) {
        final c = base.clone(dice: SeededDice(i));
        c.play(m);
        turns += playout(c, rng, 25);
      }
    }
    final ms = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('decision over ${moves.length} moves: $turns turns in $ms ms');
    expect(ms, lessThan(3000));
  });

  test('legalMoves and analysis stay cheap', () {
    final base = midGame(GameMode.classic, 9);
    while (base.phase == Phase.awaitRoll) {
      base.roll();
    }
    final sw = Stopwatch()..start();
    var n = 0;
    while (sw.elapsedMilliseconds < 200) {
      for (final m in base.legalMoves()) {
        base.insightOf(m);
        n++;
      }
    }
    // ignore: avoid_print
    print('insightOf: ${(n * 1000 / sw.elapsedMilliseconds).round()} moves/s');
    expect(n, greaterThan(100));
  });
}
