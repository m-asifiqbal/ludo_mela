// Mela Mayhem bots: when to play which power card.
//
// Why these cases: the card logic has three promises. It is sensible (reroll a roll that
// cannot be played, never throw away a six that can; Double before rolling), it is
// characterful (Golu keeps a Double until his hand is full and pounces on every Swap the
// others would pass over) and it is level-aware (Easy forgets or misplays cards a third of the
// time, Expert never). The boards are hand-built where the answer is exact and sampled from
// seeded self-play where a rate is the claim. That the cards help at all is measured by the
// arena in bot_strength_test.dart (a bot with cards beats the same bot without).

import 'dart:math';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

import 'bot_support.dart';
import 'mayhem_support.dart';
import 'support.dart' show cfg, scene;

final _noMove = mscene(
  pieces: {Seat.red: yardOnly, Seat.yellow: yardOnly},
  phase: Phase.awaitMove,
  pending: [3],
  hands: {Seat.red: [PowerCard.reroll]},
); // a 3 with every piece in the yard: nothing to play
final _playableSix = mscene(
  pieces: {Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly},
  phase: Phase.awaitMove,
  pending: [6],
  hands: {Seat.red: [PowerCard.reroll]},
);
final _doubleAlone = mscene(
  pieces: {Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly},
  hands: {Seat.red: [PowerCard.double]},
);
final _doubleFullHand = mscene(
  pieces: {Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly},
  hands: {Seat.red: [PowerCard.double, PowerCard.hop3]},
);

/// What an Expert (never slips) of [p] plays in [s].
CardUse? plays(GameState s, BotPersonality p) => BotBrain(BotLevel.expert, p).chooseCard(s, Random(1));

void main() {
  group('when there is nothing to decide', () {
    test('no cards outside Mayhem, none with an empty hand, none when the match is over or in the roll-off', () {
      final classic = scene(cfg(), pieces: {Seat.red: [10, -1, -1, -1]});
      expect(BotBrain(BotLevel.hard).chooseCard(classic, Random(1)), isNull);
      final empty = mscene(pieces: {Seat.red: [10, -1, -1, -1], Seat.yellow: yardOnly});
      expect(BotBrain(BotLevel.hard).chooseCard(empty, Random(1)), isNull);
      final over = _doubleAlone.copyWith(phase: Phase.gameOver, placements: [Seat.red, Seat.yellow]);
      expect(BotBrain(BotLevel.hard).chooseCard(over, Random(1)), isNull);
      final rollOff = _doubleAlone.copyWith(phase: Phase.rollOff);
      expect(BotBrain(BotLevel.hard).chooseCard(rollOff, Random(1)), isNull);
    });

    test('a card the rules do not allow right now is never chosen (Double after the roll, one card per turn)', () {
      final doubleAfterRoll = _playableSix.copyWith(mayhem: mayhemOf(hands: {Seat.red: [PowerCard.double]}));
      expect(legalCardUsesOf(doubleAfterRoll), isEmpty);
      expect(plays(doubleAfterRoll, BotPersonality.raja), isNull);
      final alreadyPlayed = _doubleAlone.copyWith(mayhem: mayhemOf(hands: {Seat.red: [PowerCard.double]}, cardPlayed: true));
      expect(plays(alreadyPlayed, BotPersonality.raja), isNull);
    });
  });

  group('sensible plays', () {
    test('reroll a roll that cannot be played — every character does', () {
      expect(legalMovesOf(_noMove), isEmpty);
      for (final p in BotPersonality.presets) {
        expect(plays(_noMove, p), const CardUse.reroll(), reason: p.id);
      }
    });

    test('never reroll a six that can be played', () {
      expect(legalMovesOf(_playableSix), isNotEmpty);
      for (final p in BotPersonality.presets) {
        expect(plays(_playableSix, p), isNull, reason: p.id);
      }
    });

    test('Double before the roll when there are pieces to use it on', () {
      for (final p in BotPersonality.presets.where((p) => p != BotPersonality.golu)) {
        expect(plays(_doubleAlone, p), const CardUse.doubleDice(), reason: p.id);
      }
    });

    test('the plan is a legal card use, and applying it works', () {
      final positions = samplePositions(mode: GameMode.mayhem, games: 20, seed: 8, keep: (c) => holdsCards(c, 2) || holdsCards(c, 1), oneIn: 6);
      expect(positions.length, greaterThan(30));
      var played = 0;
      for (final s in positions) {
        for (final level in BotLevel.values) {
          final use = BotBrain(level, BotPersonality.presets[s.turnNumber % 6]).chooseCard(s, Random(s.turnNumber));
          if (use == null) continue;
          played++;
          expect(legalCardUsesOf(s), contains(use), reason: '${level.name} at turn ${s.turnNumber}: $use');
          LudoGame.fromState(s, dice: SeededDice(1)).apply(UseCard(use)); // throws if illegal
        }
      }
      expect(played, greaterThan(20), reason: 'the sample must actually contain card plays');
    });
  });

  group('Golu: hoards, loves Swap', () {
    test('keeps a Double while his hand has room; spends it once the hand is full (a draw would be lost)', () {
      expect(plays(_doubleAlone, BotPersonality.golu), isNull);
      expect(plays(_doubleFullHand, BotPersonality.golu), const CardUse.doubleDice());
      expect(plays(_doubleAlone, BotPersonality.raja), const CardUse.doubleDice(), reason: 'the others play it at once');
    });

    test('plays a Swap whenever one is legal and not harmful; the others pass it over', () {
      final swappable = samplePositions(
        mode: GameMode.mayhem,
        games: 60,
        seed: 6,
        keep: (c) =>
            (c.phase == Phase.awaitRoll || c.phase == Phase.awaitMove) &&
            c.handOf(c.current).contains(PowerCard.swap) &&
            c.legalCardUses().any((u) => u.card == PowerCard.swap),
        oneIn: 3,
      );
      expect(swappable.length, greaterThan(150));
      double swapRate(BotPersonality p) =>
          swappable.where((s) => plays(s, p)?.card == PowerCard.swap).length / swappable.length;
      final golu = swapRate(BotPersonality.golu);
      final others = [for (final p in BotPersonality.presets.where((p) => p != BotPersonality.golu)) swapRate(p)];
      expect(golu, greaterThan(0.5), reason: 'golu $golu');
      expect(golu, greaterThan(3 * others.reduce(max)), reason: 'golu $golu vs others $others');
    });
  });

  group('the levels slip with cards too', () {
    test('Easy keeps or misplays a card about 17 % of the time, Normal 8 %, Hard 2.5 %, Expert never', () {
      // Slips are "do nothing" or a random legal play; with one legal play that is a coin flip, so a reroll that
      // should be played is played 1 - rate / 2 of the time.
      double rerolls(BotLevel level) {
        final brain = BotBrain(level);
        final rng = Random(77);
        var n = 0;
        for (var i = 0; i < 4000; i++) {
          if (brain.chooseCard(_noMove, rng) == const CardUse.reroll()) n++;
        }
        return n / 4000;
      }

      expect(rerolls(BotLevel.expert), 1.0);
      expect(rerolls(BotLevel.hard), closeTo(1 - 0.05 / 2, 0.015));
      expect(rerolls(BotLevel.normal), closeTo(1 - 0.15 / 2, 0.02));
      expect(rerolls(BotLevel.easy), closeTo(1 - 0.35 / 2, 0.025));
    });
  });
}
