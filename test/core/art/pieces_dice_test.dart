// Pieces (coins) and dice: every skin x seat x state paints at every board size,
// pieces are tappable with a 44 pt target and labelled, and the dice cube rolls
// on the documented clock (820 ms toss + 230 ms settle, onLand at the landing,
// Reduce Motion = a short fade), clamps its faces and works from a controller.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/art/engine_geometry.dart';

import '../../helpers/kit_harness.dart';

Widget _topLeft(Widget child) => Align(alignment: Alignment.topLeft, child: child);

void main() {
  setUpAll(loadKitFonts);

  group('PieceSkins', () {
    test('seven skins with distinct ids; unknown ids fall back to lotus coins', () {
      expect(PieceSkins.all, hasLength(7));
      expect(PieceSkins.all.map((s) => s.id).toSet(), hasLength(7));
      expect(PieceSkins.all.map((s) => s.id), ['lotus', 'star', 'moon', 'crown', 'diya', 'peacock', 'elephant']);
      expect(PieceSkins.byId(null), PieceSkins.lotus);
      expect(PieceSkins.byId('nope'), PieceSkins.lotus);
      for (final s in PieceSkins.all) {
        expect(PieceSkins.byId(s.id), same(s));
        expect(s.name, isNotEmpty);
      }
    });
  });

  group('PieceCoin', () {
    testWidgets('every skin x seat x state paints at the sizes of road, yard, stack and home', (tester) async {
      for (final skin in PieceSkins.all) {
        for (final seat in Seat.values) {
          for (final state in PieceState.values) {
            for (final (size, unit, count) in const [(22.0, 1.0, 1), (29.0, 1.0, 1), (19.0, 1.0, 2), (15.0, .8, 1), (22.0, 1.0, 4)]) {
              await tester.pumpWidget(kitApp(_topLeft(PieceCoin(seat: seat, size: size, unit: unit, skin: skin, state: state, count: count))));
              await tester.pump(const Duration(milliseconds: 16));
              expect(tester.takeException(), isNull, reason: '${skin.id} $seat $state $size x$count');
            }
          }
        }
      }
    });

    testWidgets('colour-blind marks and the hint glow paint', (tester) async {
      for (final mark in SeatMark.values) {
        await tester.pumpWidget(kitApp(_topLeft(PieceCoin(seat: Seat.blue, mark: mark, hinted: true))));
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull, reason: '$mark');
      }
    });

    testWidgets('the hit box is 44 pt at C = 25 and scales with the board', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red))));
      expect(tester.getSize(find.byType(PieceCoin)), const Size.square(44));
      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red, unit: .8))));
      expect(tester.getSize(find.byType(PieceCoin)), const Size.square(35.2));
      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red, extent: 60))));
      expect(tester.getSize(find.byType(PieceCoin)), const Size.square(60));
    });

    testWidgets('each seat has its colour on the coin face', (tester) async {
      for (final (seat, test) in <(Seat, bool Function(Color))>[
        (Seat.red, (c) => c.r > c.g + .25 && c.r > c.b + .25),
        (Seat.green, (c) => c.g > c.r + .1 && c.g > c.b + .25),
        (Seat.yellow, (c) => c.r > c.b + .35 && c.g > c.b + .3),
        (Seat.blue, (c) => c.b > c.r + .25 && c.b > c.g + .05),
      ]) {
        final px = await renderPixels(tester, PieceCoin(seat: seat, size: 40, extent: 60), width: 60, height: 60);
        final face = px.at(30, 41); // below the emblem
        expect(test(face), isTrue, reason: '$seat coin face was $face');
      }
    });

    testWidgets('a target ghost is a dashed circle on gold, not a coloured coin', (tester) async {
      final ghost = await renderPixels(tester, const PieceCoin(seat: Seat.red, size: 40, extent: 60, state: PieceState.ghost), width: 60, height: 60);
      final c = ghost.at(30, 30);
      expect(c.a, greaterThan(.3));
      expect(c.g, greaterThan(c.b), reason: 'gold-ish, not red');
      await tester.pumpWidget(kitApp(const TargetGhost()));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping: the 44 pt box reaches past the 22 pt coin; labels and button semantics', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(kitApp(Center(child: PieceCoin(seat: Seat.green, semanticLabel: 'Green piece 2', onTap: () => taps++))));
      await tester.tapAt(tester.getCenter(find.byType(PieceCoin)) + const Offset(18, 0));
      expect(taps, 1);
      final node = tester.getSemantics(find.bySemanticsLabel('Green piece 2'));
      expect(node.label, 'Green piece 2');
      expect(node.flagsCollection.isButton, isTrue);

      await tester.pumpWidget(kitApp(const Center(child: PieceCoin(seat: Seat.green))));
      expect(find.bySemanticsLabel('Green piece 2'), findsNothing);
      handle.dispose();
    });

    testWidgets('movable pieces (ring + bob), shields and the hint animate; idle pieces and Reduce Motion do not', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red, state: PieceState.movable))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));

      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red, state: PieceState.movable)), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0, reason: 'Reduce Motion keeps the ring still');

      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0, reason: 'an idle coin never ticks');

      await tester.pumpWidget(kitApp(_topLeft(const PieceCoin(seat: Seat.red, state: PieceState.shielded))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
    });

    testWidgets('MoveTag shows its text; StandingPawn paints', (tester) async {
      await tester.pumpWidget(kitApp(Column(children: [
        const MoveTag(text: 'CAPTURE', color: MoveTag.capture),
        for (final s in Seat.values) StandingPawn(seat: s),
      ])));
      expect(find.text('CAPTURE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('DiceSkins and faces', () {
    test('seven dice with distinct ids; unknown ids fall back to Mela Classic', () {
      expect(DiceSkins.all, hasLength(7));
      expect(DiceSkins.all.map((s) => s.id).toSet(), hasLength(7));
      expect(DiceSkins.all.map((s) => s.name), ['Mela Classic', 'Ruby Jelly', 'Ocean Glass', 'Gold Mohur', 'Midnight Gold', 'Peacock Royal', 'Mela Lantern']);
      expect(DiceSkins.byId(null), DiceSkins.classic);
      expect(DiceSkins.byId('nope'), DiceSkins.classic);
      for (final s in DiceSkins.all) {
        expect(DiceSkins.byId(s.id), same(s));
      }
    });

    testWidgets('flat faces 1 – 6 for every skin, mini dice and collection icons', (tester) async {
      for (final skin in DiceSkins.all) {
        for (var v = 1; v <= 6; v++) {
          for (final flat in const [true, false]) {
            await tester.pumpWidget(kitApp(_topLeft(DiceFace(value: v, skin: skin, size: 44, flat: flat))));
            expect(tester.takeException(), isNull, reason: '${skin.id} $v flat=$flat');
          }
        }
        await tester.pumpWidget(kitApp(_topLeft(DiceIcon(skin: skin))));
        expect(tester.takeException(), isNull, reason: skin.id);
      }
      for (var v = 1; v <= 6; v++) {
        await tester.pumpWidget(kitApp(_topLeft(MiniDice(value: v, size: 18))));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('classic dice show a red pip on 1 and dark pips on 2; the labels are read out', (tester) async {
      final one = await renderPixels(tester, DiceFace(value: 1, size: 60), width: 60, height: 60);
      final pip = one.at(30, 30);
      expect(pip.r, greaterThan(pip.g + .35), reason: 'the single pip is red');
      final two = await renderPixels(tester, DiceFace(value: 2, size: 60), width: 60, height: 60);
      final c = two.at(30, 30);
      expect(c.r, greaterThan(.7), reason: 'no pip in the middle of a 2');
      expect(c.g, greaterThan(.7));
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(DiceFace(value: 5, semanticLabel: 'Dice showing 5'))));
      expect(find.bySemanticsLabel('Dice showing 5'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DiceCube', () {
    testWidgets('every skin renders at tray, board and splash sizes', (tester) async {
      for (final skin in DiceSkins.all) {
        for (final size in const [20.0, 44.0, 104.0]) {
          for (var v = 1; v <= 6; v++) {
            await tester.pumpWidget(kitApp(_topLeft(DiceCube(skin: skin, size: size, initialValue: v))));
            expect(tester.takeException(), isNull, reason: '${skin.id} $size $v');
          }
        }
      }
    });

    testWidgets('different faces look different', (tester) async {
      Future<List<int>> face(int v) async {
        final px = await renderPixels(tester, DiceCube(size: 80, initialValue: v), width: 80, height: 80);
        return px.rgba.buffer.asUint8List(px.rgba.offsetInBytes, px.rgba.lengthInBytes).toList();
      }

      final f1 = await face(1);
      final f5 = await face(5);
      expect(f5, isNot(f1));
    });

    testWidgets('roll(to: n): 820 ms toss, onLand at the landing, done after the 230 ms settle', (tester) async {
      final c = DiceCubeController();
      final landed = <int>[];
      await tester.pumpWidget(kitApp(_topLeft(DiceCube(controller: c, onLand: landed.add))));
      expect(c.value, 1);
      expect(c.isRolling, isFalse);

      var done = false;
      final future = c.roll(to: 5)..then((_) => done = true);
      await tester.pump();
      expect(c.isRolling, isTrue);
      expect(c.value, 5, reason: 'the target is fixed at the start (fair roll decided by the engine)');

      await tester.pump(const Duration(milliseconds: 700));
      expect(landed, isEmpty, reason: 'still tumbling');
      await tester.pump(const Duration(milliseconds: 160));
      expect(landed, [5], reason: 'landed at 820 ms');
      expect(done, isFalse, reason: 'settling');
      await tester.pump(const Duration(milliseconds: 260));
      await future;
      expect(done, isTrue);
      expect(c.isRolling, isFalse);
      expect(landed, [5], reason: 'onLand fires once');
    });

    testWidgets('faces are clamped to 1 – 6 and show() jumps without animation', (tester) async {
      final c = DiceCubeController();
      await tester.pumpWidget(kitApp(_topLeft(DiceCube(controller: c))));
      final up = c.roll(to: 9);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await up;
      expect(c.value, 6);
      final down = c.roll(to: 0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await down;
      expect(c.value, 1);
      c.show(3);
      expect(c.value, 3);
      expect(c.isRolling, isFalse);
    });

    testWidgets('a second roll supersedes the first and both futures complete', (tester) async {
      final c = DiceCubeController();
      await tester.pumpWidget(kitApp(_topLeft(DiceCube(controller: c))));
      final first = c.roll(to: 2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final second = c.roll(to: 4);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await Future.wait([first, second]);
      expect(c.value, 4);
      expect(c.isRolling, isFalse);
    });

    testWidgets('Reduce Motion: a 120 ms fade to the face, onLand at once', (tester) async {
      final c = DiceCubeController();
      final landed = <int>[];
      await tester.pumpWidget(kitApp(_topLeft(DiceCube(controller: c, onLand: landed.add)), disableAnimations: true));
      final f = c.roll(to: 3);
      expect(landed, [3]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await f;
      expect(c.value, 3);
      expect(c.isRolling, isFalse);
    });

    testWidgets('an unmounted controller completes at once', (tester) async {
      await DiceCubeController().roll(to: 2);
      DiceCubeController().show(2);
    });

    testWidgets('the splash cube spins forever, but not with Reduce Motion', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const DiceCube(spin: true, size: 104))));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(kitApp(_topLeft(const DiceCube(spin: true, size: 104)), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('semantics label on the cube', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(const DiceCube(semanticLabel: 'Your dice'))));
      expect(find.bySemanticsLabel('Your dice'), findsOneWidget);
      handle.dispose();
    });
  });

  group('DiceTray', () {
    testWidgets('60 pt tray; tapping rolls; the arrow bounces only on your turn', (tester) async {
      final handle = tester.ensureSemantics();
      var rolls = 0;
      final c = DiceCubeController();
      await tester.pumpWidget(kitApp(Center(child: DiceTray(controller: c, onRoll: () => rolls++, showArrow: true, animateIn: false))));
      expect(tester.getSize(find.byType(DiceTray)), const Size.square(60));
      expect(find.byType(LmIcon), findsOneWidget, reason: 'the green arrow');
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, greaterThan(0), reason: 'the arrow bobs');
      await tester.tap(find.byType(DiceTray));
      expect(rolls, 1);
      expect(find.bySemanticsLabel('Roll the dice'), findsOneWidget);

      await tester.pumpWidget(kitApp(Center(child: DiceTray(controller: c, animateIn: false))));
      await tester.pump();
      expect(find.byType(LmIcon), findsNothing, reason: 'no arrow when it is not your turn');
      final node = tester.getSemantics(find.bySemanticsLabel('Roll the dice'));
      expect(node.flagsCollection.isButton, isFalse, reason: 'a bot tray is not a button');
      handle.dispose();
    });

    testWidgets('a bot tray carries its own label, both notch sides draw, Reduce Motion stills the arrow', (tester) async {
      final handle = tester.ensureSemantics();
      final c = DiceCubeController();
      for (final notch in TrayNotch.values) {
        await tester.pumpWidget(kitApp(Center(child: DiceTray(controller: c, notch: notch, semanticLabel: "Mitu's dice"))));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.bySemanticsLabel("Mitu's dice"), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(kitApp(Center(child: DiceTray(controller: c, showArrow: true, animateIn: false)), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, 0);
      handle.dispose();
    });

    testWidgets('rolling through the tray lands on the face and reports it', (tester) async {
      final c = DiceCubeController();
      final landed = <int>[];
      await tester.pumpWidget(kitApp(Center(child: DiceTray(controller: c, onLand: landed.add, animateIn: false))));
      final f = c.roll(to: 6);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await f;
      expect(landed, [6]);
    });
  });
}
