// How long the bots think.
//
// Why: the design promises Expert "≤ 0.3 s" per decision (200 Monte-Carlo rollouts inside a
// 300 ms budget) and the match screen runs Hard on the UI thread. So: on positions from real
// 4-player self-play in every mode (the heaviest tables), Expert must finish inside its
// budget, its full 200-rollout search must itself fit in 300 ms (so the budget is a safety
// net, not the thing that decides), and Hard must stay far below a frame budget in the
// typical case and below the budget in the worst. Bounds leave room for a loaded machine
// (these tests run next to others); the printed numbers are the real measurement.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';

/// Milliseconds of every decision of [decide] over [positions].
List<double> times(List<GameState> positions, void Function(GameState s, List<Move> legal) decide) {
  final out = <double>[];
  final sw = Stopwatch();
  for (final s in positions) {
    final legal = legalMovesOf(s);
    sw
      ..reset()
      ..start();
    decide(s, legal);
    out.add(sw.elapsedMicroseconds / 1000);
  }
  out.sort();
  return out;
}

double percentile(List<double> sorted, double p) => sorted[((sorted.length - 1) * p).round()];

String summary(String name, List<double> t) =>
    '$name: n=${t.length}, median ${percentile(t, 0.5).toStringAsFixed(1)} ms, p90 ${percentile(t, 0.9).toStringAsFixed(1)}, '
    'max ${t.last.toStringAsFixed(1)}';

void main() {
  // Positions from 4-player self-play in every mode, once for the whole file.
  final positions = <GameState>[
    for (final mode in GameMode.values)
      ...samplePositions(mode: mode, players: 4, games: 3, seed: 51, oneIn: 14).take(14),
  ];

  test('there are enough positions to say something', () {
    expect(positions.length, greaterThan(50));
  });

  test('Expert with its default budget (300 ms) answers inside it, mode by mode', () {
    final rng = Random(1);
    final brain = BotBrain(BotLevel.expert);
    // Warm up the JIT: the first calls of a fresh process are not what a running app sees.
    for (final s in positions.take(6)) {
      brain.chooseMove(s, legalMovesOf(s), rng);
    }
    final t = times(positions, (s, legal) => brain.chooseMove(s, legal, rng));
    // ignore: avoid_print
    print(summary('expert, default budget', t));
    expect(t.last, lessThan(400), reason: 'budget 300 ms + one round of rollouts + a loaded machine');
    expect(percentile(t, 0.5), lessThan(300));
  });

  test('Expert\'s full 200 rollouts per move fit in 300 ms on this machine (p90), so the budget is only a safety net', () {
    final brain = BotBrain(BotLevel.expert);
    var seed = 0;
    final rollouts = <int>[];
    final t = times(positions, (s, legal) {
      final options = distinctMoves(legal);
      if (options.length < 2) return;
      final r = brain.search(s, options, seed++, budget: const Duration(seconds: 30));
      rollouts.add(r.rollouts);
    });
    // ignore: avoid_print
    print(summary('expert, 200 rollouts, no clock', t));
    expect(rollouts.every((n) => n == defaultRollouts), isTrue, reason: 'the cap, not the clock, ended each search');
    expect(percentile(t, 0.9), lessThan(300));
  });

  test('a short budget is honoured: 20 ms in, about 20 ms (plus a round) out — with at least 8 rollouts played', () {
    final brain = BotBrain(BotLevel.expert);
    final rng = Random(2);
    final t = times(positions, (s, legal) => brain.chooseMove(s, legal, rng, budget: const Duration(milliseconds: 20)));
    // ignore: avoid_print
    print(summary('expert, 20 ms budget', t));
    expect(percentile(t, 0.9), lessThan(120));
    final s = positions.firstWhere((s) => distinctMoves(legalMovesOf(s)).length > 1);
    final r = brain.search(s, distinctMoves(legalMovesOf(s)), 1, budget: Duration.zero);
    expect(r.rollouts, 8, reason: 'a zero budget still plays the minimum');
  });

  test('Hard: milliseconds in the typical case, never past its budget', () {
    final rng = Random(3);
    final brain = BotBrain(BotLevel.hard);
    for (final s in positions.take(6)) {
      brain.chooseMove(s, legalMovesOf(s), rng);
    }
    final t = times(positions, (s, legal) => brain.chooseMove(s, legal, rng));
    // ignore: avoid_print
    print(summary('hard', t));
    expect(percentile(t, 0.5), lessThan(60));
    expect(t.last, lessThan(400));
  });

  test('Easy and Normal are instant', () {
    final rng = Random(4);
    for (final level in [BotLevel.easy, BotLevel.normal]) {
      final brain = BotBrain(level);
      final t = times(positions, (s, legal) => brain.chooseMove(s, legal, rng));
      expect(percentile(t, 0.9), lessThan(25), reason: level.name);
    }
  });
}
