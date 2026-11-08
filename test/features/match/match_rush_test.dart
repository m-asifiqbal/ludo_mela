// Rush on the board: the five-minute clock beside the title, the points after each name, the clock standing still under
// the pause menu, never lagging behind the real clock while moves are animated, and the time-up that ends the match.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/widgets/outlined_text.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';
import 'package:ludo_mela/features/match/widgets/mode_title.dart' show RushClockPill;

import 'match_rig.dart';

void main() {
  group('Rush', () {
    testWidgets('a clock beside the title counts down; the points follow each name', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.rush), rolls: [4]);
      expect(find.text('Rush'), findsOneWidget);
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('You · 0'), findsOneWidget);
      expect(find.text('Raja · Hunter · 0'), findsOneWidget);
      await pumpFor(tester, 3.2);
      expect(find.text('5:00'), findsNothing, reason: 'it runs on its own between the session updates');
      expect(find.textContaining(RegExp(r'^4:5')), findsOneWidget);
      await closeMatch(tester, bed);
    });

    testWidgets('the clock stands still while the match is paused', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.rush), rolls: [4]);
      await pumpFor(tester, 2);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, 1);
      final frozen = find.textContaining(RegExp(r'^4:5\d$'));
      expect(frozen, findsOneWidget);
      final shown = tester.widget<Text>(frozen).data;
      await pumpFor(tester, 5);
      expect(tester.widget<Text>(find.textContaining(RegExp(r'^4:5\d$'))).data, shown);
      await closeMatch(tester, bed);
    });

    testWidgets('the clock keeps up with the real one while the bots\' moves are being animated (it never lags by the animation)', (tester) async {
      final base = botGame(mode: GameMode.rush, firstSeat: Seat.green);
      final setup = MatchSetup(config: base.config, practice: true, turnTime: MatchSetup.vsTurnTime, rushTime: const Duration(minutes: 5), mySeat: Seat.red);
      final bed = await pumpMatch(tester, setup: setup);
      var worst = 0;
      for (var i = 0; i < 600; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        final pill = find.descendant(of: find.byType(RushClockPill), matching: find.byType(OutlinedText));
        if (pill.evaluate().isEmpty) continue;
        final parts = tester.widget<OutlinedText>(pill).text.split(':');
        final shown = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final truth = (bed.session.rushClock!.remaining.inMilliseconds / 1000).ceil();
        worst = worst < (shown - truth).abs() ? (shown - truth).abs() : worst;
      }
      expect(bed.session.state.turnNumber, greaterThan(3), reason: 'the bots played, so there were updates to animate');
      expect(worst, lessThanOrEqualTo(1), reason: 'the digits change once a second; more than that would be a stale snapshot');
      await closeMatch(tester, bed);
    });

    testWidgets('the clock stays frozen when a move is still being animated as the menu opens', (tester) async {
      final base = botGame(mode: GameMode.rush, firstSeat: Seat.green);
      final setup = MatchSetup(config: base.config, practice: true, turnTime: MatchSetup.vsTurnTime, rushTime: const Duration(minutes: 5), mySeat: Seat.red);
      final bed = await pumpMatch(tester, setup: setup);
      // Wait for the first action of a bot, then open the menu while it is being played.
      for (var i = 0; i < 100 && bed.session.state.rollsTaken == 0; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.binding.handlePopRoute();
      await pumpFor(tester, 4); // the animation ends behind the menu
      expect(bed.session.rushClock!.running, isFalse);
      String shown() => tester.widget<OutlinedText>(find.descendant(of: find.byType(RushClockPill), matching: find.byType(OutlinedText))).text;
      final before = shown();
      await pumpFor(tester, 6);
      expect(shown(), before, reason: 'a stale running snapshot must not restart the pill under the pause menu');
      await closeMatch(tester, bed);
    });

    testWidgets('time up: "Time\'s up!", the match ends and the result opens', (tester) async {
      final base = botGame(mode: GameMode.rush, players: 2);
      final setup = MatchSetup(config: base.config, practice: true, turnTime: null, rushTime: const Duration(seconds: 4), mySeat: Seat.red);
      final bed = await pumpMatch(tester, setup: setup, position: (s) => s.copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red));
      expect(await pumpUntilFound(tester, find.text('Time’s up!'), timeout: 12), isTrue);
      expect(bed.state.overReason, GameOverReason.timeUp);
      expect(await pumpUntilFound(tester, find.textContaining(RegExp(r'You win!|Raja wins'))), isTrue, reason: 'the verdict follows the toast');
      await pumpFor(tester, 4);
      expect(bed.nav.went, ['/result']);
      await closeMatch(tester, bed);
    });
  });
}
