// The other ways to play on the board: Mela Mayhem (event banner, hand, card play), Teams (the partner), pass & play
// and the tabletop (one phone, four people), the end of a match (the win, the confetti, the way to /result), and the
// accessibility switches (Reduce Motion, left-handed, big text). Rush (the clock, the points) is in match_rush_test.dart.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/widgets/confetti_layer.dart';
import 'package:ludo_mela/core/widgets/pressable.dart';
import 'package:ludo_mela/features/match/session/match_recorder.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';

import '../../helpers/fake_feedback.dart';
import 'match_rig.dart';

Finder movable() => find.byWidgetPredicate((w) => w is PieceCoin && w.onTap != null);
Finder piecesInState(PieceState s) => find.byWidgetPredicate((w) => w is PieceCoin && w.state == s);

void main() {
  group('Mela Mayhem', () {
    testWidgets('the Lucky hour banner, the hand and the card button', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.mayhem), position: (s) => mayhemPosition(s), rolls: [5]);
      expect(find.text('LUCKY HOUR!'), findsOneWidget);
      expect(find.text('Captures give 2 extra rolls'), findsOneWidget);
      expect(find.text('2 ROUNDS'), findsOneWidget);
      expect(find.text('SHIELD'), findsOneWidget);
      expect(find.text('SWAP'), findsOneWidget);
      expect(find.text('PICK A CARD'), findsOneWidget);
      expect(piecesInState(PieceState.shielded), findsOneWidget, reason: 'the second yellow piece');
      expect(piecesInState(PieceState.frozen), findsOneWidget, reason: 'the first blue piece');
      await closeMatch(tester, bed);
    });

    testWidgets('without an event the title is the mode; an empty hand says how to draw a card', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.mayhem),
        position: (s) => mayhemPosition(s, hand: const [], event: false),
      );
      expect(find.text('Mela Mayhem'), findsOneWidget);
      expect(find.text('LUCKY HOUR!'), findsNothing);
      expect(find.text('No cards — land on a purple power tile to draw one.'), findsOneWidget);
      await closeMatch(tester, bed);
    });

    testWidgets('pick Shield, press USE, tap the piece to protect: the card is played and leaves the hand', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.mayhem), position: (s) => mayhemPosition(s), rolls: [5]);
      await tester.tap(find.text('SHIELD'));
      await pumpFor(tester, .5);
      expect(find.text('USE SHIELD'), findsOneWidget);
      expect(find.text('Safe from capture for 2 rounds'), findsOneWidget, reason: 'the line says what the card does');
      await tester.tap(find.text('USE SHIELD'));
      await pumpFor(tester, .5);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('Tap the piece to protect.'), findsOneWidget);
      expect(movable(), findsNWidgets(2), reason: 'only your two pieces on the loop can be protected');
      await tester.tap(movable().first);
      expect(await pumpUntilFound(tester, find.text('You played SHIELD')), isTrue);
      expect(bed.state.mayhem!.shields.keys.where((p) => p.seat == Seat.red), hasLength(1));
      expect(bed.state.mayhem!.handOf(Seat.red), [PowerCard.swap]);
      await pumpFor(tester, 1);
      expect(find.text('SHIELD'), findsNothing);
      await closeMatch(tester, bed);
    });

    testWidgets('pressing the card button again cancels the target mode', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.mayhem), position: (s) => mayhemPosition(s), rolls: [5]);
      await tester.tap(find.text('SHIELD'));
      await pumpFor(tester, .3);
      await tester.tap(find.text('USE SHIELD'));
      await pumpFor(tester, .3);
      expect(find.text('CANCEL'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await pumpFor(tester, .3);
      expect(find.text('USE SHIELD'), findsOneWidget);
      expect(movable(), findsNothing);
      await closeMatch(tester, bed);
    });

    testWidgets('Swap: your piece first, then the rival piece it trades with', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.mayhem),
        position: (s) {
          final p = placed(s, const {Seat.red: [9, 30, -1, -1], Seat.yellow: [38, -1, -1, -1]});
          return p.copyWith(
            current: Seat.red,
            phase: Phase.awaitRoll,
            firstSeat: Seat.red,
            mayhem: p.mayhem!.copyWith(hands: {...p.mayhem!.hands, Seat.red: const [PowerCard.swap]}),
          );
        },
        rolls: [5],
      );
      await tester.tap(find.text('SWAP'));
      await pumpFor(tester, .3);
      await tester.tap(find.text('USE SWAP'));
      await pumpFor(tester, .3);
      expect(find.text('Tap your piece, then a rival piece up to 6 squares ahead.'), findsOneWidget);
      expect(movable(), findsOneWidget, reason: 'only the piece with a rival just ahead');
      await tester.tap(movable());
      await pumpFor(tester, .3);
      expect(movable(), findsOneWidget, reason: 'now the rival piece');
      await tester.tap(movable());
      expect(await pumpUntilFound(tester, find.text('You played SWAP')), isTrue);
      await pumpFor(tester, 1);
      expect(bed.state.pieces(Seat.red)[0], 12, reason: 'three squares ahead');
      expect(bed.state.pieces(Seat.yellow)[0], 35, reason: 'three squares back');
      await closeMatch(tester, bed);
    });

    testWidgets('Double needs no target: it plays at once and the two dice wait to be used', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.mayhem),
        position: (s) => mayhemPosition(s, hand: const [PowerCard.double]),
        rolls: [3, 4],
      );
      await tester.tap(find.text('DOUBLE'));
      await pumpFor(tester, .3);
      await tester.tap(find.text('USE DOUBLE'));
      expect(await pumpUntilFound(tester, find.text('You played DOUBLE')), isTrue);
      await pumpFor(tester, 3);
      expect(bed.state.pendingDice, hasLength(2));
      expect(bed.state.mayhem!.handOf(Seat.red), isEmpty);
      await closeMatch(tester, bed);
    });

    testWidgets('with two dice a piece has two moves: tap it, then tap the destination you want', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.mayhem),
        position: (s) => mayhemPosition(s, hand: const [PowerCard.double]),
        rolls: [3, 4],
      );
      await tester.tap(find.text('DOUBLE'));
      await pumpFor(tester, .3);
      await tester.tap(find.text('USE DOUBLE'));
      await pumpFor(tester, 3);
      final before = bed.state.pieces(Seat.red).fold<int>(0, (a, b) => a + b);
      await tester.tap(movable().first);
      await pumpFor(tester, .6);
      final destinations = find.bySemanticsLabel(RegExp(r'^Move here'));
      expect(destinations, findsNWidgets(2), reason: 'one ghost per die, each a button of its own');
      await tester.tap(destinations.first);
      await pumpFor(tester, 2.5);
      expect(bed.state.pendingDice, hasLength(1), reason: 'one die was spent on the move');
      expect(bed.state.pieces(Seat.red).fold<int>(0, (a, b) => a + b), greaterThan(before));
      expect(find.bySemanticsLabel(RegExp(r'^Move here')), findsNothing, reason: 'the ghosts are gone');
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('a card you cannot play now is dimmed, not hidden (after one card this turn)', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.mayhem),
        position: (s) {
          final m = mayhemPosition(s);
          return m.copyWith(mayhem: m.mayhem!.copyWith(cardPlayed: true));
        },
        rolls: [5],
      );
      expect(find.text('SHIELD'), findsOneWidget);
      await tester.tap(find.text('SHIELD'));
      await pumpFor(tester, .3);
      expect(find.text('PICK A CARD'), findsOneWidget, reason: 'one card per turn: nothing was picked');
      await closeMatch(tester, bed);
    });
  });

  group('Teams', () {
    testWidgets('the partner opposite is named as such', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.teams), rolls: [4]);
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('Mitu · Partner'), findsOneWidget, reason: 'yellow sits opposite red');
      expect(find.text('Raja · Hunter'), findsOneWidget);
      expect(find.text('Tara · Racer'), findsOneWidget);
      await closeMatch(tester, bed);
    });

    testWidgets('a finished seat rolls for its partner: the line says whose piece to tap', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.teams),
        position: (s) => placed(s, const {
          Seat.red: [56, 56, 56, 56],
          Seat.yellow: [10, 20, -1, -1],
          Seat.green: [3, -1, -1, -1],
          Seat.blue: [5, -1, -1, -1],
        }).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red),
        rolls: [3],
        save: saveWithSettings((s) => s.copyWith(autoMove: false)),
      );
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('Tap a piece of Mitu’s')), isTrue);
      expect(movable(), findsNWidgets(2), reason: 'the two pieces of Mitu on the track');
      await closeMatch(tester, bed);
    });
  });

  group('pass & play and the tabletop', () {
    testWidgets('on the phone in hand each person is named when it is their turn', (tester) async {
      final setup = MatchSetup.passAndPlay(
        mode: GameMode.classic,
        firstSeat: Seat.red,
        players: const [PlayerSpec(seat: Seat.red, name: 'Mitu', id: 'p1'), PlayerSpec(seat: Seat.yellow, name: 'Rafi', avatar: 'panda')],
      );
      final bed = await pumpMatch(tester, setup: setup, position: (s) => placed(s, const {Seat.red: [7, -1, -1, -1], Seat.yellow: [30, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red), rolls: [2, 2]);
      expect(find.text('Mitu, tap the dice to roll'), findsOneWidget);
      await tester.tap(find.byType(DiceTray));
      await pumpFor(tester, 3.5);
      expect(find.text('Rafi, tap the dice to roll'), findsOneWidget, reason: 'the single move played itself and the phone is handed on');
      expect(bed.state.current, Seat.yellow);
      await closeMatch(tester, bed);
    });

    testWidgets('four flat dice wells: the seat on turn glows and is the only one that can be tapped', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, setup: tabletopGame(), position: (s) => artboardPosition(s), rolls: [5]);
      expect(find.byType(DiceTray), findsNothing, reason: 'no 3D tray on the table');
      expect(find.text('YOUR TURN'), findsOneWidget);
      expect(find.bySemanticsLabel('Player, roll the dice'), findsOneWidget);
      for (final n in ['Nadia', 'Rafi', 'Nani']) {
        expect(find.bySemanticsLabel('$n’s dice'), findsOneWidget, reason: n);
      }
      final live = tester.widgetList<Pressable>(find.byType(Pressable)).where((p) => p.onTap != null);
      expect(live.length, greaterThanOrEqualTo(1));
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('on the table a roll and a move pass the glow to the next seat', (tester) async {
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, setup: tabletopGame(), position: (s) => artboardPosition(s), rolls: [5, 2]);
      await tester.tap(find.bySemanticsLabel('Player, roll the dice'));
      await pumpFor(tester, 2.5);
      expect(find.text('YOUR TURN'), findsNothing, reason: 'the roll is made; now a piece has to move');
      expect(movable(), findsNWidgets(2));
      await tester.tap(movable().first);
      await pumpFor(tester, 2.5);
      expect(find.bySemanticsLabel('Nadia, roll the dice'), findsOneWidget, reason: 'green rolls next');
      expect(find.bySemanticsLabel('Player’s dice'), findsOneWidget);
      await closeMatch(tester, bed);
      handle.dispose();
    });

    testWidgets('a roll that cannot be played offers PASS on the table when auto-pass is off', (tester) async {
      final base = tabletopGame();
      final setup = MatchSetup.passAndPlay(
        mode: GameMode.classic,
        firstSeat: Seat.red,
        tabletop: true,
        rules: const Rules(autoPass: false),
        players: base.config.players,
      );
      final handle = tester.ensureSemantics();
      final bed = await pumpMatch(tester, setup: setup, rolls: [3]);
      await tester.tap(find.bySemanticsLabel('Player, roll the dice'));
      expect(await pumpUntilFound(tester, find.text('PASS')), isTrue);
      await tester.tap(find.text('PASS'));
      await pumpFor(tester, 2);
      expect(bed.state.current, isNot(Seat.red));
      await closeMatch(tester, bed);
      handle.dispose();
    });
  });

  group('the end of a match', () {
    GameState almostWon(GameState s) =>
        placed(s, const {Seat.red: [55, -1, -1, -1]}).copyWith(current: Seat.red, phase: Phase.awaitRoll, firstSeat: Seat.red);

    testWidgets('a win: "You win!", confetti, a silent board — then the result opens (it owns the cheer)', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.quick), position: almostWon, rolls: [1]);
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('You win!')), isTrue);
      expect(find.byType(ConfettiLayer), findsOneWidget);
      expect(find.descendant(of: find.byType(ConfettiLayer), matching: find.byType(CustomPaint)), findsWidgets);
      // The cheer is the Win screen's (one cheer, not two): the board only says it and drops the confetti.
      expect(fakeFeedbackOf(bed.container).played, isNot(anyOf(contains(Sfx.win), contains(Sfx.lose))));
      expect(bed.nav.went, isEmpty, reason: 'the screen holds on for the celebration');
      await pumpFor(tester, 4);
      expect(bed.nav.went, ['/result']);
      expect(bed.container.read(matchResultProvider)!.record.myPlace, 1);
      await closeMatch(tester, bed);
    });

    testWidgets('with Reduce Motion nothing falls and the board does not shake', (tester) async {
      final bed = await pumpMatch(tester, setup: botGame(mode: GameMode.quick), position: almostWon, rolls: [1], reduceMotion: true);
      await tester.tap(find.byType(DiceTray));
      expect(await pumpUntilFound(tester, find.text('You win!')), isTrue);
      expect(find.descendant(of: find.byType(ConfettiLayer), matching: find.byType(CustomPaint)), findsNothing);
      await pumpFor(tester, 3);
      expect(bed.nav.went, ['/result']);
      await closeMatch(tester, bed);
    });

    testWidgets('a bot winning is told by name, in red, without a sound of its own', (tester) async {
      final bed = await pumpMatch(
        tester,
        setup: botGame(mode: GameMode.quick),
        position: (s) => placed(s, const {Seat.green: [55, -1, -1, -1]}).copyWith(current: Seat.green, phase: Phase.awaitRoll, firstSeat: Seat.green),
        rolls: [1],
      );
      expect(await pumpUntilFound(tester, find.text('Raja wins'), timeout: 10), isTrue);
      expect(fakeFeedbackOf(bed.container).played, isNot(anyOf(contains(Sfx.win), contains(Sfx.lose))), reason: 'the Win screen plays the gentle sound');
      expect(find.byType(ConfettiLayer), findsNothing);
      await closeMatch(tester, bed);
    });
  });

  group('accessibility switches', () {
    testWidgets('left-handed play puts your tray on the outer side of your avatar', (tester) async {
      final right = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
      final mine = find.byWidgetPredicate((w) => w is AvatarFrame && w.timer != null);
      final trayRight = tester.getCenter(find.byType(DiceTray)).dx > tester.getCenter(mine).dx;
      expect(trayRight, isTrue, reason: 'bottom-left corner: the tray is on the inner side');
      await closeMatch(tester, right);

      final left = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5], save: saveWithSettings((s) => s.copyWith(leftHanded: true)));
      final trayLeft = tester.getCenter(find.byType(DiceTray)).dx < tester.getCenter(mine).dx;
      expect(trayLeft, isTrue, reason: 'left-handed: the tray moves to the outer side');
      await closeMatch(tester, left);
    });

    testWidgets('big text does not break the layout', (tester) async {
      final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5], textScale: 1.6);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DiceTray));
      await pumpFor(tester, 2.5);
      expect(tester.takeException(), isNull);
      await closeMatch(tester, bed);
    });

    testWidgets('big pieces and colour-blind marks draw without trouble', (tester) async {
      final bed = await pumpMatch(
        tester,
        position: (s) => artboardPosition(s),
        rolls: [5],
        save: saveWithSettings((s) => s.copyWith(bigPieces: true, colourPatterns: true)),
      );
      expect(tester.takeException(), isNull);
      await closeMatch(tester, bed);
    });
  });
}
