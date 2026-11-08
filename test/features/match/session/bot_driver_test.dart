// BotDriver on REAL isolates (`isolateRun`, what the app uses): every other test runs the bots inline, so this is the one
// place that proves the work really crosses to another isolate — nothing unsendable captured — and comes back with a
// legal answer inside the engine's budget (Expert's search is capped at 300 ms).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/features/match/session/bot_driver.dart';

import 'session_rig.dart';

/// Yellow (a bot of [level]) has rolled [die] with pieces on the track: several different moves to choose from.
GameState _yellowToMove(BotLevel level, int die, {GameMode mode = GameMode.classic}) {
  final config = duel(mode: mode, first: Seat.yellow, level: level).config;
  final start = GameState.initial(config).withPieces(Seat.yellow, [9, 30, 14, -1]).withPieces(Seat.red, [20, 40, -1, -1]);
  final game = LudoGame.fromState(start.copyWith(current: Seat.yellow, phase: Phase.awaitRoll, firstSeat: Seat.yellow), dice: ScriptedDice([die]));
  game.apply(const Roll());
  return game.state;
}

void main() {
  for (final level in [BotLevel.hard, BotLevel.expert]) {
    test('${level.name} decides a move through a real isolate: legal, and within the engine\'s budget', () async {
      final s = _yellowToMove(level, 4);
      expect(legalMovesOf(s).map((m) => m.piece).toSet().length, greaterThan(1), reason: 'a real choice');
      final driver = BotDriver(rng: Random(3), offThread: isolateRun);
      final clock = Stopwatch()..start();
      final action = await driver.decide(s, s.config.playerOf(Seat.yellow));
      expect(action, isA<MovePiece>());
      expect(legalMovesOf(s), contains((action as MovePiece).move));
      expect(clock.elapsed, lessThan(const Duration(seconds: 3)), reason: 'the search is capped at ${BotBrain.defaultBudget.inMilliseconds} ms plus the isolate\'s start');
    });
  }

  test('Mayhem: a Hard bot asks the isolate about its cards too, and plays what comes back', () async {
    final s = _yellowToMove(BotLevel.hard, 4, mode: GameMode.mayhem);
    final driver = BotDriver(rng: Random(5), offThread: isolateRun);
    final action = await driver.decide(s, s.config.playerOf(Seat.yellow));
    expect(action, anyOf(isA<MovePiece>(), isA<UseCard>()));
  });

  test('the smart-move rating of a played move comes back from an isolate, deterministically', () async {
    final s = _yellowToMove(BotLevel.hard, 4);
    final move = legalMovesOf(s).first;
    final a = await rateInOther(isolateRun, s, move);
    final b = await rateInOther(inlineRun, s, move);
    expect(a.chosen, move);
    expect(a.scoreGap, b.scoreGap, reason: 'the same position and move always rate the same, whichever isolate does it');
    expect(a.matchedExpert, b.matchedExpert);
  });
}
