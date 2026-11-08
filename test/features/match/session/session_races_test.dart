// Races inside LocalMatchSession: bots, the turn timer, the animation gate, pause, kills and resumes happening in the
// worst orders. Targeted cases first (a late isolate answer, a gate closing under a decision), then a chaos run that
// throws random pauses, gates, taps and kills at whole matches and checks what must always hold: the match never
// stalls, the autosave is the position, a finished match makes exactly one record, a paused match does not move.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';

import 'session_rig.dart';

/// An off-thread runner whose answers arrive when the test says so (a slow isolate).
class _SlowIsolate {
  final List<void Function()> _waiting = [];

  int get waiting => _waiting.length;

  Future<R> run<R>(FutureOr<R> Function() computation) {
    final done = Completer<R>();
    _waiting.add(() => done.complete(computation()));
    return done.future;
  }

  /// Answers every request made so far.
  void answerAll() {
    final now = List.of(_waiting);
    _waiting.clear();
    for (final answer in now) {
      answer();
    }
  }
}

String _json(GameState s) => jsonEncode(s.toJson());

/// What the chaos run says: stickers and phrases.
const _chat = ['happy', 'cool', 'Well played!', 'Oops!'];

void main() {
  group('a slow bot', () {
    test('an answer that arrives after a pause is dropped; the bot decides again after resuming and plays once', () async {
      final slow = _SlowIsolate();
      final r = Rig(duel(first: Seat.yellow, level: BotLevel.hard), dice: ScriptedDice([6], then: SeededDice(1)), offThread: slow.run);
      await r.timers.seconds(1); // the beat before the die is over: the bot rolled
      expect(r.played<Roll>(), isTrue);
      await r.timers.advance(Duration.zero);
      expect(slow.waiting, 1, reason: 'Hard decides its move off the UI thread');

      r.session.setPaused(true);
      slow.answerAll();
      await r.timers.seconds(5);
      expect(r.actions.whereType<MovePiece>(), isEmpty, reason: 'a paused match does not move, whatever arrives');

      r.session.setPaused(false);
      await r.timers.advance(Duration.zero);
      expect(slow.waiting, 1, reason: 'a fresh decision for the same position');
      slow.answerAll();
      await r.timers.seconds(2);
      expect(r.actions.whereType<MovePiece>(), hasLength(1));
      r.session.dispose();
    });

    test('an answer that arrives while the screen animates is dropped too, then the bot plays once', () async {
      final slow = _SlowIsolate();
      final r = Rig(duel(first: Seat.yellow, level: BotLevel.hard), dice: ScriptedDice([6], then: SeededDice(1)), offThread: slow.run);
      await r.timers.seconds(1);
      r.session.setAnimating(true);
      slow.answerAll();
      await r.timers.seconds(5);
      expect(r.actions.whereType<MovePiece>(), isEmpty);
      r.session.setAnimating(false);
      await r.timers.advance(Duration.zero);
      slow.answerAll();
      await r.timers.seconds(2);
      expect(r.actions.whereType<MovePiece>(), hasLength(1));
      r.session.dispose();
    });

    test('an answer that arrives after the session is disposed or the match left changes nothing', () async {
      final slow = _SlowIsolate();
      final r = Rig(duel(first: Seat.yellow, level: BotLevel.hard), dice: ScriptedDice([6], then: SeededDice(1)), offThread: slow.run);
      await r.timers.seconds(1);
      final before = r.actions.length;
      await r.session.concede();
      slow.answerAll();
      await r.timers.seconds(5);
      expect(r.actions.length, before + 1, reason: 'only the Concede');
      expect(r.records, hasLength(1));
      r.session.dispose();
    });
  });

  group('the gates', () {
    test('a turn timer that reaches zero in the same moment as the gate closes plays at most once', () async {
      final r = Rig(duel(turnTime: const Duration(seconds: 15)), dice: ScriptedDice([6], then: SeededDice(1)));
      await r.timers.seconds(14);
      r.session.setAnimating(true);
      await r.timers.seconds(5);
      expect(r.played<AutoPlay>(), isFalse, reason: 'the clock froze with a second left');
      r.session.setAnimating(false);
      await r.timers.seconds(1.1);
      expect(r.actions.whereType<AutoPlay>(), hasLength(1));
      r.session.dispose();
    });

    test('pause and the animation gate together: opening one does not open the other', () async {
      final r = Rig(duel(first: Seat.yellow));
      r.session.setPaused(true);
      r.session.setAnimating(true);
      await r.timers.seconds(10);
      r.session.setAnimating(false);
      await r.timers.seconds(10);
      expect(r.actions, isEmpty, reason: 'still paused');
      r.session.setPaused(false);
      r.session.setAnimating(true);
      await r.timers.seconds(10);
      expect(r.actions, isEmpty, reason: 'still animating');
      r.session.setAnimating(false);
      await r.timers.seconds(1);
      expect(r.played<Roll>(), isTrue);
      r.session.dispose();
    });

    test('Rush: pausing during the last second of the clock holds the time-up until the resume', () async {
      final r = Rig(duel(mode: GameMode.rush, rushTime: const Duration(seconds: 10)));
      await r.timers.advance(const Duration(milliseconds: 9500));
      r.session.setPaused(true);
      await r.timers.seconds(60);
      expect(r.session.state.isOver, isFalse);
      r.session.setPaused(false);
      await r.timers.seconds(1);
      expect(r.session.state.isOver, isTrue);
      expect(r.session.state.overReason, GameOverReason.timeUp);
      await r.timers.seconds(1);
      expect(r.records, hasLength(1));
      r.session.dispose();
    });

    test('leaving while paused and animating still ends the match and records it once', () async {
      final r = Rig(duel());
      r.session.setPaused(true);
      r.session.setAnimating(true);
      await r.session.concede();
      await r.timers.seconds(5);
      expect(r.records, hasLength(1));
      expect(r.records.single.abandoned, isTrue);
      expect(r.memory.hasSave, isFalse);
      r.session.dispose();
    });
  });

  group('kills and resumes', () {
    test('a match that was over when the app died is recorded by the next session, once', () async {
      final autosave = MemoryMatchAutosave();
      final first = Rig(duel(mode: GameMode.quick), seed: 3, autosave: autosave);
      // The screen never finishes animating the last events: the app is killed on the verdict.
      first.session.updates.listen((u) {
        if (u.state.isOver) first.session.setAnimating(true);
      });
      await first.humanPlays();
      expect(first.session.state.isOver, isTrue);
      expect(first.records, isEmpty);
      first.session.dispose();

      final saved = await autosave.load();
      expect(saved, isNotNull, reason: 'a finished but unrecorded match stays saved');
      final second = Rig(duel(mode: GameMode.quick), autosave: autosave, resume: saved);
      await second.timers.seconds(5);
      expect(second.records, hasLength(1));
      expect(second.records.single.id, 'm1');
      expect(autosave.hasSave, isFalse);
      second.session.dispose();
    });

    test('a resumed session continues the saved position exactly, whatever the first one was doing', () async {
      final autosave = MemoryMatchAutosave();
      final first = Rig(duel(first: Seat.yellow, level: BotLevel.hard), autosave: autosave);
      await first.timers.seconds(3);
      first.session.dispose();
      final saved = (await autosave.load())!;
      expect(_json(saved.state), _json(first.session.state));
      final second = Rig(duel(first: Seat.yellow, level: BotLevel.hard), autosave: autosave, resume: saved);
      expect(_json(second.session.state), _json(first.session.state));
      await second.timers.seconds(20);
      expect(second.session.state.turnNumber, greaterThanOrEqualTo(first.session.state.turnNumber));
      second.session.dispose();
    });
  });

  group('chaos', () {
    /// One match under random pauses, gates, taps and kills; returns every record made.
    Future<List<MatchRecord>> chaos(int seed, {required GameMode mode, required BotLevel level, bool timer = false}) async {
      final rng = Random(seed);
      final autosave = MemoryMatchAutosave();
      final rigs = <Rig>[];
      Rig start([SavedMatch? resume]) {
        final r = Rig(
          duel(mode: mode, level: level, turnTime: timer ? const Duration(seconds: 15) : null, rushTime: const Duration(minutes: 2)),
          seed: seed * 31 + rigs.length,
          resume: resume,
          autosave: autosave,
        );
        rigs.add(r);
        return r;
      }

      var r = start();
      var animating = false;
      for (var i = 0; i < 900 && !r.session.state.isOver; i++) {
        final s = r.session;
        switch (rng.nextInt(12)) {
          case 0:
            s.setPaused(!s.paused);
          case 1:
            animating = !animating;
            s.setAnimating(animating);
          case 2:
            if (rng.nextInt(4) == 0) {
              // Kill the app and come back: a new session from the autosave.
              s.dispose();
              final saved = await autosave.load();
              if (saved == null) break;
              r = start(saved);
              animating = false;
            }
          case 3 || 4 || 5:
            if (s.state.current == Seat.red) {
              if (s.state.phase == Phase.awaitRoll || s.state.phase == Phase.rollOff) {
                await s.roll();
              } else if (s.state.phase == Phase.awaitMove) {
                final legal = legalMovesOf(s.state);
                legal.isEmpty ? await s.pass() : await s.move(legal[rng.nextInt(legal.length)]);
              }
            }
          case 6:
            s.sendSticker(Seat.red, _chat[rng.nextInt(_chat.length)]);
          default:
            final before = r.actions.length;
            final held = s.paused || animating;
            await r.timers.advance(Duration(milliseconds: 50 + rng.nextInt(2500)));
            if (held) {
              expect(r.actions.length, before, reason: 'seed $seed: nothing moves while paused or animating');
            }
        }
        // The autosave is always the position (the session saves every action).
        await r.timers.advance(Duration.zero);
        final saved = await autosave.load();
        if (saved != null && !r.session.state.isOver) {
          expect(_json(saved.state), _json(r.session.state), reason: 'seed $seed, step $i: the autosave is the position');
        }
      }
      // Everybody lets go: the match must finish by itself (the person plays on), and make one record.
      r.session.setPaused(false);
      r.session.setAnimating(false);
      await r.humanPlays(steps: 3000);
      await r.timers.seconds(10);
      expect(r.session.state.isOver, isTrue, reason: 'seed $seed: the match never stalls');
      r.session.dispose();
      return [for (final rig in rigs) ...rig.records];
    }

    for (final mode in [GameMode.quick, GameMode.classic, GameMode.mayhem]) {
      for (final level in [BotLevel.normal, BotLevel.hard]) {
        test('${mode.name} against a ${level.name} bot: every seed finishes with exactly one record', () async {
          for (var seed = 1; seed <= 6; seed++) {
            final records = await chaos(seed, mode: mode, level: level, timer: seed.isEven);
            expect(records, hasLength(1), reason: 'seed $seed');
            expect(records.single.id, 'm1');
            expect(records.single.abandoned, isFalse);
          }
        });
      }
    }

    test('Rush with a short clock: the time-up comes once, whatever was paused', () async {
      for (var seed = 1; seed <= 5; seed++) {
        final records = await chaos(seed, mode: GameMode.rush, level: BotLevel.normal);
        expect(records, hasLength(1), reason: 'seed $seed');
      }
    });
  });
}
