// Bots play whole matches on the real engine, in every mode.
//
// Why: the unit tests show single decisions; this shows the bots hold up for hundreds of
// consecutive ones in every mode and seating the app offers. Every answer goes through
// `LudoGame.apply`, which throws on an illegal move or card, so "the bot only ever says legal
// things" is checked the way the match screen will use it. Levels and personalities are mixed
// at the table (and Expert gets 5 ms, which still plays its minimum of eight rollouts), the
// matches must end, and the usual engine invariants must hold at the end.

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A table of [count] bots in [mode]: seat i plays level (i + [shift]) % 4 with personality (i + [shift]) % 6.
MatchConfig table(GameMode mode, int count, int shift) {
  final base = MatchConfig.generic(mode: mode, count: count, firstSeat: Seat.red, allBots: true);
  return base.copyWith(
    players: [
      for (final (i, p) in base.players.indexed)
        p.copyWith(
          kind: PlayerKind.bot,
          level: BotLevel.values[(i + shift) % 4],
          personality: BotPersonality.presets[(i + shift) % 6].id,
        ),
    ],
  );
}

/// Plays [config] to the end with its bots; returns the final state and how many decisions were real choices.
(GameState, int) playOut(
  MatchConfig config, {
  required int diceSeed,
  required int botSeed,
  int maxTurns = 500,
  Duration budget = const Duration(milliseconds: 5),
}) {
  final game = LudoGame(config, dice: SeededDice(diceSeed));
  final rng = Random(botSeed);
  var choices = 0;
  var cards = 0;
  while (!game.state.isOver) {
    final s = game.state;
    if (s.turnNumber >= maxTurns) {
      game.apply(config.mode == GameMode.rush ? const RushTimeUp() : const FinishByProgress());
      break;
    }
    final spec = config.playerOf(s.current);
    final brain = BotBrain(spec.level!, BotPersonality.byId(spec.personality));
    if (config.mode == GameMode.mayhem && s.mayhem!.handOf(s.current).isNotEmpty) {
      final use = brain.chooseCard(s, rng);
      if (use != null) {
        cards++;
        game.apply(UseCard(use)); // throws if the bot invented a play
        continue;
      }
    }
    if (s.phase == Phase.awaitRoll) {
      game.apply(const Roll());
      continue;
    }
    final legal = game.legalMoves();
    if (legal.isEmpty) {
      game.apply(const PassTurn());
      continue;
    }
    if (distinctMoves(legal).length > 1) choices++;
    game.apply(MovePiece(brain.chooseMove(s, legal, rng, budget: budget)));
  }
  if (config.mode == GameMode.mayhem) expect(cards, greaterThan(0), reason: 'no card was ever played');
  return (game.state, choices);
}

void main() {
  final tables = <(GameMode, int)>[
    (GameMode.classic, 2),
    (GameMode.classic, 3),
    (GameMode.classic, 4),
    (GameMode.quick, 2),
    (GameMode.quick, 4),
    (GameMode.master, 2),
    (GameMode.master, 4),
    (GameMode.rush, 2),
    (GameMode.rush, 4),
    (GameMode.mayhem, 2),
    (GameMode.mayhem, 3),
    (GameMode.mayhem, 4),
    (GameMode.teams, 4),
  ];
  for (final (mode, count) in tables) {
    test('${mode.name}, $count bots of mixed levels and characters: legal all the way, and the match ends', () {
      var choices = 0;
      for (var seed = 0; seed < 3; seed++) {
        final (end, c) = playOut(table(mode, count, seed + count), diceSeed: seed * 13 + count, botSeed: seed + 100);
        checkInvariants(end);
        expect(end.isOver, isTrue);
        choices += c;
      }
      expect(choices, greaterThan(60), reason: 'the bots had real decisions to make');
    });
  }

  test('the same table, the same seeds: the same match (bots add no hidden randomness)', () {
    // A generous budget: with a tight one the clock, not only the bot, would end the search.
    final config = table(GameMode.mayhem, 4, 0).copyWith(
      players: [for (final p in table(GameMode.mayhem, 4, 0).players) p.copyWith(level: BotLevel.hard)],
    );
    const long = Duration(seconds: 30);
    final a = playOut(config, diceSeed: 5, botSeed: 6, budget: long).$1;
    final b = playOut(config, diceSeed: 5, botSeed: 6, budget: long).$1;
    expect(a.toJson(), b.toJson());
    final c = playOut(config, diceSeed: 5, botSeed: 7, budget: long).$1;
    expect(c.toJson(), isNot(a.toJson()), reason: 'another bot seed plays another match');
  });
}
