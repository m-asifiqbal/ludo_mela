// The classic board on a phone, driven through the real session: what is on screen, rolling and moving, the toasts
// and bursts of a capture / a piece reaching home / no move, hints, the turn pie and stickers. The pause menu, Android
// back, the app going to the background and leaving the match are in match_pause_test.dart.

import 'package:flutter/widgets.dart' show AppLifecycleState, Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';

import '../../helpers/fake_feedback.dart';
import '../../helpers/screen_harness.dart';
import 'match_rig.dart';

/// The pieces with a ring (the ones a tap moves).
Finder movable() => find.byWidgetPredicate((w) => w is PieceCoin && w.onTap != null);

/// Taps the dice tray and lets the toss, the hops and the toasts play.
Future<void> roll(WidgetTester tester, {double seconds = 2.5}) async {
  await tester.tap(find.byType(DiceTray));
  await pumpFor(tester, seconds);
}


void main() {
  group('the board at rest', () {
    testWidgets('shows the ad slot, four corners with their names, the mode, the board and the tool row', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      expect(find.text('Classic'), findsOneWidget);
      for (final label in ['You', 'Raja · Hunter', 'Mitu · Turtle', 'Tara · Racer']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Tap the dice to roll'), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget, reason: 'practice has unlimited hints');
      expect(find.byType(DiceTray), findsOneWidget, reason: 'only the seat that rolls has a tray');
      expect(find.byType(PieceCoin), findsNWidgets(16));
      expect(movable(), findsNothing, reason: 'nothing can be tapped before the roll');
      await closeMatch(tester, bed);
    });

    testWidgets('your avatar shows the turn pie; a bot\'s turn has none and says it is playing', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      final mine = tester.widgetList<AvatarFrame>(find.byType(AvatarFrame)).where((f) => f.timer != null);
      expect(mine.length, 1, reason: 'one pie, in the avatar of the person who must act');
      expect(mine.single.active, isTrue);
      await closeMatch(tester, bed);

      final bot = await pumpMatch(tester, position: (s) => artboardPosition(s, current: Seat.green), settleFrames: 5);
      expect(find.text('Raja is playing…'), findsOneWidget);
      expect(tester.widgetList<AvatarFrame>(find.byType(AvatarFrame)).where((f) => f.timer != null), isEmpty);
      await closeMatch(tester, bot);
    });

    testWidgets('every piece and the dice have a spoken label', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      expect(find.bySemanticsLabel('Your piece 1, on the track'), findsOneWidget);
      expect(find.bySemanticsLabel('Your piece 3, in the yard'), findsOneWidget);
      expect(find.bySemanticsLabel('Raja’s piece 1, on the track'), findsOneWidget);
      expect(find.bySemanticsLabel('Roll the dice'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Ludo board\. Your turn\.')), findsOneWidget);
      expect(find.bySemanticsLabel('Menu'), findsOneWidget);
      expect(find.bySemanticsLabel('Stickers and quick chat'), findsOneWidget);
      await closeMatch(tester, bed);
      handle.dispose();
    });
  });

  group('rolling and moving', () {
    testWidgets('a roll offers the pieces that can move; tapping one hops it and the turn goes on', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await roll(tester);
      expect(bed.state.phase, Phase.awaitMove);
      expect(find.text('Tap a piece with a ring'), findsOneWidget);
      expect(movable(), findsNWidgets(2), reason: 'the two pieces on the track can move 5; the yard ones need a 6');
      expect(find.text('Hint'), findsOneWidget);
      await tester.tap(movable().first);
      await pumpFor(tester, 1.5);
      final red = bed.state.pieces(Seat.red);
      expect(red, anyOf(contains(11), contains(24)), reason: 'one piece moved 5 squares');
      expect(bed.state.current, isNot(Seat.red), reason: 'no six, no capture: the turn passed');
      await closeMatch(tester, bed);
    });

    testWidgets('the tray tosses with a sound, then the dice just rolled sit beside your name', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await tester.tap(find.byType(DiceTray));
      await pumpFor(tester, .3);
      expect(fakeFeedbackOf(bed.container).played, contains(Sfx.diceShake));
      await pumpFor(tester, 2);
      expect(fakeFeedbackOf(bed.container).played, contains(Sfx.diceLand));
      expect(find.byType(MiniDice), findsOneWidget);
      expect(find.byType(DiceTray), findsNothing, reason: 'the tray gives way to the little dice once it has landed');
      await closeMatch(tester, bed);
    });

    testWidgets('a lone legal move plays itself after a short pause (Settings › auto-move)', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [2],
      );
      await roll(tester, seconds: 3);
      expect(bed.state.pieces(Seat.red)[0], 9, reason: 'nobody tapped: the only move was played');
      await closeMatch(tester, bed);
    });

    testWidgets('holding a piece with a ring shows the path and its chance of being hit', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await roll(tester);
      final gesture = await tester.startGesture(tester.getCenter(movable().first));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(MoveTag), findsWidgets);
      await gesture.up();
      await pumpFor(tester, 1);
      await closeMatch(tester, bed);
    });

    testWidgets('a six: the pieces in the yard come out and the roll goes on', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [6]);
      await roll(tester);
      expect(movable(), findsNWidgets(4), reason: 'two on the track, and the yard pieces can enter');
      expect(find.text('CAPTURE'), findsNothing);
      await closeMatch(tester, bed);
    });
  });

  group('what happens on the board', () {
    testWidgets('a capture: POW!, the toast, the victim back in its yard, your roll again', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1], Seat.blue: [23, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [3, 2],
      );
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('POW!')), isTrue, reason: 'the burst on the square');
      expect(await pumpUntilFound(tester, find.text('Captured Tara! Roll again')), isTrue);
      expect(bed.state.pieces(Seat.blue)[0], -1, reason: 'sent home');
      expect(fakeFeedbackOf(bed.container).played, contains(Sfx.capture));
      await pumpFor(tester, 2);
      expect(bed.state.current, Seat.red, reason: 'a capture gives another roll');
      expect(find.text('Tap the dice to roll'), findsOneWidget);
      await closeMatch(tester, bed);
    });

    testWidgets('being captured is told, with the sad sound', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [23, -1, -1, -1], Seat.blue: [33, -1, -1, -1]}).copyWith(current: Seat.blue, phase: Phase.awaitRoll, firstSeat: Seat.blue),
        rolls: [3],
      );
      expect(await pumpUntilFound(tester, find.text('Tara captured you'), timeout: 10), isTrue);
      expect(bed.state.pieces(Seat.red)[0], -1);
      expect(fakeFeedbackOf(bed.container).played, contains(Sfx.captured));
      await closeMatch(tester, bed);
    });

    testWidgets('a piece reaching home says HOME! and rolls again', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [53, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [3],
      );
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('Home! Roll again')), isTrue);
      expect(find.text('HOME!'), findsOneWidget, reason: 'the burst on the home triangle');
      expect(bed.state.pieces(Seat.red)[0], Board.home);
      expect(fakeFeedbackOf(bed.container).played, contains(Sfx.home));
      await closeMatch(tester, bed);
    });

    testWidgets('no move: a toast, then the turn passes', (tester) async {
      final bed = await pumpMatch(tester, rolls: [3]);
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('No move with a 3')), isTrue);
      await pumpFor(tester, 2.5);
      expect(bed.state.current, isNot(Seat.red));
      await closeMatch(tester, bed);
    });

    testWidgets('a six toasts "Six! Roll again" once the piece has moved, and the same hand rolls on', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [6],
      );
      await roll(tester);
      expect(movable(), findsNWidgets(4), reason: 'the piece on the track, and the three that can come out');
      await tester.tap(movable().first);
      expect(await pumpUntilFound(tester, find.text('Six! Roll again')), isTrue);
      await pumpFor(tester, 2);
      expect(bed.state.current, Seat.red);
      expect(bed.state.phase, Phase.awaitRoll);
      await closeMatch(tester, bed);
    });

    testWidgets('three sixes in a row end the turn with a red toast', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, 9, 11, 13]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [6, 6, 6],
        save: saveWithSettings((s) => s.copyWith(autoMove: false)),
      );
      for (var i = 0; i < 2; i++) {
        await roll(tester);
        await tester.tap(movable().first);
        await pumpFor(tester, 3.5);
      }
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('Three sixes — turn passes')), isTrue);
      await closeMatch(tester, bed);
    });
  });

  group('hints and tags', () {
    testWidgets('Hint rings the best piece (unlimited in practice)', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await roll(tester);
      expect(find.byWidgetPredicate((w) => w is PieceCoin && w.hinted), findsNothing);
      await tester.tap(find.text('Hint'));
      await pumpFor(tester, .5);
      expect(find.byWidgetPredicate((w) => w is PieceCoin && w.hinted), findsOneWidget);
      expect(find.text('Hint'), findsOneWidget, reason: 'practice never counts them down');
      await closeMatch(tester, bed);
    });

    testWidgets('at a coin table there is no Hint button unless Settings allow it; then it counts ×3', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(practice: false, venueId: 'village_haat'), rolls: [5]);
      expect(find.text('Hint'), findsNothing);
      expect(find.textContaining('Hint ×'), findsNothing);
      await closeMatch(tester, bed);

      final base = sampleSave();
      final allowed = base.copyWith(settings: base.settings.copyWith(tableHints: true));
      final on = await pumpMatch(
        tester,
        setup: botGame(practice: false, venueId: 'village_haat'),
        position: (s) => artboardPosition(s),
        save: allowed,
        rolls: [5],
      );
      expect(find.text('Hint ×3'), findsOneWidget);
      await roll(tester);
      await tester.tap(find.text('Hint ×3'));
      await pumpFor(tester, .5);
      expect(find.text('Hint ×2'), findsOneWidget);
      await closeMatch(tester, on);
    });

    testWidgets('destinations carry their tags, and Settings can switch the tags off', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1], Seat.blue: [23, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [3],
        save: saveWithSettings((s) => s.copyWith(autoMove: false)),
      );
      await roll(tester);
      expect(find.byType(MoveTag), findsOneWidget);
      expect(find.text('CAPTURE'), findsOneWidget);
      await closeMatch(tester, bed);

      final off = await pumpMatch(
        tester,
        position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1], Seat.blue: [23, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [3],
        save: saveWithSettings((s) => s.copyWith(autoMove: false, moveTags: false)),
      );
      await roll(tester);
      expect(find.byType(MoveTag), findsNothing);
      await closeMatch(tester, off);
    });
  });

  group('stickers', () {
    testWidgets('the picker offers six stickers and four phrases; a pick speaks beside your avatar for a moment', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await tester.tap(find.bySemanticsLabel('Stickers and quick chat'));
      await pumpFor(tester, .6);
      for (final p in ['Well played!', 'Oops!', 'Hurry up!', 'Good luck!']) {
        expect(find.text(p), findsOneWidget, reason: p);
      }
      await tester.tap(find.text('Well played!'));
      await pumpFor(tester, .6);
      expect(find.text('Well played!'), findsOneWidget, reason: 'the picker closed; the bubble is left');
      expect(find.text('Hurry up!'), findsNothing);
      await pumpFor(tester, 2.2);
      expect(find.text('Well played!'), findsNothing, reason: 'it fades after 1.8 s');
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('a sticker (not a phrase) shows its picture with a label', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await tester.tap(find.bySemanticsLabel('Stickers and quick chat'));
      await pumpFor(tester, .6);
      await tester.tap(find.bySemanticsLabel('Laughing sticker'));
      await pumpFor(tester, .6);
      expect(find.bySemanticsLabel('Laughing sticker'), findsOneWidget);
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('a tap outside the picker closes it; Android back closes it before it opens the menu', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      Future<void> open() async {
        await tester.tap(find.bySemanticsLabel('Stickers and quick chat'));
        await pumpFor(tester, .4);
        expect(find.text('Hurry up!'), findsOneWidget);
      }

      await open();
      await tester.tapAt(const Offset(40, 300)); // the barrier, well away from the picker
      await pumpFor(tester, .4);
      expect(find.text('Hurry up!'), findsNothing);

      await open();
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .4);
      expect(find.text('Hurry up!'), findsNothing, reason: 'back closes the picker first');
      expect(find.text('PAUSED'), findsNothing);
      expect(bed.session.paused, isFalse);
      await tester.binding.handlePopRoute();
      await pumpFor(tester, .4);
      expect(find.text('PAUSED'), findsOneWidget, reason: 'the next back opens the menu');
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('the app going to the background takes the picker away for good', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      await tester.tap(find.bySemanticsLabel('Stickers and quick chat'));
      await pumpFor(tester, .4);
      expect(find.text('Hurry up!'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await pumpFor(tester, .4);
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('Hurry up!'), findsNothing);
      await tester.tap(find.text('RESUME'));
      await pumpFor(tester, .4);
      expect(find.text('Hurry up!'), findsNothing, reason: 'it does not pop up again when the match goes on');
      await closeMatch(tester, bed);
    });

    testWidgets('Parent controls (stickers off) remove the button', (tester) async {
      final base = sampleSave();
      final bed = await pumpMatch(tester, save: base.copyWith(settings: base.settings.copyWith(stickers: false)));
      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Stickers and quick chat'), findsNothing);
      handle.dispose();
      await closeMatch(tester, bed);
    });
  });
}
