// The event player and the end-of-match verdict on their own, without a screen: the player drops the rest of an update
// once its screen is gone (no sounds, toasts or bursts on a dead board), and the Celebration words the verdict for the
// person against the computer, their team, people sharing the phone and a bot, holds the board for its beats and makes
// no sound of its own (the Win screen owns the cheer).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/widgets/toast.dart' show ToastTone;
import 'package:ludo_mela/features/match/board/board_model.dart';
import 'package:ludo_mela/features/match/match_look.dart';
import 'package:ludo_mela/features/match/match_models.dart';
import 'package:ludo_mela/features/match/playback/celebration.dart';
import 'package:ludo_mela/features/match/playback/event_player.dart';
import 'package:ludo_mela/features/match/session/match_session.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';

import '../../helpers/app_harness.dart' show sampleSave;
import '../../helpers/fake_feedback.dart';
import 'match_rig.dart' show botGame, tabletopGame;

/// What a screen has around the Celebration / EventPlayer: an environment on the sample save, a recording of the
/// toasts, and the silent feedback fake.
class _Bed {
  _Bed(this.setup, {bool reduced = true}) {
    final save = sampleSave();
    container = ProviderContainer(overrides: [fakeFeedbackOverride]);
    addTearDown(container.dispose);
    env = MatchEnv(
      settings: () => save.settings,
      look: () => MatchLook(setup: setup, profiles: save.profiles, active: save.activeProfile),
      feedback: container.read(feedbackProvider),
      reduced: () => reduced,
    );
  }

  final MatchSetup setup;
  late final ProviderContainer container;
  late final MatchEnv env;
  final List<(String, ToastTone)> toasts = [];
  int changes = 0;
  bool cancelled = false;

  FakeFeedback get feedback => fakeFeedbackOf(container);

  Celebration celebration() => Celebration(
    env: env,
    isMine: (seat) => setup.humanSeats.contains(seat),
    toast: (text, tone) => toasts.add((text, tone)),
    onChanged: () => changes++,
    cancelled: () => cancelled,
  );

  /// The position after the match: [placements] first place first.
  GameState over(List<Seat> placements, {GameOverReason reason = GameOverReason.quickTarget}) =>
      GameState.initial(setup.config).copyWith(phase: Phase.gameOver, placements: placements, overReason: reason);
}

/// Plays [c]'s verdict to the end (the test clock moves on in one go).
Future<void> verdict(WidgetTester tester, Celebration c, GameState end, {GameOverReason reason = GameOverReason.quickTarget}) async {
  final done = c.play(GameOverEvent(end.placements, reason), end);
  await tester.pump(const Duration(seconds: 5));
  await done;
}

void main() {
  group('Celebration', () {
    testWidgets('you win against the computer: "You win!" in green, the confetti flag, and not a sound', (tester) async {
      final bed = _Bed(botGame());
      final c = bed.celebration();
      expect(c.active, isFalse);
      await verdict(tester, c, bed.over([Seat.red, Seat.green, Seat.yellow, Seat.blue]));
      expect(bed.toasts, [('You win!', ToastTone.green)]);
      expect(c.active, isTrue);
      expect(c.won, isTrue);
      expect(bed.changes, greaterThan(0), reason: 'the board is told to repaint');
      expect(bed.feedback.played, isEmpty, reason: 'the cheer is the Win screen\'s');
      expect(bed.feedback.haptics, 0);
    });

    testWidgets('a bot wins: its name in red, no confetti', (tester) async {
      final bed = _Bed(botGame());
      final c = bed.celebration();
      await verdict(tester, c, bed.over([Seat.green, Seat.red, Seat.yellow, Seat.blue]));
      expect(bed.toasts, [('Raja wins', ToastTone.red)]);
      expect(c.active, isTrue);
      expect(c.won, isFalse);
    });

    testWidgets('Teams: when your partner (a bot) finishes first it is still "You win!"', (tester) async {
      final bed = _Bed(botGame(mode: GameMode.teams));
      final c = bed.celebration();
      // Red and yellow are partners; yellow came first.
      await verdict(tester, c, bed.over([Seat.yellow, Seat.green, Seat.red, Seat.blue], reason: GameOverReason.lastStanding));
      expect(bed.toasts.single, ('You win!', ToastTone.green));
      expect(c.won, isTrue);
    });

    testWidgets('people sharing the phone: the winner is named, in green, with confetti', (tester) async {
      final bed = _Bed(tabletopGame());
      final c = bed.celebration();
      await verdict(tester, c, bed.over([Seat.green, Seat.red, Seat.yellow, Seat.blue]));
      expect(bed.toasts, [('Nadia wins', ToastTone.green)]);
      expect(c.won, isTrue, reason: 'somebody on this phone won');
    });

    testWidgets('Rush: "Time\'s up!" is read first, then the verdict', (tester) async {
      final bed = _Bed(botGame(mode: GameMode.rush));
      final c = bed.celebration();
      await verdict(tester, c, bed.over([Seat.red, Seat.green, Seat.yellow, Seat.blue], reason: GameOverReason.timeUp), reason: GameOverReason.timeUp);
      expect(bed.toasts, [('Time’s up!', ToastTone.gold), ('You win!', ToastTone.green)]);
    });

    testWidgets('nothing is said once the screen is gone or the player is leaving', (tester) async {
      final bed = _Bed(botGame(mode: GameMode.rush))..cancelled = true;
      final c = bed.celebration();
      await verdict(tester, c, bed.over([Seat.red, Seat.green], reason: GameOverReason.timeUp), reason: GameOverReason.timeUp);
      expect(bed.toasts, isEmpty);
      expect(c.active, isFalse);

      // …and when it happens during the "Time's up!" beat, the verdict never comes.
      final late = _Bed(botGame(mode: GameMode.rush));
      final lc = late.celebration();
      final done = lc.play(const GameOverEvent([Seat.red, Seat.green], GameOverReason.timeUp), late.over([Seat.red, Seat.green], reason: GameOverReason.timeUp));
      await tester.pump(const Duration(milliseconds: 100));
      late.cancelled = true;
      await tester.pump(const Duration(seconds: 5));
      await done;
      expect(late.toasts, [('Time’s up!', ToastTone.gold)]);
    });

    testWidgets('with full motion the board holds on for the win beat (1.2 s + a little), with Reduce Motion for less', (tester) async {
      final full = _Bed(botGame(), reduced: false);
      var finished = false;
      final done = full.celebration().play(const GameOverEvent([Seat.red, Seat.green], GameOverReason.quickTarget), full.over([Seat.red, Seat.green])).then((_) => finished = true);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(finished, isFalse, reason: 'still celebrating at 1.4 s');
      await tester.pump(const Duration(milliseconds: 200));
      await done;
      expect(finished, isTrue);

      final quick = _Bed(botGame());
      var quickDone = false;
      final d2 = quick.celebration().play(const GameOverEvent([Seat.red, Seat.green], GameOverReason.quickTarget), quick.over([Seat.red, Seat.green])).then((_) => quickDone = true);
      await tester.pump(const Duration(milliseconds: 450));
      await d2;
      expect(quickDone, isTrue);
    });
  });

  group('EventPlayer', () {
    EventPlayer player(_Bed bed, BoardModel board, GameState settled, {bool leaveAfterFirstToast = false}) => EventPlayer(
      board: board,
      env: bed.env,
      hooks: PlaybackHooks(
        toss: (seat, value) async {},
        rolled: (seat, value) {},
        turnPassed: (from, to) {},
        celebrate: (e) async {},
        toast: (text, tone) {
          bed.toasts.add((text, tone));
          // The screen goes away while its first toast is up.
          if (leaveAfterFirstToast) bed.cancelled = true;
        },
        isMine: (seat) => seat == Seat.red,
        settled: () => settled,
        cancelled: () => bed.cancelled,
      ),
    );

    test('plays every event of an update, in order', () async {
      final bed = _Bed(botGame());
      final state = GameState.initial(bed.setup.config);
      final board = BoardModel(vsync: const TestVSync(), initial: state);
      addTearDown(board.dispose);
      await player(bed, board, state).play(MatchUpdate(state: state, events: const [ConcededEvent(Seat.green), ConcededEvent(Seat.yellow)]));
      expect(bed.toasts.map((t) => t.$1), ['Raja left the match', 'Mitu left the match']);
    });

    test('drops the rest of an update once its screen is gone', () async {
      final bed = _Bed(botGame());
      final state = GameState.initial(bed.setup.config);
      final board = BoardModel(vsync: const TestVSync(), initial: state);
      addTearDown(board.dispose);
      await player(bed, board, state, leaveAfterFirstToast: true).play(MatchUpdate(state: state, events: const [ConcededEvent(Seat.green), ConcededEvent(Seat.yellow)]));
      expect(bed.toasts.map((t) => t.$1), ['Raja left the match'], reason: 'the second event is never played');
    });
  });
}
