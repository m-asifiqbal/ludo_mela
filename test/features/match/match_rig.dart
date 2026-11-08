// Shared setup for the match-board widget tests (a helper, not a test file: no _test suffix).
//
// `pumpMatch` mounts MatchScreen at /match on the shared screen harness (app theme, frame, silent feedback, 390 x 844
// phone with a notch) with a REAL LocalMatchSession: scripted dice, bots thinking inline, no autosave, and a
// position you can hand-build (`position:`). The session reaches the screen the way a Wi-Fi session does, through
// `PendingMatch.custom`, so nothing in the screen is faked. Time is the test clock: `tester.pump(duration)` moves bot
// think times, hops and toasts.
//
// `MatchBed` bundles what a test needs afterwards: the container, the session (to read the state or play for a bot)
// and the navigation log (`nav.went` holds '/lobby' after leaving).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/domain/settings.dart';
import 'package:ludo_mela/features/match/match_screen.dart';
import 'package:ludo_mela/features/match/session/bot_driver.dart' show inlineRun;
import 'package:ludo_mela/features/match/session/local_match_session.dart';
import 'package:ludo_mela/features/match/session/match_autosave.dart';
import 'package:ludo_mela/features/match/session/match_navigation.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/session/pending_match.dart';
import 'package:ludo_mela/features/match/session/session_timers.dart';

import '../../helpers/screen_harness.dart';

/// A navigation log standing in for the app router (`went` = root changes such as /lobby).
class Nav {
  final pushed = <String>[];
  final went = <String>[];
  late final MatchNavigation nav = MatchNavigation(push: pushed.add, go: went.add);
}

/// Hands the screen a match that is already pending (what `startMatch` leaves behind).
class _Pending extends PendingMatchNotifier {
  _Pending(this._pending);

  final PendingMatch? _pending;

  @override
  PendingMatch? build() => _pending;
}

/// Mitu (red, a person) against bots on the other seats; [firstSeat] skips the roll-off.
MatchSetup botGame({
  GameMode mode = GameMode.classic,
  int players = 4,
  Seat? firstSeat = Seat.red,
  Duration? turnTime = MatchSetup.vsTurnTime,
  bool practice = true,
  String? venueId,
  Rules? rules,
}) => MatchSetup.vsBots(
  mode: mode,
  name: 'Mitu',
  avatar: 'parrot',
  profileId: 'p1',
  players: players,
  firstSeat: firstSeat,
  turnTime: turnTime,
  practice: practice,
  venueId: venueId,
  rules: rules,
);

/// Four people around one phone lying on the table.
MatchSetup tabletopGame({GameMode mode = GameMode.classic, Seat? firstSeat = Seat.red}) => MatchSetup.passAndPlay(
  mode: mode,
  firstSeat: firstSeat,
  tabletop: true,
  players: const [
    PlayerSpec(seat: Seat.red, name: 'Player', avatar: 'cat'),
    PlayerSpec(seat: Seat.green, name: 'Nadia', avatar: 'fox'),
    PlayerSpec(seat: Seat.yellow, name: 'Rafi', avatar: 'panda'),
    PlayerSpec(seat: Seat.blue, name: 'Nani', avatar: 'elephant'),
  ],
);

/// A session whose record cannot be saved: concede() ends the match and then fails.
class _FailsToConcede extends LocalMatchSession {
  _FailsToConcede({required super.setup, super.resume, super.dice, super.timers, super.offThread, super.autosave, super.onFinished});

  @override
  Future<void> concede() async {
    await super.concede();
    throw StateError('the save is full');
  }
}

/// A mounted board and the handles a test needs.
class MatchBed {
  MatchBed(this.container, this.session, this.nav, this.setup);

  final ProviderContainer container;
  final LocalMatchSession session;
  final Nav nav;
  final MatchSetup setup;

  GameState get state => session.state;
}

/// Mounts the board for [setup] (default: a classic game of four) and settles its first frames.
///
/// [position] builds the state to start from (a hand-placed board); [dice] feeds the rolls (anything past the script
/// is seeded); [reduceMotion] switches Reduce Motion on in Settings.
Future<MatchBed> pumpMatch(
  WidgetTester tester, {
  MatchSetup? setup,
  GameState Function(GameState start)? position,
  Dice? dice,
  List<int>? rolls,
  bool reduceMotion = false,
  SaveData? save,
  double? textScale,
  List<Override> overrides = const [],
  int settleFrames = 30,
  bool concedeFails = false,
}) async {
  final game = (setup ?? botGame()).normalized(newId: () => 'm1', profileId: 'p1');
  final start = position?.call(GameState.initial(game.config));
  final nav = Nav();
  late LocalMatchSession session;
  final pending = PendingMatch(
    game,
    resume: start == null ? null : SavedMatch(setup: game, state: start),
    custom: (ref) {
      final resume = start == null ? null : SavedMatch(setup: game, state: start);
      final fate = dice ?? (rolls == null ? SeededDice(11) : ScriptedDice(rolls, then: SeededDice(11)));
      final timers = _TestTimers(tester);
      final record = ref.read(matchRecorderProvider).publish;
      return session = concedeFails
          ? _FailsToConcede(setup: game, resume: resume, dice: fate, offThread: inlineRun, timers: timers, autosave: MemoryMatchAutosave(), onFinished: record)
          : LocalMatchSession(setup: game, resume: resume, dice: fate, offThread: inlineRun, timers: timers, autosave: MemoryMatchAutosave(), onFinished: record);
    },
  );
  final container = await pumpScreen(
    tester,
    (context, state) => const MatchScreen(),
    location: Routes.match,
    save: save,
    reduceMotion: reduceMotion,
    textScale: textScale,
    settleFrames: settleFrames,
    overrides: [pendingMatchProvider.overrideWith(() => _Pending(pending)), matchNavigationProvider.overrideWithValue(nav.nav), ...overrides],
  );
  return MatchBed(container, session, nav, game);
}

/// Sizes the phone like a small Android (360 x 740) and re-lays the screen out.
Future<void> useSmallPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360 * 3, 740 * 3);
  await tester.pump(const Duration(milliseconds: 50));
}

/// Pumps [seconds] of test time in 50 ms steps (animations and timers move on).
Future<void> pumpFor(WidgetTester tester, double seconds) async {
  final steps = (seconds * 20).round();
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A state with the pieces of [seat] at [progress] (the rest as they were).
GameState placed(GameState s, Map<Seat, List<int>> pieces) {
  var out = s;
  pieces.forEach((seat, p) => out = out.withPieces(seat, p));
  return out;
}

/// The positions of Match.dc.html (progress per piece; -1 = yard) with [current] about to roll.
GameState artboardPosition(GameState s, {Seat current = Seat.red, Phase phase = Phase.awaitRoll}) => placed(s, const {
  Seat.red: [6, 19, -1, -1],
  Seat.green: [3, -1, -1, 27],
  Seat.yellow: [9, -1, -1, -1],
  Seat.blue: [14, 33, -1, -1],
}).copyWith(current: current, phase: phase, firstSeat: Seat.red);

/// The Mayhem board of Mayhem.dc.html: the person (red) holds Shield + Swap, the first blue piece is frozen, the
/// second yellow piece is shielded and Lucky hour has two rounds to run; red rolls next.
GameState mayhemPosition(GameState s, {List<PowerCard> hand = const [PowerCard.shield, PowerCard.swap], bool event = true}) {
  final base = placed(s, const {
    Seat.red: [9, 20, -1, -1],
    Seat.green: [5, -1, -1, 33],
    Seat.yellow: [12, 24, -1, -1],
    Seat.blue: [10, -1, -1, -1],
  });
  final m = base.mayhem!;
  return base.copyWith(
    current: Seat.red,
    phase: Phase.awaitRoll,
    firstSeat: Seat.red,
    mayhem: m.copyWith(
      hands: {...m.hands, Seat.red: hand},
      shields: {const PieceRef(Seat.yellow, 1): 99},
      frozen: {const PieceRef(Seat.blue, 0)},
      event: event ? ActiveMelaEvent(MelaEventKind.luckyHour, base.round + 2) : null,
    ),
  );
}

/// Ends a test: tears the board down and flushes timers.
Future<void> closeMatch(WidgetTester tester, MatchBed bed) => closeScreen(tester, bed.container);

/// The sample save with its Settings changed by [change] (auto-move off, tags off, left-handed …).
SaveData saveWithSettings(AppSettings Function(AppSettings s) change) {
  final s = sampleSave();
  return s.copyWith(settings: change(s.settings));
}

/// Pumps (50 ms at a time) until [finder] matches something or [timeout] seconds of test time have passed.
Future<bool> pumpUntilFound(WidgetTester tester, Finder finder, {double timeout = 8}) async {
  for (var i = 0; i < (timeout * 20).round(); i++) {
    if (finder.evaluate().isNotEmpty) return true;
    await tester.pump(const Duration(milliseconds: 50));
  }
  return finder.evaluate().isNotEmpty;
}

/// The session's clock on test time: timers are the (faked) Dart timers, `now` follows the test binding's clock, so
/// the turn timer, bot think time and the Rush clock move with `tester.pump(duration)`.
class _TestTimers implements SessionTimers {
  _TestTimers(this._tester) : _start = _tester.binding.clock.now();

  final WidgetTester _tester;
  final DateTime _start;

  @override
  Duration get now => _tester.binding.clock.now().difference(_start);

  @override
  SessionTimer after(Duration delay, void Function() callback) => _TestTimer(Timer(delay, callback));
}

class _TestTimer implements SessionTimer {
  _TestTimer(this._timer);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}
