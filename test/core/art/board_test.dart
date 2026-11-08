// The board art: BoardLayout measurements and grid <-> screen maps, the skin
// catalogue, the cached Picture, and what BoardPainter actually puts on screen
// (yards, lanes, centre triangles, safe squares) at several phone widths.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/art/engine_geometry.dart';

import '../../helpers/kit_harness.dart';

/// Every channel within [tol] of [want].
void expectColor(Color got, Color want, {int tol = 3, String? reason}) {
  int ch(double v) => (v * 255).round();
  expect((ch(got.r) - ch(want.r)).abs(), lessThanOrEqualTo(tol), reason: 'red of $got vs $want ${reason ?? ''}');
  expect((ch(got.g) - ch(want.g)).abs(), lessThanOrEqualTo(tol), reason: 'green of $got vs $want ${reason ?? ''}');
  expect((ch(got.b) - ch(want.b)).abs(), lessThanOrEqualTo(tol), reason: 'blue of $got vs $want ${reason ?? ''}');
}

void main() {
  setUpAll(loadKitFonts);

  group('BoardLayout', () {
    test('C = floor((width - 10) / 15): the 390 pt phone gets 25 pt squares and a 385 pt board', () {
      final l = BoardLayout.forWidth(390);
      expect(l.cell, 25);
      expect(l.frame, 5);
      expect(l.size, 385);
      expect(l.inner, const Rect.fromLTWH(5, 5, 375, 375));
      expect(l.unit, 1);
    });

    test('other phones snap to whole points and never overflow', () {
      expect(BoardLayout.forWidth(360).cell, 23);
      expect(BoardLayout.forWidth(360).size, 355);
      expect(BoardLayout.forWidth(320).cell, 20);
      expect(BoardLayout.forWidth(414).cell, 26);
      for (var w = 160.0; w <= 520; w += 7) {
        final l = BoardLayout.forWidth(w);
        expect(l.size, lessThanOrEqualTo(w), reason: 'width $w');
        expect(l.size, 15 * l.cell + 2 * l.frame);
        expect(l.cell, l.cell.floorToDouble());
      }
    });

    test('scaled() keeps the 385 pt drawing proportions at any width', () {
      final l = BoardLayout.scaled(154);
      expect(l.size, 154);
      expect(l.cell, closeTo(25 * 154 / 385, 1e-9));
      expect(l.frame, closeTo(5 * 154 / 385, 1e-9));
      expect(l.unit, closeTo(154 / 385, 1e-9));
    });

    test('mini() uses a chunkier frame and a deeper lip', () {
      final l = BoardLayout.mini(100);
      expect(l.size, 100);
      expect(l.frame, closeTo(4, 1e-9));
      expect(l.cell * 15 + 2 * l.frame, closeTo(100, 1e-9));
      expect(l.lipOverride, isNotNull);
    });

    test('a drawn square is C - 1 at +0.5; yards are 6 C; the centre is 3 C', () {
      final l = BoardLayout.forWidth(390);
      expect(l.cellRect(0, 0), const Rect.fromLTWH(5.5, 5.5, 24, 24));
      expect(l.cellRect(7, 7), const Rect.fromLTWH(5.5 + 7 * 25, 5.5 + 7 * 25, 24, 24));
      expect(l.yardRect(Seat.green), const Rect.fromLTWH(5, 5, 150, 150));
      expect(l.yardRect(Seat.yellow), const Rect.fromLTWH(5 + 9 * 25, 5, 150, 150));
      expect(l.yardRect(Seat.red), const Rect.fromLTWH(5, 5 + 9 * 25, 150, 150));
      expect(l.yardRect(Seat.blue), const Rect.fromLTWH(5 + 9 * 25, 5 + 9 * 25, 150, 150));
      expect(l.yardInnerRect(Seat.red), const Rect.fromLTWH(5 + 16, 5 + 9 * 25 + 16, 118, 118));
      expect(l.centerRect, const Rect.fromLTWH(5 + 150, 5 + 150, 75, 75));
    });

    test('centerOf and pointAt are inverses; cellAt finds the square or null', () {
      final l = BoardLayout.forWidth(390);
      for (final p in const [GridPoint(0, 0), GridPoint(7, 7), GridPoint(14, 3), GridPoint(5.5, 9.25)]) {
        final back = l.pointAt(l.centerOf(p));
        expect(back.row, closeTo(p.row, 1e-9));
        expect(back.col, closeTo(p.col, 1e-9));
      }
      expect(l.cellAt(l.centerOfCell(3, 11)), (row: 3, col: 11));
      expect(l.cellAt(const Offset(1, 1)), isNull, reason: 'inside the frame, outside the grid');
      expect(l.cellAt(Offset(l.size - 1, 200)), isNull);
    });

    test('pieceCenter follows the engine path of every seat from the yard to home', () {
      final l = BoardLayout.forWidth(390);
      for (final seat in Seat.values) {
        for (final progress in const [Board.yard, 0, 12, 40, Board.wrap]) {
          final c = l.pieceCenter(seat, progress, 1);
          expect(l.bounds.contains(c), isTrue, reason: '$seat $progress');
          expect(c, l.centerOf(Board.cellOf(seat, progress, 1)));
        }
      }
    });

    test('piece sizes, stack offsets, hit box', () {
      final l = BoardLayout.forWidth(390);
      expect(l.pieceSize(PieceSpot.road), 22);
      expect(l.pieceSize(PieceSpot.yard), 29);
      expect(l.pieceSize(PieceSpot.stacked), 19);
      expect(l.pieceSize(PieceSpot.home), 15);
      expect(l.stackOffsets(1), [0]);
      expect(l.stackOffsets(2), [-4, 4]);
      expect(l.stackOffsets(3), [-8, 0, 8]);
      expect(l.hitSize, 44);
      final small = BoardLayout.forWidth(320);
      expect(small.pieceSize(PieceSpot.road), closeTo(22 * 20 / 25, 1e-9));
    });

    test('move tags clamp inside the board and flip below on the top row', () {
      final l = BoardLayout.forWidth(390);
      final left = l.tagAnchor(l.centerOfCell(7, 0));
      expect(left.dx, greaterThanOrEqualTo(l.frame + 30));
      final right = l.tagAnchor(l.centerOfCell(7, 14));
      expect(right.dx, lessThanOrEqualTo(l.size - l.frame - 30));
      final mid = l.tagAnchor(l.centerOfCell(7, 7));
      expect(mid.dy, lessThan(l.centerOfCell(7, 7).dy), reason: 'above the square');
      final top = l.tagAnchor(l.centerOfCell(0, 7));
      expect(top.dy, greaterThan(l.centerOfCell(0, 7).dy), reason: 'flipped below on the top row');
    });

    test('loopHeading points along the loop (bearing 0 = east, clockwise)', () {
      // The loop starts at (13, 6) and goes up (towards smaller rows).
      expect(loopHeading(0), closeTo(-90, 1e-9));
      for (var g = 0; g < Board.loopLength; g++) {
        final h = loopHeading(g);
        expect(h, inInclusiveRange(-180, 180));
        expect(h % 45, anyOf(closeTo(0, 1e-6), closeTo(45, 1e-6)), reason: 'steps run along an axis or a corner diagonal ($g)');
      }
    });
  });

  group('BoardSkins', () {
    test('the catalogue: 6 collection boards, 8 venue boards, 11 distinct skins', () {
      expect(BoardSkins.collection, hasLength(6));
      expect(BoardSkins.venues, hasLength(8));
      expect(BoardSkins.all, hasLength(11));
      final ids = BoardSkins.all.map((s) => s.id).toSet();
      expect(ids, hasLength(11));
      expect(ids, containsAll(['mela_wood', 'lantern_night', 'monsoon_garden', 'sandstone', 'royal_palace', 'ocean_reef', 'frost', 'neon']));
      expect(BoardSkins.venues.map((s) => s.id), everyElement(isIn(ids)));
    });

    test('byId falls back to the Mela wood board', () {
      expect(BoardSkins.byId(null).id, 'mela_wood');
      expect(BoardSkins.byId('no_such_board').id, 'mela_wood');
      for (final s in BoardSkins.all) {
        expect(BoardSkins.byId(s.id), same(s));
      }
    });

    test('the Mayhem variant is built once per skin and has the purple frame', () {
      final a = BoardSkins.mayhem(BoardSkins.melaWood);
      expect(BoardSkins.mayhem(BoardSkins.melaWood), same(a));
      expect(a.id, 'mela_wood+mayhem');
      expect(a.frameLine, const Color(0xFFFFD45A));
      expect(BoardSkins.mayhem(BoardSkins.frost), isNot(same(a)));
    });

    test('every skin has a main and a darker tone for the four seats', () {
      for (final s in BoardSkins.all) {
        expect(s.seats, hasLength(4), reason: s.id);
        for (final c in s.seats) {
          expect(c.dark.computeLuminance(), lessThanOrEqualTo(c.main.computeLuminance() + 1e-9), reason: '${s.id}: dark is not lighter than main');
        }
        expect(s.name, isNotEmpty);
      }
    });
  });

  group('BoardPictureCache', () {
    test('one recorded picture per skin + size + options, reused until cleared', () {
      BoardPictureCache.clear();
      final skin = BoardSkins.melaWood;
      final l = BoardLayout.forWidth(390);
      const o = BoardPaintOptions();
      final a = BoardPictureCache.get(skin, l, o);
      expect(BoardPictureCache.get(skin, l, o), same(a));
      expect(BoardPictureCache.length, 1);
      final b = BoardPictureCache.get(skin, BoardLayout.forWidth(360), o);
      expect(b, isNot(same(a)));
      final m = BoardPictureCache.get(skin, l, const BoardPaintOptions(mayhem: true));
      expect(m, isNot(same(a)));
      expect(BoardPictureCache.length, 3);
      BoardPictureCache.clear();
      expect(BoardPictureCache.length, 0);
    });

    test('the cache is bounded', () {
      BoardPictureCache.clear();
      for (var w = 200.0; w < 200 + 40 * 15; w += 15) {
        BoardPictureCache.get(BoardSkins.melaWood, BoardLayout.forWidth(w), const BoardPaintOptions());
      }
      expect(BoardPictureCache.length, lessThanOrEqualTo(16));
      BoardPictureCache.clear();
    });

    test('BoardPaintOptions compare by value', () {
      expect(const BoardPaintOptions(mayhem: true), const BoardPaintOptions(mayhem: true));
      expect(const BoardPaintOptions(patterns: true), isNot(const BoardPaintOptions()));
      expect(const BoardPaintOptions().hashCode, const BoardPaintOptions().hashCode);
    });
  });

  group('BoardView paints', () {
    testWidgets('every skin at phone widths 280 – 430, with and without Mayhem tiles and colour-blind marks', (tester) async {
      for (final skin in BoardSkins.all) {
        for (final width in const [280.0, 320.0, 360.0, 390.0, 430.0]) {
          final combos = width == 390 ? const [(false, false), (true, false), (false, true), (true, true)] : const [(false, false)];
          for (final (mayhem, patterns) in combos) {
            await tester.pumpWidget(kitApp(Align(
              alignment: Alignment.topLeft,
              child: BoardView(skin: skin, width: width, mayhem: mayhem, patterns: patterns),
            )));
            await tester.pump(const Duration(milliseconds: 50));
            expect(tester.takeException(), isNull, reason: '${skin.id} $width mayhem=$mayhem patterns=$patterns');
            expect(tester.getSize(find.byType(BoardView)).width, lessThanOrEqualTo(width));
          }
        }
      }
    });

    testWidgets('BoardView.mini and BoardPreview draw small boards', (tester) async {
      await tester.pumpWidget(kitApp(Column(children: [
        BoardView.mini(skin: BoardSkins.neon, width: 96),
        BoardPreview(skin: BoardSkins.frost, size: 84),
      ])));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(BoardView).first).width, 96);
    });

    testWidgets('the overlay gets the layout and sits in board coordinates', (tester) async {
      BoardLayout? seen;
      await tester.pumpWidget(kitApp(Align(
        alignment: Alignment.topLeft,
        child: BoardView(
          skin: BoardSkins.melaWood,
          width: 390,
          overlay: (context, layout) {
            seen = layout;
            return const SizedBox.expand();
          },
        ),
      )));
      expect(seen, BoardLayout.forWidth(390));
    });

    testWidgets('semantics: one image with the given label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(Align(alignment: Alignment.topLeft, child: BoardView(skin: BoardSkins.melaWood, width: 300, semanticLabel: 'Ludo board'))));
      expect(find.bySemanticsLabel('Ludo board'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the Mela wood board: yards, lanes, centre triangles, starts, stars and plain squares', (tester) async {
      final skin = BoardSkins.melaWood;
      final px = await renderPixels(tester, BoardView(skin: skin, width: 385), width: 385, height: 385);
      final l = BoardLayout.forWidth(385);

      // The darker rounded square in the middle of each yard, and the flat seat colour round it.
      for (final seat in Seat.values) {
        final yard = l.yardRect(seat);
        final colors = skin.seats[seat.index];
        expectColor(px.at(yard.center.dx, yard.center.dy), colors.dark, reason: '$seat inner yard');
        final corner = seat == Seat.green || seat == Seat.red ? yard.topLeft + const Offset(9, 9) : yard.topRight + const Offset(-9, 9);
        expectColor(px.at(corner.dx, corner.dy), colors.main, reason: '$seat yard');
      }

      // Home lanes (the 5 squares before the centre) are the seat colour.
      for (final (seat, row, col) in [(Seat.red, 12, 7), (Seat.green, 7, 2), (Seat.yellow, 2, 7), (Seat.blue, 7, 12)]) {
        final c = l.centerOfCell(row, col);
        expectColor(px.at(c.dx, c.dy + 8), skin.seats[seat.index].main, reason: '$seat lane');
      }

      // The four flat triangles of the centre face their lanes.
      final cc = l.centerRect.center;
      expectColor(px.at(cc.dx, cc.dy + 22), skin.seats[Seat.red.index].main, reason: 'red triangle (bottom)');
      expectColor(px.at(cc.dx - 22, cc.dy), skin.seats[Seat.green.index].main, reason: 'green triangle (left)');
      expectColor(px.at(cc.dx, cc.dy - 22), skin.seats[Seat.yellow.index].main, reason: 'yellow triangle (top)');
      expectColor(px.at(cc.dx + 22, cc.dy), skin.seats[Seat.blue.index].main, reason: 'blue triangle (right)');

      // A plain road square, a safe star square (grey with a darker star), a start square (seat colour).
      final plain = l.cellRect(8, 0); // left arm, row 8, column 0: not on the loop's special squares
      expectColor(px.at(plain.left + 2, plain.top + 2), skin.cell, reason: 'plain square');
      final (sr, sc) = Board.track[Board.stars.first];
      final safe = l.cellRect(sr, sc);
      expectColor(px.at(safe.left + 2, safe.top + 2), skin.safeCell, reason: 'safe square');
      final star = px.at(safe.center.dx, safe.center.dy);
      expectColor(star, skin.safeStar, tol: 40, reason: 'safe star');
      final (rr, rc) = Board.track[0];
      final start = l.cellRect(rr, rc);
      expectColor(px.at(start.left + 2, start.top + 2), skin.seats[Seat.red.index].main, reason: 'red start square');

      // The 1 pt grey grid shows between squares (anti-aliased: darker than a square, lighter than the ground).
      final gap = px.at(l.cellRect(0, 7).right + .5, l.cellRect(0, 7).center.dy);
      expect(gap.computeLuminance(), lessThan(skin.cell.computeLuminance() - .02), reason: 'grid line');
    });

    testWidgets('Mayhem tiles and colour-blind marks change the drawing', (tester) async {
      Future<List<int>> bytes(bool mayhem, bool patterns) async {
        final px = await renderPixels(tester, BoardView(skin: BoardSkins.melaWood, width: 385, mayhem: mayhem, patterns: patterns), width: 385, height: 385);
        return px.rgba.buffer.asUint8List(px.rgba.offsetInBytes, px.rgba.lengthInBytes).toList();
      }

      final plain = await bytes(false, false);
      expect(await bytes(true, false), isNot(plain), reason: 'mayhem');
      expect(await bytes(false, true), isNot(plain), reason: 'patterns');
    });

    testWidgets('colours never depend on the skin of another board (Frost differs from Mela wood)', (tester) async {
      final a = await renderPixels(tester, BoardView(skin: BoardSkins.melaWood, width: 300), width: 300, height: 300);
      final b = await renderPixels(tester, BoardView(skin: BoardSkins.frost, width: 300), width: 300, height: 300);
      final l = BoardLayout.forWidth(300);
      final c = l.yardRect(Seat.red).topLeft + const Offset(9, 9);
      final ca = a.at(c.dx, c.dy);
      final cb = b.at(c.dx, c.dy);
      expect(ca == cb, isFalse);
      expect(math.max((ca.r - cb.r).abs(), math.max((ca.g - cb.g).abs(), (ca.b - cb.b).abs())), greaterThan(.01));
    });

    testWidgets('the tilt camera is skipped with Reduce Motion', (tester) async {
      await tester.pumpWidget(kitApp(Align(alignment: Alignment.topLeft, child: BoardView(skin: BoardSkins.melaWood, width: 300, tilt: 30)), disableAnimations: true));
      expect(find.descendant(of: find.byType(BoardView), matching: find.byType(Transform)), findsNothing);
      await tester.pumpWidget(kitApp(Align(alignment: Alignment.topLeft, child: BoardView(skin: BoardSkins.melaWood, width: 300, tilt: 30))));
      expect(find.descendant(of: find.byType(BoardView), matching: find.byType(Transform)), findsWidgets);
    });
  });

  test('BoardPainter repaints only when its inputs change', () {
    final l = BoardLayout.forWidth(390);
    final p = BoardPainter(BoardSkins.melaWood, l);
    expect(p.shouldRepaint(BoardPainter(BoardSkins.melaWood, l)), isFalse);
    expect(p.shouldRepaint(BoardPainter(BoardSkins.frost, l)), isTrue);
    expect(p.shouldRepaint(BoardPainter(BoardSkins.melaWood, BoardLayout.forWidth(360))), isTrue);
    expect(p.shouldRepaint(BoardPainter(BoardSkins.melaWood, l, const BoardPaintOptions(mayhem: true))), isTrue);
    // keep the dart:ui import honest: a recorded picture can be turned into an image
    expect(BoardPictureCache.get(BoardSkins.melaWood, l, const BoardPaintOptions()), isA<ui.Picture>());
  });
}
