// No overflow, nothing off screen: every way of playing, at the reference phone (390 x 844) and a small Android
// (360 x 740, with a notch and a home indicator), plus the overlays (pause, leave, stickers) and bigger text.
// A RenderFlex overflow is an exception in a widget test, so "takeException is null" is the whole check; the
// board is also asserted to be on screen and square.

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart' hide MoveTag;
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/features/match/session/match_setup.dart';

import 'match_rig.dart';

/// One way of playing to lay out.
class _Variant {
  const _Variant(this.name, this.setup, [this.position]);

  final String name;
  final MatchSetup Function() setup;
  final GameState Function(GameState s)? position;
}

final _variants = <_Variant>[
  _Variant('classic, four players', () => botGame(), (s) => artboardPosition(s)),
  _Variant('classic, two players', () => botGame(players: 2)),
  _Variant('quick', () => botGame(mode: GameMode.quick)),
  _Variant('master', () => botGame(mode: GameMode.master)),
  _Variant('rush', () => botGame(mode: GameMode.rush)),
  _Variant('teams', () => botGame(mode: GameMode.teams)),
  _Variant('mayhem with an event and a full hand', () => botGame(mode: GameMode.mayhem), (s) => mayhemPosition(s)),
  _Variant('mayhem without an event', () => botGame(mode: GameMode.mayhem), (s) => mayhemPosition(s, event: false, hand: const [])),
  _Variant('venue table with hints', () => botGame(practice: false, venueId: 'village_haat')),
  _Variant('pass & play on the phone in hand', () => MatchSetup.passAndPlay(
        mode: GameMode.classic,
        firstSeat: Seat.red,
        players: const [PlayerSpec(seat: Seat.red, name: 'Mitu', id: 'p1'), PlayerSpec(seat: Seat.yellow, name: 'Raphaela-Maria', avatar: 'panda')],
      )),
  _Variant('tabletop', () => tabletopGame(), (s) => artboardPosition(s)),
];

const _sizes = [Size(390, 844), Size(360, 740)];

void main() {
  for (final size in _sizes) {
    group('${size.width.toInt()} x ${size.height.toInt()}', () {
      for (final v in _variants) {
        testWidgets(v.name, (tester) async {
          final bed = await pumpMatch(tester, setup: v.setup(), position: v.position, rolls: [5]);
          if (size != _sizes.first) await useSmallPhone(tester);
          expect(tester.takeException(), isNull);

          // The board is whole, square and on screen.
          final board = tester.getRect(find.byType(BoardView));
          expect(board.width, closeTo(board.height, 1.0));
          expect(board.left, greaterThanOrEqualTo(0));
          expect(board.right, lessThanOrEqualTo(size.width));
          expect(board.top, greaterThanOrEqualTo(47), reason: 'under the status bar');
          expect(board.bottom, lessThanOrEqualTo(size.height - 34), reason: 'above the home indicator');
          expect(board.width, greaterThanOrEqualTo(220));

          // A roll adds tags, a ring and the mini dice: still no overflow.
          final tray = find.byType(DiceTray);
          if (tray.evaluate().isNotEmpty) {
            await tester.tap(tray);
            await pumpFor(tester, 2.5);
            expect(tester.takeException(), isNull);
          }
          await closeMatch(tester, bed);
        });
      }

      testWidgets('with the sticker picker, a bubble, the pause menu and the leave question', (tester) async {
        final handle = tester.ensureSemantics();
        final bed = await pumpMatch(tester, position: (s) => artboardPosition(s), rolls: [5]);
        if (size != _sizes.first) await useSmallPhone(tester);
        await tester.tap(find.bySemanticsLabel('Stickers and quick chat'));
        await pumpFor(tester, .6);
        expect(tester.takeException(), isNull);
        final picker = tester.getRect(find.bySemanticsLabel('Stickers and quick chat').last);
        expect(picker.right, lessThanOrEqualTo(size.width));
        await tester.tap(find.text('Well played!'));
        await pumpFor(tester, .8);
        expect(tester.takeException(), isNull);
        await tester.binding.handlePopRoute();
        await pumpFor(tester, .8);
        expect(find.text('PAUSED'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final sheet = tester.getRect(find.text('LEAVE MATCH'));
        expect(sheet.bottom, lessThanOrEqualTo(size.height), reason: 'the whole sheet is reachable (it scrolls when short)');
        await tester.tap(find.text('LEAVE MATCH'));
        await pumpFor(tester, .8);
        expect(find.text('Leave this match?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await closeMatch(tester, bed);
        handle.dispose();
      });

      testWidgets('with bigger text (1.3) on the hardest screens', (tester) async {
        for (final v in [_variants[6], _variants[4], _variants[0]]) {
          final bed = await pumpMatch(tester, setup: v.setup(), position: v.position, rolls: [5], textScale: 1.3);
          if (size != _sizes.first) await useSmallPhone(tester);
          expect(tester.takeException(), isNull, reason: v.name);
          await closeMatch(tester, bed);
        }
      });
    });
  }
}
