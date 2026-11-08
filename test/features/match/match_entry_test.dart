// How a match begins and what the clock does: the dev entry (nothing pending: a free Quick match against three
// bots), the roll-off on the board, the 15 s turn timer running out, and the sound of each hop.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/features/match/match_screen.dart';

import '../../helpers/fake_feedback.dart';
import '../../helpers/screen_harness.dart';
import 'match_rig.dart';

Finder movable() => find.byWidgetPredicate((w) => w is PieceCoin && w.onTap != null);

void main() {
  testWidgets('dev entry: with nothing pending a free Quick match against three bots starts, beginning with the roll-off', (tester) async {
    final c = await pumpScreen(tester, (context, state) => const MatchScreen(), location: Routes.match);
    await pumpFor(tester, 1);
    expect(find.text('Quick'), findsOneWidget);
    for (final label in ['You', 'Raja · Hunter', 'Mitu · Turtle', 'Tara · Racer']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(PieceCoin), findsNWidgets(16));
    expect(find.text('Tap the dice to roll'), findsOneWidget, reason: 'the person rolls first in the roll-off');
    // Roll off until somebody goes first (a tie rolls again).
    for (var i = 0; i < 400 && find.textContaining(RegExp(r'^(You go|\w+ goes) first$')).evaluate().isEmpty; i++) {
      final tray = find.byType(DiceTray);
      if (tray.evaluate().isNotEmpty && tester.widget<DiceTray>(tray).onRoll != null) await tester.tap(tray);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining(RegExp(r'^(You go|\w+ goes) first$')), findsOneWidget);
    await closeScreen(tester, c);
  });

  testWidgets('the roll-off on the board: everybody rolls once, the highest goes first', (tester) async {
    final bed = await pumpMatch(tester, setup: botGame(firstSeat: null), rolls: [4, 2, 1, 3]);
    expect(bed.state.phase, Phase.rollOff);
    await tester.tap(find.byType(DiceTray));
    expect(await pumpUntilFound(tester, find.text('You rolled 4')), isTrue);
    expect(await pumpUntilFound(tester, find.text('Raja rolled 2'), timeout: 10), isTrue);
    expect(await pumpUntilFound(tester, find.text('You go first'), timeout: 20), isTrue);
    await pumpFor(tester, 2);
    expect(bed.state.phase, Phase.awaitRoll);
    expect(bed.state.current, Seat.red);
    expect(find.text('Tap the dice to roll'), findsOneWidget);
    await closeMatch(tester, bed);
  });

  testWidgets('a tie rolls again', (tester) async {
    final bed = await pumpMatch(tester, setup: botGame(firstSeat: null, players: 2), rolls: [3, 3, 5, 1]);
    await tester.tap(find.byType(DiceTray));
    expect(await pumpUntilFound(tester, find.text('Tie! Roll again'), timeout: 15), isTrue);
    await closeMatch(tester, bed);
  });

  testWidgets('the turn pie runs down; when it is empty the game plays for you', (tester) async {
    final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
    final pie = find.byWidgetPredicate((w) => w is AvatarFrame && w.timer != null);
    expect(pie, findsOneWidget);
    expect(tester.widget<AvatarFrame>(pie).timer!.total, const Duration(seconds: 15));
    await pumpFor(tester, 10);
    expect(bed.state.rollsTaken, 0, reason: 'still waiting for you at 10 s');
    await pumpFor(tester, 7);
    expect(bed.state.current != Seat.red || bed.state.phase != Phase.awaitRoll, isTrue, reason: 'at 15 s the session rolled (and played) for you');
    await closeMatch(tester, bed);
  });

  testWidgets('pausing freezes the pie where it is', (tester) async {
    final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
    await pumpFor(tester, 6);
    await tester.binding.handlePopRoute();
    await pumpFor(tester, .5);
    final frozen = bed.session.clock!;
    expect(frozen.running, isFalse);
    await pumpFor(tester, 20);
    expect(bed.state.phase, Phase.awaitRoll, reason: 'no timeout while paused');
    expect(bed.session.clock!.remaining, frozen.remaining);
    await closeMatch(tester, bed);
  });

  testWidgets('a hop ticks once per square, a capture and a home have their own sounds', (tester) async {
    final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
    await tester.tap(find.byType(DiceTray));
    await pumpFor(tester, 2.5);
    final before = fakeFeedbackOf(bed.container).played.where((s) => s == Sfx.hop).length;
    await tester.tap(movable().first);
    await pumpFor(tester, 2);
    final hops = fakeFeedbackOf(bed.container).played.where((s) => s == Sfx.hop).length - before;
    expect(hops, 5, reason: 'five squares, five ticks');
    expect(fakeFeedbackOf(bed.container).haptics, greaterThan(0));
    await closeMatch(tester, bed);
  });

  testWidgets('a six sounds the dhol; the game speed never changes the dice', (tester) async {
    final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [6]);
    await tester.tap(find.byType(DiceTray));
    await pumpFor(tester, 2.5);
    expect(fakeFeedbackOf(bed.container).played, containsAllInOrder([Sfx.diceShake, Sfx.diceLand, Sfx.six]));
    await closeMatch(tester, bed);
  });
}
