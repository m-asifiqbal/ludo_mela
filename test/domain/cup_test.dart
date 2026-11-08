// The Mela Cup (board Cup + C): a knockout of three 1-v-1 rounds against the 7 bots, one
// free run a day, a loss ends the run, a title pays 25 gems and a badge, and three cups
// earn the Champion Set. The bracket is decided by stored seeds, so it never changes.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' show BotLevel;
import 'package:ludo_mela/domain/cup.dart';

void main() {
  group('the field', () {
    test('seven bots with the names of the Cup board, strongest Nani', () {
      expect([for (final b in Cup.bots) b.name], ['Raja', 'Mitu', 'Tara', 'Golu', 'Nani', 'Pintu', 'Bindu']);
      expect({for (final b in Cup.bots) b.id}, hasLength(7));
      expect(Cup.bots.reduce((a, b) => a.strength > b.strength ? a : b).id, 'nani');
      expect(Cup.roundNames, ['Quarter-final', 'Semi-final', 'Final']);
      expect(Cup.bot('golu')!.name, 'Golu');
      expect(Cup.bot('you'), isNull);
    });

    test('bot strength: Normal, Hard, Expert by round; Nani is Expert-only', () {
      expect([for (var r = 0; r < 3; r++) Cup.levelFor(r, 'raja')], [BotLevel.normal, BotLevel.hard, BotLevel.expert]);
      expect(Cup.levelFor(0, 'nani'), BotLevel.expert);
      expect(Cup.levelFor(9, 'raja'), BotLevel.expert, reason: 'out of range is clamped');
    });

    test('a bracket has eight entrants — you first, the seven bots shuffled by the seed — and is the same for the same seed', () {
      final a = CupRun.create(42);
      expect(a.slots, hasLength(8));
      expect(a.slots.first, Cup.you);
      expect(a.slots.skip(1).toSet(), {for (final b in Cup.bots) b.id});
      expect(CupRun.create(42).slots, a.slots);
      expect({for (var s = 0; s < 30; s++) CupRun.create(s).slots.join()}.length, greaterThan(10));
      expect(a.isActive, isTrue);
      expect(a.round, 0);
      expect(a.roundsWon, 0);
    });

    test('you meet your neighbour first; the opponent\'s level follows the round', () {
      final run = CupRun(seed: 1, slots: const ['you', 'raja', 'mitu', 'tara', 'golu', 'nani', 'pintu', 'bindu']);
      expect(run.opponentId, 'raja');
      expect(run.opponentLevel, BotLevel.normal);
      expect(run.participants(0), run.slots);
      expect(run.participants(1), isEmpty, reason: 'not decided yet');
    });
  });

  group('playing a run', () {
    CupRun run() => const CupRun(seed: 7, slots: ['you', 'raja', 'mitu', 'tara', 'golu', 'nani', 'pintu', 'bindu']);

    test('winning all three rounds makes you champion; the field halves each round and you always meet someone new', () {
      var r = run();
      final met = <String>[];
      for (var round = 0; round < 3; round++) {
        expect(r.round, round);
        expect(r.participants(round), hasLength(8 >> round));
        expect(r.participants(round), contains(Cup.you));
        met.add(r.opponentId!);
        r = r.advance(playerWon: true);
      }
      expect(met.toSet(), hasLength(3));
      expect(r.status, CupStatus.champion);
      expect(r.isActive, isFalse);
      expect(r.roundsWon, 3);
      expect(r.opponentId, isNull);
      expect(r.winners.map((w) => w.length), [4, 2, 1]);
      expect(r.winners.last, [Cup.you]);
    });

    test('one loss ends the run in the round it happened', () {
      var r = run().advance(playerWon: true);
      r = r.advance(playerWon: false);
      expect(r.status, CupStatus.eliminated);
      expect(r.round, 1);
      expect(r.roundsWon, 1);
      expect(r.opponentId, isNull);
      expect(r.advance(playerWon: true), same(r), reason: 'a finished run does not move');
      expect(run().advance(playerWon: false).roundsWon, 0);
    });

    test('the other matches are decided once, by the seed: replaying the same results gives the same bracket after a restart', () {
      final a = run().advance(playerWon: true).advance(playerWon: true);
      final b = CupRun.fromJson(run().advance(playerWon: true).toJson())!.advance(playerWon: true);
      expect(b.winners, a.winners);
      expect(b.toJson(), a.toJson());
    });

    test('a stronger bot beats a weaker one more often (Nani 0.70 against Bindu 0.35 is about two in three)', () {
      var nani = 0;
      const n = 3000;
      for (var seed = 0; seed < n; seed++) {
        final r = CupRun(seed: seed, slots: const ['you', 'golu', 'nani', 'bindu', 'raja', 'mitu', 'tara', 'pintu']).advance(playerWon: true);
        if (r.winners.first[1] == 'nani') nani++;
      }
      expect(nani * 100 / n, closeTo(100 * 0.70 / (0.70 + 0.35), 3));
    });

    test('JSON round trips a run in progress; a stored bracket that is not valid is dropped', () {
      final r = run().advance(playerWon: true);
      final back = CupRun.fromJson(r.toJson())!;
      expect(back.toJson(), r.toJson());
      expect((back.seed, back.round, back.status), (r.seed, r.round, r.status));
      expect(CupRun.fromJson(null), isNull);
      expect(CupRun.fromJson({'slots': ['you', 'raja']}), isNull);
      expect(CupRun.fromJson({'slots': ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']}), isNull, reason: 'you are not in it');
    });
  });

  group('the cup state (one free run a day, titles, the Champion Set)', () {
    const today = '2026-11-07';

    test('the first run of the day is free and uses it up; a run cannot start while one is going', () {
      const s = CupState();
      expect(s.freeRunAvailable(today), isTrue);
      final (started, run) = s.start(today: today, seed: 5)!;
      expect(started.run, same(run));
      expect(started.hasActiveRun, isTrue);
      expect(started.runsStarted, 1);
      expect(started.freeRunAvailable(today), isFalse);
      expect(started.freeRunAvailable('2026-11-08'), isTrue, reason: 'a new day');
      expect(started.start(today: today, seed: 6), isNull, reason: 'one run at a time');
    });

    test('after a finished run another can start the same day (the caller charges 300 coins); the free day stays as it was', () {
      var s = const CupState().start(today: today, seed: 1)!.$1;
      s = s.advance(playerWon: false)!.state;
      expect(s.hasActiveRun, isFalse);
      final (again, _) = s.start(today: today, seed: 2)!;
      expect(again.lastFreeDay, today);
      expect(again.runsStarted, 2);
    });

    test('a title pays 25 gems and counts a cup; a loss pays nothing', () {
      var s = const CupState().start(today: today, seed: 3)!.$1;
      for (var i = 0; i < 2; i++) {
        final step = s.advance(playerWon: true)!;
        expect(step.grant.isEmpty, isTrue);
        expect(step.isChampion, isFalse);
        s = step.state;
      }
      final champ = s.advance(playerWon: true)!;
      expect(champ.isChampion, isTrue);
      expect(champ.grant.gems, 25);
      expect(champ.grant.items, isEmpty);
      expect(champ.state.cupsWon, 1);
      expect(champ.state.bestRounds, 3);
      expect(champ.wonMatch, isTrue);
      final lost = const CupState().start(today: today, seed: 3)!.$1.advance(playerWon: false)!;
      expect(lost.isEliminated, isTrue);
      expect(lost.grant.isEmpty, isTrue);
      expect(lost.state.cupsWon, 0);
    });

    test('the third cup also hands over the Champion Set', () {
      var s = const CupState(cupsWon: 2).start(today: today, seed: 4)!.$1;
      late CupAdvance last;
      for (var i = 0; i < 3; i++) {
        last = s.advance(playerWon: true)!;
        s = last.state;
      }
      expect(last.grant.gems, 25);
      expect(last.grant.items, ['champion']);
      expect(s.cupsWon, 3);
    });

    test('nothing to advance without an active run; abandoning clears it but keeps the counters', () {
      expect(const CupState().advance(playerWon: true), isNull);
      var s = const CupState(cupsWon: 1, bestRounds: 2).start(today: today, seed: 9)!.$1;
      final gone = s.abandon();
      expect(gone.run, isNull);
      expect((gone.cupsWon, gone.bestRounds, gone.runsStarted, gone.lastFreeDay), (1, 2, 1, today));
      expect(gone.advance(playerWon: true), isNull);
      s = gone;
      expect(s.hasActiveRun, isFalse);
    });

    test('JSON round trips; garbage loads as a fresh state', () {
      final s = const CupState(cupsWon: 2, bestRounds: 3).start(today: today, seed: 8)!.$1;
      final back = CupState.fromJson(s.toJson());
      expect((back.cupsWon, back.bestRounds, back.runsStarted, back.lastFreeDay), (2, 3, 1, today));
      expect(back.run!.slots, s.run!.slots);
      final junk = CupState.fromJson({'run': 'x', 'won': 'x', 'best': 99});
      expect(junk.run, isNull);
      expect(junk.cupsWon, 0);
      expect(junk.bestRounds, 3, reason: 'clamped');
    });
  });
}
