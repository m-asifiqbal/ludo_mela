// Dice sources, rules presets and match configuration: fairness of FairDice,
// determinism of SeededDice, scripting, and the validation of seatings.

import 'dart:convert';

import 'package:ludo_engine/ludo_engine.dart';
import 'package:test/test.dart';

void main() {
  group('dice', () {
    test('FairDice is uniform over 1..6 (chi-square, 12000 rolls)', () {
      final dice = FairDice();
      final counts = List.filled(7, 0);
      for (var i = 0; i < 12000; i++) {
        counts[dice.roll()]++;
      }
      expect(counts[0], 0);
      var chi = 0.0;
      for (var f = 1; f <= 6; f++) {
        chi += (counts[f] - 2000) * (counts[f] - 2000) / 2000;
      }
      expect(chi, lessThan(35), reason: 'df=5: 35 is p ~ 1e-6, so a fair die never fails this by luck; counts $counts');
    });

    test('SeededDice repeats, differs by seed, stays in 1..6', () {
      final a = SeededDice(5);
      final b = SeededDice(5);
      final c = SeededDice(6);
      final ra = [for (var i = 0; i < 200; i++) a.roll()];
      expect([for (var i = 0; i < 200; i++) b.roll()], ra);
      expect([for (var i = 0; i < 200; i++) c.roll()], isNot(ra));
      expect(ra.every((v) => v >= 1 && v <= 6), isTrue);
    });

    test('SeededDice is SplitMix64: the same rolls on every device and Dart version', () {
      // Pinned against an independent BigInt implementation. If this fails, daily puzzles and saved
      // replays would change under people's feet: do not "fix" the vectors, fix the generator.
      const expected = {
        0: [4, 1, 4, 3, 4, 4, 3, 5, 6, 2, 1, 6, 2, 2, 3, 4],
        1: [3, 4, 4, 6, 5, 5, 5, 5, 1, 6, 5, 6, 5, 6, 3, 6],
        42: [1, 4, 4, 1, 6, 4, 1, 5, 1, 2, 6, 6, 2, 4, 5, 2],
        -5: [6, 5, 5, 2, 6, 5, 2, 3, 1, 6, 2, 2, 5, 6, 5, 4],
      };
      for (final e in expected.entries) {
        final d = SeededDice(e.key);
        expect([for (var i = 0; i < 16; i++) d.roll()], e.value, reason: 'seed ${e.key}');
      }
    });

    test('SeededDice is uniform over 1..6 (chi-square, 12000 rolls)', () {
      final d = SeededDice(2024);
      final counts = List.filled(7, 0);
      for (var i = 0; i < 12000; i++) {
        counts[d.roll()]++;
      }
      var chi = 0.0;
      for (var v = 1; v <= 6; v++) {
        chi += (counts[v] - 2000) * (counts[v] - 2000) / 2000;
      }
      expect(chi, lessThan(35), reason: 'df=5; counts $counts');
    });

    test('ScriptedDice replays, tracks what is left, then falls back or throws', () {
      final d = ScriptedDice([3, 1, 6]);
      expect(d.remaining, 3);
      expect([d.roll(), d.roll(), d.roll()], [3, 1, 6]);
      expect(d.roll, throwsStateError);
      d.add([2]);
      expect(d.roll(), 2);
      final f = ScriptedDice([4], then: SeededDice(1));
      expect(f.roll(), 4);
      expect(f.roll(), inInclusiveRange(1, 6));
      expect(() => ScriptedDice([7]), throwsArgumentError);
      expect(() => ScriptedDice([0]), throwsArgumentError);
    });

    test('RecordingDice logs and NoDice refuses', () {
      final r = RecordingDice(ScriptedDice([2, 5]));
      r.roll();
      r.roll();
      expect(r.rolls, [2, 5]);
      expect(const NoDice().roll, throwsStateError);
    });
  });

  group('rules', () {
    test('classic defaults', () {
      const r = Rules();
      expect(r.sixToEnter && r.bonusOnSix && r.bonusOnCapture && r.bonusOnHome, isTrue);
      expect(r.threeSixesForfeit && r.exactHome && r.autoPass, isTrue);
      expect(r.blockades || r.gentleCaptures || r.helpingDice || r.captureBeforeLane || r.startOut, isFalse);
      expect(r.quickTarget, 1);
    });

    test('Rules.forMode presets', () {
      expect(Rules.forMode(GameMode.classic), const Rules());
      expect(Rules.forMode(GameMode.mayhem), const Rules());
      expect(Rules.forMode(GameMode.teams), const Rules());
      expect(Rules.forMode(GameMode.quick).startOut, isTrue);
      expect(Rules.forMode(GameMode.rush).startOut, isTrue);
      final master = Rules.forMode(GameMode.master);
      expect(master.blockades && master.captureBeforeLane, isTrue);
      expect(master.startOut, isFalse);
    });

    test('house rules are merged under the mode presets', () {
      const house = Rules(gentleCaptures: true, sixToEnter: false, quickTarget: 2);
      final quick = Rules.forMode(GameMode.quick, house: house);
      expect(quick.gentleCaptures && !quick.sixToEnter && quick.startOut && quick.quickTarget == 2, isTrue);
      final master = Rules.forMode(GameMode.master, house: house);
      expect(master.gentleCaptures && master.blockades && master.captureBeforeLane, isTrue);
    });

    test('JSON round trip, missing keys fall back to classic, quickTarget is clamped', () {
      const r = Rules(blockades: true, helpingDice: true, quickTarget: 3, exactHome: false);
      expect(Rules.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>), r);
      expect(Rules.fromJson(const {}), const Rules());
      expect(Rules.fromJson(const {'quickTarget': 99}).quickTarget, 4);
      expect(Rules.fromJson(const {'quickTarget': -5}).quickTarget, 1);
      expect(() => Rules.fromJson(const {'sixToEnter': 'yes'}), throwsFormatException);
      expect(r.copyWith(blockades: false).blockades, isFalse);
      expect(r.copyWith(quickTarget: 2).hashCode, isNot(r.hashCode));
    });
  });

  group('match config', () {
    PlayerSpec p(Seat s, [PlayerKind k = PlayerKind.human]) => PlayerSpec(seat: s, name: s.name, kind: k);

    test('players are kept clockwise whatever order they come in', () {
      final c = MatchConfig(mode: GameMode.classic, players: [p(Seat.blue), p(Seat.red), p(Seat.yellow)]);
      expect(c.seats, [Seat.red, Seat.yellow, Seat.blue]);
      expect(c.rules, Rules.forMode(GameMode.classic));
      expect(c.hasSeat(Seat.green), isFalse);
      expect(c.playerOf(Seat.blue).name, 'blue');
      expect(c.tryPlayerOf(Seat.green), isNull);
      expect(() => c.playerOf(Seat.green), throwsArgumentError);
    });

    test('two players must sit opposite each other, any opposite pair works', () {
      MatchConfig(mode: GameMode.classic, players: [p(Seat.green), p(Seat.blue)]);
      MatchConfig(mode: GameMode.classic, players: [p(Seat.red), p(Seat.yellow)]);
      expect(() => MatchConfig(mode: GameMode.classic, players: [p(Seat.red), p(Seat.green)]), throwsArgumentError);
    });

    test('player counts and seat clashes are rejected', () {
      expect(() => MatchConfig(mode: GameMode.classic, players: [p(Seat.red)]), throwsArgumentError);
      expect(() => MatchConfig(mode: GameMode.teams, players: [p(Seat.red), p(Seat.yellow)]), throwsArgumentError);
      expect(() => MatchConfig(mode: GameMode.classic, players: [p(Seat.red), p(Seat.red)]), throwsArgumentError);
      expect(
        () => MatchConfig(mode: GameMode.classic, players: [p(Seat.red), p(Seat.yellow)], firstSeat: Seat.blue),
        throwsArgumentError,
      );
      MatchConfig(mode: GameMode.teams, players: [for (final s in Seat.values) p(s)]);
    });

    test('teams: red + yellow vs green + blue', () {
      final c = MatchConfig.generic(mode: GameMode.teams, count: 4);
      expect([for (final s in Seat.values) c.teamOf(s)], [0, 1, 0, 1]);
      expect(c.isTeams, isTrue);
    });

    test('generic helper seats and kinds', () {
      expect(MatchConfig.generic(count: 2).seats, [Seat.red, Seat.yellow]);
      expect(MatchConfig.generic(count: 3).seats, [Seat.red, Seat.green, Seat.yellow]);
      expect(MatchConfig.generic(count: 4).seats, Seat.values);
      final c = MatchConfig.generic(count: 2, level: BotLevel.hard);
      expect(c.players.first.kind, PlayerKind.human);
      expect(c.players.last.kind, PlayerKind.bot);
      expect(c.players.last.level, BotLevel.hard);
      expect(MatchConfig.generic(count: 2, allBots: true).players.every((q) => q.isBot), isTrue);
      expect(() => MatchConfig.generic(count: 5), throwsArgumentError);
    });

    test('JSON round trip keeps everything, copyWith changes one thing', () {
      final c = MatchConfig(
        mode: GameMode.mayhem,
        rules: const Rules(gentleCaptures: true),
        firstSeat: Seat.green,
        players: [
          PlayerSpec(seat: Seat.red, name: 'Asif', id: 'p1', avatar: 'cat'),
          PlayerSpec(seat: Seat.green, name: 'Raja', kind: PlayerKind.bot, level: BotLevel.expert, personality: 'raja'),
          PlayerSpec(seat: Seat.yellow, name: 'Friend', kind: PlayerKind.remote),
        ],
      );
      final back = MatchConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, Object?>);
      expect(back, c);
      expect(back.hashCode, c.hashCode);
      expect(c.copyWith(clearFirstSeat: true).firstSeat, isNull);
      expect(c.copyWith(mode: GameMode.classic).mode, GameMode.classic);
      expect(() => MatchConfig.fromJson(const {'mode': 'nope', 'players': []}), throwsFormatException);
    });
  });
}
