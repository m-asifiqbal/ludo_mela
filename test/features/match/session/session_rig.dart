// Shared setup for the match-session tests (not a test file: no _test suffix).
//
// [FakeTimers] is the hand-turned clock the session runs on: `advance(d)` moves time forward, running
// every timer that falls due in order and letting async work settle in between. [Rig] builds a
// LocalMatchSession on it with seeded dice, a seeded Random, bots thinking inline (no isolate), an
// in-memory autosave and a list collecting records and updates.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/match_record.dart';
import 'package:ludo_mela/features/match/session/bot_driver.dart';
import 'package:ludo_mela/features/match/session/local_match_session.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_session.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/session/session_timers.dart';

class _Task implements SessionTimer {
  _Task(this.at, this.order, this.callback);

  final Duration at;
  final int order;
  final void Function() callback;
  bool cancelled = false;

  @override
  void cancel() => cancelled = true;
}

class FakeTimers implements SessionTimers {
  Duration _now = Duration.zero;
  final List<_Task> _tasks = [];
  int _order = 0;

  @override
  Duration get now => _now;

  @override
  SessionTimer after(Duration delay, void Function() callback) {
    final t = _Task(_now + delay, _order++, callback);
    _tasks.add(t);
    return t;
  }

  /// Time moves on by [d]: due timers run in order, and microtasks / streams settle around each.
  Future<void> advance(Duration d) async {
    final end = _now + d;
    while (true) {
      await pumpEventQueue();
      final due = _tasks.where((t) => !t.cancelled && t.at <= end).toList()
        ..sort((a, b) => a.at != b.at ? a.at.compareTo(b.at) : a.order.compareTo(b.order));
      if (due.isEmpty) break;
      final next = due.first;
      _tasks.remove(next);
      if (next.at > _now) _now = next.at;
      next.callback();
    }
    _now = end;
    await pumpEventQueue();
  }

  Future<void> seconds(num s) => advance(Duration(milliseconds: (s * 1000).round()));
}

/// A two-player game: Mitu (a person, red) against Raja (a bot, yellow).
MatchSetup duel({
  GameMode mode = GameMode.classic,
  Seat? first = Seat.red,
  BotLevel level = BotLevel.normal,
  Duration? turnTime,
  Duration rushTime = MatchSetup.defaultRushTime,
  bool puzzle = false,
}) => MatchSetup(
  config: MatchConfig(
    mode: mode,
    firstSeat: first,
    players: [
      const PlayerSpec(seat: Seat.red, name: 'Mitu', id: 'p1'),
      PlayerSpec(seat: Seat.yellow, name: 'Raja', kind: PlayerKind.bot, level: level, personality: 'raja'),
    ],
  ),
  turnTime: turnTime,
  rushTime: rushTime,
  puzzle: puzzle,
  id: 'm1',
);

class Rig {
  Rig(
    this.setup, {
    int seed = 1,
    Dice? dice,
    double speed = 1,
    SavedMatch? resume,
    MatchAutosave? autosave,
    OffThread? offThread,
    bool stickersOn = true,
    bool botStickersOn = true,
  })
    : autosave = autosave ?? MemoryMatchAutosave() {
    session = LocalMatchSession(
      setup: setup,
      resume: resume,
      dice: dice ?? SeededDice(seed),
      speed: () => speed,
      stickersOn: () => stickersOn,
      botStickersOn: () => botStickersOn,
      random: Random(7),
      timers: timers,
      offThread: offThread ?? inlineRun,
      autosave: this.autosave,
      onFinished: records.add,
    );
    session.updates.listen(updates.add);
  }

  final MatchSetup setup;
  final FakeTimers timers = FakeTimers();
  final MatchAutosave autosave;
  final List<MatchRecord> records = [];
  final List<MatchUpdate> updates = [];
  late final LocalMatchSession session;

  MemoryMatchAutosave get memory => autosave as MemoryMatchAutosave;

  /// The actions applied so far, in order.
  List<Action> get actions => [
    for (final u in updates)
      if (u.action != null) u.action!,
  ];

  bool played<T extends Action>() => actions.any((a) => a is T);

  /// The person (red) plays on: rolls, moves the first legal piece, passes when stuck.
  Future<void> humanPlays({int steps = 4000, Duration step = const Duration(milliseconds: 700)}) async {
    for (var i = 0; i < steps && !session.state.isOver; i++) {
      final s = session.state;
      if (s.current == Seat.red) {
        if (s.phase == Phase.awaitRoll) {
          await session.roll();
        } else if (s.phase == Phase.awaitMove) {
          final legal = legalMovesOf(s);
          legal.isEmpty ? await session.pass() : await session.move(legal.first);
        }
      }
      await timers.advance(step);
    }
  }
}
