// LocalMatchSession on a hand-turned clock: bots take their turns, the turn timer plays AutoPlay, pause
// and the animation gate freeze everything, a killed match resumes from its autosave, and exactly one
// record is made at the end (a finished match, a left match, a Rush time-up).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';

import 'session_rig.dart';

void main() {
  const timer = Duration(seconds: 15);

  group('bots', () {
    test('a bot rolls after its beat, thinks, and gives the turn back to the person', () async {
      final r = Rig(duel(first: Seat.yellow));
      await r.timers.advance(Duration.zero);
      expect(r.actions, isEmpty, reason: 'the bot waits before pressing the die');
      await r.timers.advance(const Duration(milliseconds: 499));
      expect(r.actions, isEmpty);
      await r.timers.advance(const Duration(milliseconds: 2));
      expect(r.played<Roll>(), isTrue);
      await r.timers.seconds(30);
      expect(r.session.state.current, Seat.red, reason: 'the bot cannot go on forever');
      expect(r.session.state.phase, Phase.awaitRoll);
      expect(r.actions.whereType<MovePiece>().length + r.actions.whereType<Roll>().length, greaterThan(0));
      r.session.dispose();
    });

    test('think time is scaled by the game speed (2x: the 0.5 s beat before the die becomes 0.25 s)', () async {
      final turbo = Rig(duel(first: Seat.yellow), speed: 2);
      await turbo.timers.advance(const Duration(milliseconds: 240));
      expect(turbo.actions, isEmpty);
      await turbo.timers.advance(const Duration(milliseconds: 20));
      expect(turbo.played<Roll>(), isTrue);
      turbo.session.dispose();
    });

    test('Hard and Expert decide through the off-thread runner, with a fallback to AutoPlay on failure', () async {
      for (final level in [BotLevel.hard, BotLevel.expert]) {
        final r = Rig(duel(first: Seat.yellow, level: level));
        await r.timers.seconds(40);
        expect(r.played<Roll>(), isTrue, reason: '${level.name} rolled');
        expect(r.session.state.current, Seat.red);
        r.session.dispose();
      }
    });

    test("a failing isolate falls back to AutoPlay: the bot still plays", () async {
      Future<R> broken<R>(FutureOr<R> Function() c) => Future<R>.error(StateError("no isolate"));
      final r = Rig(duel(first: Seat.yellow, level: BotLevel.hard), dice: ScriptedDice([6], then: SeededDice(1)), offThread: broken);
      await r.timers.seconds(10);
      expect(r.played<Roll>(), isTrue);
      expect(r.played<AutoPlay>(), isTrue, reason: "the six had to be played without the isolate");
      r.session.dispose();
    });

    test("Mayhem: bots decide cards too, and the match never stalls", () async {
      for (final level in [BotLevel.normal, BotLevel.hard]) {
        final r = Rig(duel(mode: GameMode.mayhem, level: level), seed: 11);
        await r.humanPlays(steps: 1200);
        expect(r.session.state.isOver || r.actions.length > 200, isTrue, reason: "${level.name}: ${r.actions.length} actions");
        r.session.dispose();
      }
    });
  });

  group('turn timer', () {
    test('runs for the person, plays AutoPlay at zero, and restarts for the next decision', () async {
      final r = Rig(duel(turnTime: timer), dice: ScriptedDice([6], then: SeededDice(1)));
      await r.timers.advance(Duration.zero);
      final first = r.updates.lastWhere((u) => u.clock != null).clock!;
      expect(first.seat, Seat.red);
      expect(first.total, timer);
      expect(first.running, isTrue);
      await r.timers.seconds(14);
      expect(r.played<AutoPlay>(), isFalse);
      expect(r.session.clock!.remaining, const Duration(seconds: 1));
      await r.timers.seconds(1.1);
      expect(r.played<AutoPlay>(), isTrue);
      await r.timers.advance(Duration.zero);
      final next = r.session.clock;
      expect(next, isNotNull, reason: 'a new decision gets a new timer');
      expect(next!.remaining, greaterThan(const Duration(seconds: 14)));
      r.session.dispose();
    });

    test('there is none without a turn time, and none for bots', () async {
      final r = Rig(duel(first: Seat.yellow, turnTime: timer));
      await r.timers.advance(const Duration(milliseconds: 300));
      expect(r.session.clock, isNull, reason: "the bot is on turn");
      final free = Rig(duel());
      await free.timers.seconds(60);
      expect(free.actions, isEmpty, reason: 'no timer: the person may think forever');
      r.session.dispose();
      free.session.dispose();
    });

    test('pause freezes it, resuming gives back what was left', () async {
      final r = Rig(duel(turnTime: timer));
      await r.timers.seconds(10);
      r.session.setPaused(true);
      await r.timers.advance(Duration.zero);
      expect(r.session.clock!.running, isFalse);
      expect(r.session.clock!.remaining, const Duration(seconds: 5));
      await r.timers.seconds(120);
      expect(r.played<AutoPlay>(), isFalse);
      r.session.setPaused(false);
      await r.timers.seconds(4.9);
      expect(r.played<AutoPlay>(), isFalse);
      await r.timers.seconds(0.2);
      expect(r.played<AutoPlay>(), isTrue);
      r.session.dispose();
    });

    test('does not run while the screen animates; starts when it is idle', () async {
      final r = Rig(duel(turnTime: timer));
      r.session.setAnimating(true);
      await r.timers.seconds(60);
      expect(r.session.clock, isNull);
      expect(r.actions, isEmpty);
      r.session.setAnimating(false);
      await r.timers.seconds(14.9);
      expect(r.actions, isEmpty);
      await r.timers.seconds(0.3);
      expect(r.played<AutoPlay>(), isTrue);
      r.session.dispose();
    });
  });

  group('gates', () {
    test('pause holds the bot; it starts its beat over after resuming', () async {
      final r = Rig(duel(first: Seat.yellow));
      await r.timers.advance(const Duration(milliseconds: 300));
      r.session.setPaused(true);
      await r.timers.seconds(10);
      expect(r.actions, isEmpty);
      r.session.setPaused(false);
      await r.timers.advance(const Duration(milliseconds: 499));
      expect(r.actions, isEmpty);
      await r.timers.advance(const Duration(milliseconds: 2));
      expect(r.played<Roll>(), isTrue);
      r.session.dispose();
    });

    test('a bot waits while the screen animates, then plays', () async {
      final r = Rig(duel(first: Seat.yellow));
      r.session.setAnimating(true);
      await r.timers.seconds(20);
      expect(r.actions, isEmpty);
      r.session.setAnimating(false);
      await r.timers.advance(const Duration(milliseconds: 501));
      expect(r.played<Roll>(), isTrue);
      r.session.dispose();
    });

    test('a person cannot act when it is not their turn, when paused, or with an illegal move', () async {
      final r = Rig(duel(first: Seat.yellow));
      await r.session.roll();
      expect(r.actions, isEmpty, reason: 'the bot is on turn');
      r.session.dispose();
      final p = Rig(duel());
      p.session.setPaused(true);
      await p.session.roll();
      expect(p.actions, isEmpty);
      p.session.setPaused(false);
      await p.session.move(const Move(seat: Seat.red, piece: 0, from: -1, to: 0, die: 6, kind: MoveKind.enter));
      expect(p.actions, isEmpty, reason: 'a move before the roll is ignored');
      await p.session.roll();
      expect(p.played<Roll>(), isTrue);
      p.session.dispose();
    });

    test('the clock publishes start, freeze and resume; a new action clears it', () async {
      final r = Rig(duel(turnTime: timer));
      await r.timers.seconds(3);
      r.session.setPaused(true);
      await r.timers.advance(Duration.zero);
      r.session.setPaused(false);
      await r.timers.advance(Duration.zero);
      final clocks = [for (final u in r.updates) if (u.action == null && u.sticker == null) u.clock];
      expect(clocks.map((c) => c?.running), [true, false, true]);
      await r.session.roll();
      await r.timers.advance(Duration.zero);
      expect(r.updates.firstWhere((u) => u.action is Roll).clock, isNull);
      r.session.dispose();
    });
  });

  group('autosave and resume', () {
    test('every action is saved and a new session continues from it, tally included', () async {
      final a = Rig(duel(), seed: 5);
      await a.session.roll();
      await a.timers.advance(Duration.zero);
      expect(a.memory.hasSave, isTrue);
      final saved = await a.autosave.load();
      expect(saved, isNotNull);
      expect(jsonEncode(saved!.state.toJson()), jsonEncode(a.session.state.toJson()));
      expect(saved.setup.id, 'm1');
      a.session.dispose();

      final b = Rig(duel(), seed: 9, resume: saved);
      expect(b.session.state, a.session.state);
      await b.session.concede();
      expect(b.records, hasLength(1));
      expect(b.records.single.rolls, 1, reason: 'the roll before the kill is still counted');
      expect(b.records.single.id, 'm1');
      expect(b.memory.hasSave, isFalse, reason: 'cleared when the match ends');
    });

    test('a running match stays saved when the session is disposed, with the play time', () async {
      final a = Rig(duel());
      await a.timers.seconds(90);
      a.session.dispose();
      final saved = await a.autosave.load();
      expect(saved, isNotNull);
      expect(saved!.played, const Duration(seconds: 90));
    });

    test('a saved Rush match keeps its clock', () async {
      final a = Rig(duel(mode: GameMode.rush, rushTime: const Duration(minutes: 5)));
      await a.session.roll();
      await a.timers.seconds(100);
      a.session.dispose();
      final saved = (await a.autosave.load())!;
      expect(saved.rushLeft, const Duration(seconds: 200));
      final b = Rig(duel(mode: GameMode.rush), resume: saved);
      await b.timers.advance(Duration.zero);
      expect(b.session.rushClock!.remaining, const Duration(seconds: 200));
      b.session.dispose();
    });

    test('a puzzle is never saved or recorded', () async {
      final a = Rig(duel(puzzle: true));
      await a.session.roll();
      expect(a.memory.saves, 0);
      await a.session.concede();
      expect(a.records, isEmpty);
    });
  });

  group('the end', () {
    test('a finished match makes exactly one record, once the screen is idle, and clears the save', () async {
      final r = Rig(duel(mode: GameMode.quick), seed: 3);
      await r.humanPlays();
      expect(r.session.state.isOver, isTrue);
      await r.timers.seconds(5);
      expect(r.records, hasLength(1));
      final rec = r.records.single;
      expect(rec.mode, GameMode.quick);
      expect(rec.abandoned, isFalse);
      expect(rec.id, 'm1');
      expect([for (final s in rec.seats) s.place]..sort(), [1, 2]);
      expect(rec.mySeat, Seat.red);
      expect(rec.seats.firstWhere((s) => s.seat == Seat.yellow).botId, 'raja');
      expect(rec.seats.firstWhere((s) => s.seat == Seat.red).profileId, 'p1');
      final rolled = [
        for (final u in r.updates)
          for (final e in u.events)
            if (e is RolledEvent && e.seat == Seat.red && !e.helping) e,
      ];
      expect(rec.rolls, rolled.length);
      expect(rec.turns, greaterThan(0));
      expect(rec.race.map((s) => s.seat), containsAll([Seat.red, Seat.yellow]));
      expect(r.memory.hasSave, isFalse);
      await r.timers.seconds(60);
      expect(r.records, hasLength(1), reason: 'never a second record');
      await r.session.concede();
      expect(r.records, hasLength(1));
      r.session.dispose();
    });

    test('the record waits while the screen is still animating the last events', () async {
      final r = Rig(duel(mode: GameMode.quick), seed: 3);
      // Like the screen: the moment the final events arrive it starts animating them.
      r.session.updates.listen((u) {
        if (u.state.isOver) r.session.setAnimating(true);
      });
      await r.humanPlays();
      expect(r.session.state.isOver, isTrue);
      await r.timers.seconds(30);
      expect(r.records, isEmpty);
      r.session.setAnimating(false);
      await r.timers.seconds(1);
      expect(r.records, hasLength(1));
      r.session.dispose();
    });

    test('leaving is a recorded loss, the match ends at once, and it is recorded only once', () async {
      final r = Rig(duel(), seed: 2);
      await r.session.roll();
      await r.session.concede();
      await r.session.concede();
      expect(r.records, hasLength(1));
      final rec = r.records.single;
      expect(rec.abandoned, isTrue);
      expect(rec.myPlace, 2);
      expect(r.session.state.isOver, isTrue);
      expect(r.session.state.overReason, GameOverReason.conceded);
      expect(r.memory.hasSave, isFalse);
      await r.timers.seconds(30);
      expect(r.records, hasLength(1));
      r.session.dispose();
    });

    test('Rush: the clock runs out and RushTimeUp ends the match; pause stops the clock', () async {
      final r = Rig(duel(mode: GameMode.rush));
      await r.timers.advance(Duration.zero);
      expect(r.session.rushClock!.running, isTrue);
      await r.timers.seconds(60);
      r.session.setPaused(true);
      await r.timers.seconds(3600);
      expect(r.session.state.isOver, isFalse, reason: 'a paused clock does not run');
      expect(r.session.rushClock!.running, isFalse);
      r.session.setPaused(false);
      await r.timers.seconds(238);
      expect(r.session.state.isOver, isFalse, reason: '60 + 238 s of 300');
      await r.timers.seconds(3);
      expect(r.session.state.isOver, isTrue);
      expect(r.session.state.overReason, GameOverReason.timeUp);
      await r.timers.seconds(1);
      expect(r.records, hasLength(1));
      r.session.dispose();
    });

    test('Rush time-up waits for the animation gate', () async {
      final r = Rig(duel(mode: GameMode.rush, rushTime: const Duration(seconds: 10)));
      r.session.setAnimating(true);
      await r.timers.seconds(30);
      expect(r.session.state.isOver, isFalse);
      expect(r.session.rushClock!.remaining, Duration.zero);
      r.session.setAnimating(false);
      await r.timers.seconds(1);
      expect(r.session.state.isOver, isTrue);
      r.session.dispose();
    });

    test('the match ends at once, by progress, when nobody of this phone is still playing', () async {
      // Three seats: red (a person) is one step from finishing, two bots race on.
      final setup = MatchSetup(
        config: MatchConfig(
          mode: GameMode.classic,
          firstSeat: Seat.red,
          players: const [
            PlayerSpec(seat: Seat.red, name: 'Mitu', id: 'p1'),
            PlayerSpec(seat: Seat.green, name: 'Mitu', kind: PlayerKind.bot, level: BotLevel.easy),
            PlayerSpec(seat: Seat.yellow, name: 'Tara', kind: PlayerKind.bot, level: BotLevel.easy),
          ],
        ),
        id: 'm1',
      );
      final nearly = GameState.initial(setup.config).withPieces(Seat.red, [56, 56, 56, 55]);
      final r = Rig(setup, dice: ScriptedDice([1]), resume: SavedMatch(setup: setup, state: nearly));
      await r.session.roll();
      await r.session.move(legalMovesOf(r.session.state).single);
      await r.timers.seconds(2);
      expect(r.session.state.isOver, isTrue, reason: 'the bots do not race for the places below');
      expect(r.session.state.overReason, GameOverReason.byProgress);
      expect(r.session.state.placements.first, Seat.red);
      await r.timers.seconds(1);
      expect(r.records, hasLength(1));
      expect(r.records.single.myPlace, 1);
      expect(r.records.single.won, isTrue);
      r.session.dispose();
    });
  });
}
