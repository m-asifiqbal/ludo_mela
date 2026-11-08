// Mela pots (kinds, ready shake, crack-open), the icon glyph set and the emblem
// paths: every glyph parses and paints at several sizes, tints stay single-coloured
// and accessible labels are exposed only when asked for.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/art.dart';
import 'package:ludo_mela/core/art/engine_geometry.dart';

import '../../helpers/kit_harness.dart';

Widget _topLeft(Widget child) => Align(alignment: Alignment.topLeft, child: child);

/// Every glyph of the set, by name (LmGlyphs = ported from the boards, LmIcons = hand-made).
const Map<String, Glyph> _glyphs = {
  'stallCoins': LmGlyphs.stallCoins,
  'stallWheel': LmGlyphs.stallWheel,
  'stallGift': LmGlyphs.stallGift,
  'stallMissions': LmGlyphs.stallMissions,
  'modePass': LmGlyphs.modePass,
  'modeWifi': LmGlyphs.modeWifi,
  'modeMayhem': LmGlyphs.modeMayhem,
  'modePuzzle': LmGlyphs.modePuzzle,
  'dockHome': LmGlyphs.dockHome,
  'dockFriends': LmGlyphs.dockFriends,
  'dockCollection': LmGlyphs.dockCollection,
  'dockRoad': LmGlyphs.dockRoad,
  'dockEvents': LmGlyphs.dockEvents,
  'tabDice': LmGlyphs.tabDice,
  'tabPieces': LmGlyphs.tabPieces,
  'tabBoards': LmGlyphs.tabBoards,
  'coinStack': LmGlyphs.coinStack,
  'gemCluster': LmGlyphs.gemCluster,
  'potClay': LmGlyphs.potClay,
  'ruleClassic': LmGlyphs.ruleClassic,
  'ruleQuick': LmGlyphs.ruleQuick,
  'ruleMayhem': LmGlyphs.ruleMayhem,
  'ruleCup': LmGlyphs.ruleCup,
  'stickerHappy': LmGlyphs.stickerHappy,
  'stickerLaugh': LmGlyphs.stickerLaugh,
  'stickerWow': LmGlyphs.stickerWow,
  'stickerCool': LmGlyphs.stickerCool,
  'stickerAngry': LmGlyphs.stickerAngry,
  'stickerCry': LmGlyphs.stickerCry,
  'coin': LmIcons.coin,
  'gem': LmIcons.gem,
  'gear': LmIcons.gear,
  'chart': LmIcons.chart,
  'lock': LmIcons.lock,
  'tick': LmIcons.tick,
  'check': LmIcons.check,
  'close': LmIcons.close,
  'back': LmIcons.back,
  'forward': LmIcons.forward,
  'plus': LmIcons.plus,
  'play': LmIcons.play,
  'bulb': LmIcons.bulb,
  'info': LmIcons.info,
  'menu': LmIcons.menu,
  'star': LmIcons.star,
  'sparkle': LmIcons.sparkle,
  'trayArrow': LmIcons.trayArrow,
  'shield': LmIcons.shield,
  'freeze': LmIcons.freeze,
  'swap': LmIcons.swap,
  'hop': LmIcons.hop,
  'reroll': LmIcons.reroll,
  'double2': LmIcons.double2,
  'trophy': LmIcons.trophy,
  'lightning': LmIcons.lightning,
  'chevrons': LmIcons.chevrons,
  'chest': LmIcons.chest,
};

void main() {
  setUpAll(loadKitFonts);

  group('MelaPot', () {
    testWidgets('every kind, ready or waiting, in three cloth colours and sizes', (tester) async {
      for (final kind in PotKind.values) {
        for (final ready in const [true, false]) {
          for (final cloth in const [Color(0xFFE8322B), Color(0xFF2B78D6), Color(0xFF9B59E6)]) {
            for (final size in const [24.0, 48.0, 80.0]) {
              await tester.pumpWidget(kitApp(_topLeft(MelaPot(kind: kind, ready: ready, cloth: cloth, size: size))));
              await tester.pump(const Duration(milliseconds: 100));
              expect(tester.takeException(), isNull, reason: '$kind ready=$ready $size');
            }
          }
        }
      }
    });

    testWidgets('the size is the width; the pot is 56 : 58', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const MelaPot(size: 56))));
      expect(tester.getSize(find.descendant(of: find.byType(MelaPot), matching: find.byType(SizedBox)).first), const Size(56, 58));
    });

    testWidgets('a ready pot shakes (a loop); a waiting one and Reduce Motion do not', (tester) async {
      await tester.pumpWidget(kitApp(_topLeft(const MelaPot(ready: true))));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(kitApp(_topLeft(const MelaPot())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(kitApp(_topLeft(const MelaPot(ready: true)), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, 0);
    });

    test('the shake keeps still for 70 % of the loop, then -7, +6, -3 degrees and back to 0', () {
      expect(lmPotShakeAngle(0), 0);
      expect(lmPotShakeAngle(.69), 0);
      expect(lmPotShakeAngle(.75), closeTo(-7, 1e-9));
      expect(lmPotShakeAngle(.82), closeTo(6, 1e-9));
      expect(lmPotShakeAngle(.89), closeTo(-3, 1e-9));
      expect(lmPotShakeAngle(1), closeTo(0, 1e-9));
    });

    testWidgets('open() cracks the pot, reset() puts it back; opening twice is a no-op', (tester) async {
      final c = MelaPotController();
      await tester.pumpWidget(kitApp(_topLeft(MelaPot(ready: true, controller: c))));
      expect(c.isOpen, isFalse);
      final f = c.open();
      expect(c.isOpen, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 700));
      await f;
      await c.open(); // already open
      c.reset();
      expect(c.isOpen, isFalse);
      await tester.pump();
    });

    testWidgets('Reduce Motion: the pot just fades away in 220 ms', (tester) async {
      final c = MelaPotController();
      await tester.pumpWidget(kitApp(_topLeft(MelaPot(controller: c)), disableAnimations: true));
      final f = c.open();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await f;
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unmounted controller does nothing', (tester) async {
      await MelaPotController().open();
      MelaPotController().reset();
    });

    testWidgets('semantics label only when given; empty slot and standing pawn paint', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(kitApp(_topLeft(const MelaPot(semanticLabel: 'Clay pot, ready'))));
      expect(find.bySemanticsLabel('Clay pot, ready'), findsOneWidget);
      await tester.pumpWidget(kitApp(const Column(children: [EmptyPotSlot(), StandingPawn(seat: Seat.blue)])));
      expect(tester.takeException(), isNull);
      handle.dispose();
    });
  });

  group('glyphs', () {
    test('the set is complete: lobby stalls, mode art, dock, tabs, currencies, stickers, HUD and card icons', () {
      expect(_glyphs.length, greaterThanOrEqualTo(57));
      for (final n in const [
        'stallCoins', 'stallWheel', 'stallGift', 'stallMissions', 'modePass', 'modeWifi', 'modeMayhem', 'modePuzzle', //
        'dockHome', 'dockFriends', 'dockCollection', 'dockRoad', 'dockEvents', 'coin', 'gem', 'star', 'gear', 'chart', //
        'lock', 'tick', 'trophy', 'shield', 'freeze', 'swap', 'hop', 'reroll', 'double2', 'stickerHappy', 'stickerLaugh',
        'stickerWow', 'stickerCool', 'stickerAngry', 'stickerCry',
      ]) {
        expect(_glyphs, contains(n));
      }
    });

    test('every part parses to a non-empty path with a fill or a visible stroke, inside its view box', () {
      for (final e in _glyphs.entries) {
        expect(e.value.parts, isNotEmpty, reason: e.key);
        expect(e.value.box, greaterThan(0));
        for (final p in e.value.parts) {
          final b = lmParsePath(p.d).getBounds();
          expect(b.width > 0 || b.height > 0, isTrue, reason: '${e.key}: ${p.d}'); // a straight line has no area
          expect(p.fill != null || p.gradient != null || (p.stroke != null && p.strokeWidth > 0), isTrue, reason: '${e.key} has an invisible part');
          final box = e.value.box;
          expect(b.left, greaterThanOrEqualTo(-box * .25), reason: e.key);
          expect(b.right, lessThanOrEqualTo(box * 1.25), reason: e.key);
          expect(b.top, greaterThanOrEqualTo(-box * .25), reason: e.key);
          expect(b.bottom, lessThanOrEqualTo(box * 1.25), reason: e.key);
        }
      }
    });

    testWidgets('every glyph paints at 12, 24 and 48 pt', (tester) async {
      for (final e in _glyphs.entries) {
        for (final size in const [12.0, 24.0, 48.0]) {
          await tester.pumpWidget(kitApp(_topLeft(LmIcon(e.value, size: size, dropShadow: const Color(0x40000000)))));
          expect(tester.takeException(), isNull, reason: '${e.key} $size');
          expect(tester.getSize(find.byType(LmIcon)), Size.square(size));
        }
      }
    });

    testWidgets('a tint recolours every part to one colour', (tester) async {
      const tint = Color(0xFF00FF00);
      for (final g in [LmIcons.plus, LmIcons.close, LmIcons.lock, LmGlyphs.dockHome]) {
        final px = await renderPixels(tester, LmIcon(g, size: 48, tint: tint), width: 48, height: 48);
        var seen = 0;
        for (var y = 0; y < 48; y++) {
          for (var x = 0; x < 48; x++) {
            final c = px.at(x + .5, y + .5);
            if (c.a > 0) {
              seen++;
              expect(c.r, lessThan(.02), reason: 'red at $x,$y');
              expect(c.b, lessThan(.02), reason: 'blue at $x,$y');
            }
          }
        }
        expect(seen, greaterThan(20));
      }
    });

    testWidgets('opacity fades the icon; semantics label only when given', (tester) async {
      final handle = tester.ensureSemantics();
      final full = await renderPixels(tester, LmIcon(LmIcons.plus, size: 48, tint: const Color(0xFFFFFFFF)), width: 48, height: 48);
      final half = await renderPixels(tester, LmIcon(LmIcons.plus, size: 48, tint: const Color(0xFFFFFFFF), opacity: .5), width: 48, height: 48);
      expect(half.at(24, 24).a, closeTo(full.at(24, 24).a * .5, .05));
      await tester.pumpWidget(kitApp(_topLeft(const LmIcon(LmIcons.gear, semanticLabel: 'Settings'))));
      expect(find.bySemanticsLabel('Settings'), findsOneWidget);
      await tester.pumpWidget(kitApp(_topLeft(const LmIcon(LmIcons.gear))));
      expect(find.bySemanticsLabel('Settings'), findsNothing);
      handle.dispose();
    });
  });

  group('emblems', () {
    test('every piece emblem and the Mayhem bolt parse to real paths', () {
      for (final s in PieceSkins.all) {
        expect(lmParsePath(s.emblem).getBounds().isEmpty, isFalse, reason: s.id);
      }
      expect(lmParsePath(LmEmblems.bolt).getBounds().isEmpty, isFalse);
    });
  });
}
