// Tokens of the design system (board A): colours, glossy actions, the type scale,
// spacing / radii / depth, the box painter and the app theme.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/engine_geometry.dart';
import 'package:ludo_mela/core/theme/app_theme.dart';
import 'package:ludo_mela/core/theme/box_paint.dart';
import 'package:ludo_mela/core/theme/colors.dart';
import 'package:ludo_mela/core/theme/fonts.dart';
import 'package:ludo_mela/core/theme/gloss.dart';
import 'package:ludo_mela/core/theme/space.dart';
import 'package:ludo_mela/core/theme/text.dart';

void main() {
  group('colour tokens', () {
    test('seat palettes are fixed by seat and distinct', () {
      expect(LmColors.seat(Seat.red).main, const Color(0xFFE8322B));
      expect(LmColors.seat(Seat.green).main, const Color(0xFF76BE2E));
      expect(LmColors.seat(Seat.yellow).main, const Color(0xFFF8C21C));
      expect(LmColors.seat(Seat.blue).main, const Color(0xFF1E8BEA));
      final mains = {for (final s in Seat.values) LmColors.seat(s).main};
      expect(mains.length, 4);
      // dark is darker than main, light is lighter, side is the darkest
      for (final s in Seat.values) {
        final c = LmColors.seat(s);
        expect(c.dark.computeLuminance(), lessThan(c.main.computeLuminance()));
        expect(c.light.computeLuminance(), greaterThan(c.main.computeLuminance()));
        expect(c.side.computeLuminance(), lessThan(c.dark.computeLuminance()));
      }
    });

    test('board A section 1 values', () {
      expect(LmColors.navy, const Color(0xFF0A2A6B));
      expect(LmColors.panelRim, const Color(0xFF5FB0FF));
      expect(LmColors.well, const Color(0xFF0D3680));
      expect(LmColors.badgeRed, const Color(0xFFF2463B));
      expect(LmColors.badgeGreen, const Color(0xFF47BA2B));
      expect(LmColors.safeCell, const Color(0xFFCFCFCF));
      expect(LmColors.safeStar, const Color(0xFFA0A0A0));
      expect(LmColors.boardGround, const Color(0xFFD2D2D2));
      expect(LmColors.xpText, const Color(0xFFFFE27A));
      expect(LmColors.scrim, const Color(0xB8040E28)); // rgba(4,14,40,.72)
    });

    test('rarity enum maps to the four frame palettes', () {
      expect(LmRarity.values.length, 4);
      expect(LmRarity.standard.colors, same(LmColors.standard));
      expect(LmRarity.legendary.colors.top, const Color(0xFFC99BFF));
      expect({for (final r in LmRarity.values) r.label}, {'Standard', 'Rare', 'Epic', 'Legendary'});
    });
  });

  group('glossy actions', () {
    test('gradient runs hi → mid (55 %) → lo', () {
      final g = LmGloss.green.gradient;
      expect(g.colors, [LmGloss.green.hi, LmGloss.green.mid, LmGloss.green.lo]);
      expect(g.stops, [0, .55, 1]);
      expect(g.angle, 180);
    });

    test('shadow stack: inner band, lip, soft drop', () {
      final s = LmGloss.green.shadows(lipHeight: 5);
      expect(s.length, 3);
      expect(s[0].inset, isTrue);
      expect(s[0].dy, -3);
      expect(s[1].color, LmGloss.green.lip);
      expect(s[1].dy, 5);
      expect(s[2].blur, 12);
    });

    test('navy has an inner rim; gold uses dark brown text with a white top light', () {
      expect(LmGloss.navy.shadows().first.spread, 2);
      expect(LmGloss.gold.ink, LmColors.inkOnGold);
      expect(LmGloss.gold.labelShadow.color.a, greaterThan(.5));
      expect(LmGloss.green.labelShadow.offset, const Offset(0, 2));
    });

    test('seat gloss uses the seat palette', () {
      final g = LmGloss.seat(LmColors.blue);
      expect(g.hi, LmColors.blue.light);
      expect(g.lip, LmColors.blue.side);
    });
  });

  group('type scale', () {
    test('sizes of board A section 2', () {
      expect(LmText.display.fontSize, 40);
      expect(LmText.h1.fontSize, 26);
      expect(LmText.h2.fontSize, 24);
      expect(LmText.cta.fontSize, 30);
      expect(LmText.btnL.fontSize, 24);
      expect(LmText.btnM.fontSize, 16);
      expect(LmText.btnS.fontSize, 14);
      expect(LmText.label.fontSize, 13);
      expect(LmText.value.fontSize, 14);
      expect(LmText.body.fontSize, 14);
      expect(LmText.caption.fontSize, 11);
    });

    test('display text is Lilita One with 8 × 1.5 pt navy shadows and a 3 pt drop', () {
      final s = LmText.display;
      expect(s.fontFamily, AppFonts.display);
      expect(s.shadows!.length, 9);
      expect(s.shadows!.every((e) => e.color == LmColors.navy && e.blurRadius == 0), isTrue);
      expect(s.shadows!.last.offset, const Offset(0, 3));
      expect(s.shadows!.take(4).map((e) => e.offset.distance), everyElement(1.5));
    });

    test('on gold the text is brown with a 1 pt white light instead of the outline', () {
      final s = LmText.onGold(20);
      expect(s.color, const Color(0xFF5A2E00));
      expect(s.shadows!.length, 1);
      expect(s.shadows!.single.offset, const Offset(0, 1));
    });

    test('body styles pass the variable-font weight axis', () {
      final s = LmText.bodyAt(14, weight: FontWeight.w800);
      expect(s.fontFamily, AppFonts.body);
      expect(s.fontVariations!.single.axis, 'wght');
      expect(s.fontVariations!.single.value, 800);
      expect(LmText.display.fontVariations, isNotEmpty);
      expect(LmText.display.fontFamilyFallback, AppFonts.fallback);
    });

    test('numbers use tabular figures', () {
      expect(LmText.value.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('space, radius, depth', () {
    test('4 pt grid', () {
      expect([LmSpace.xxs, LmSpace.xs, LmSpace.s, LmSpace.m, LmSpace.l, LmSpace.xl, LmSpace.xxl, LmSpace.xxxl], [2, 4, 6, 8, 10, 12, 16, 24]);
    });

    test('radii of board A section 3', () {
      expect([LmRadius.tag, LmRadius.buttonS, LmRadius.card, LmRadius.buttonL, LmRadius.bigTile, LmRadius.modal], [5, 10, 12, 14, 16, 20]);
      expect(LmRadius.full, greaterThan(100));
    });

    test('depth stacks match the CSS', () {
      expect(LmDepth.card.first.spread, 2);
      expect(LmDepth.card.last.dy, 3);
      expect(LmDepth.well.every((s) => s.inset), isTrue);
      expect(LmDepth.modal[0].spread, 3);
      expect(LmDepth.modal[2].dy, 6);
      final raised = LmDepth.raised(const Color(0xFF123456), lipHeight: 4);
      expect(raised[1].dy, 4);
    });
  });

  group('box painter', () {
    test('LmGradient follows the CSS gradient line (corners get the end colours)', () {
      const g = LmGradient([Color(0xFF000000), Color(0xFFFFFFFF)], angle: 90);
      final sh = g.shader(const Rect.fromLTWH(0, 0, 200, 50));
      expect(sh, isNotNull);
      const diag = LmGradient([Color(0xFF000000), Color(0xFFFFFFFF)], angle: 135);
      expect(diag.shader(const Rect.fromLTWH(0, 0, 100, 100)), isNotNull);
    });

    test('shadow equality and scaling', () {
      const a = LmShadow(Color(0x80000000), dy: 4, blur: 8);
      expect(a, const LmShadow(Color(0x80000000), dy: 4, blur: 8));
      expect(a.scaled(.5).dy, 2);
      expect(a.withColor(const Color(0xFFFFFFFF)).color, const Color(0xFFFFFFFF));
      expect(lmShadowsEqual([a], [a]), isTrue);
    });

    test('lmPaintBox draws outer lip pixels below the box', () async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 100, 100));
      lmPaintBox(
        canvas,
        RRect.fromRectAndRadius(const Rect.fromLTWH(20, 20, 60, 40), const Radius.circular(10)),
        color: const Color(0xFF00FF00),
        shadows: const [LmShadow(Color(0xFFFF0000), dy: 6)],
      );
      final img = await rec.endRecording().toImage(100, 100);
      final data = (await img.toByteData())!;
      Color at(int x, int y) {
        final i = (y * 100 + x) * 4;
        return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
      }

      expect(at(50, 40), const Color(0xFF00FF00)); // the face
      expect(at(50, 63), const Color(0xFFFF0000)); // the 6 pt lip under the 40 pt box (y 60 – 66)
      expect(at(50, 70).a, 0); // nothing below the lip
    });

    test('inset shadows stay inside the box', () async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec, const Rect.fromLTWH(0, 0, 100, 100));
      lmPaintBox(
        canvas,
        RRect.fromRectAndRadius(const Rect.fromLTWH(10, 10, 80, 80), const Radius.circular(8)),
        color: const Color(0xFFFFFFFF),
        shadows: const [LmShadow.rim(Color(0xFF0000FF), 3)],
      );
      final img = await rec.endRecording().toImage(100, 100);
      final data = (await img.toByteData())!;
      Color at(int x, int y) {
        final i = (y * 100 + x) * 4;
        return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
      }

      expect(at(11, 50), const Color(0xFF0000FF)); // inside the 3 pt rim
      expect(at(50, 50), const Color(0xFFFFFFFF)); // the face
      expect(at(5, 50).a, 0); // the rim does not spill outside
    });

    test('elliptical radial shader builds', () {
      final s = lmEllipticalRadialShader(const Offset(195, 400), 429, 506, const [Color(0xFF3EA2FF), Color(0xFF0F45A6)], const [0, 1]);
      expect(s, isNotNull);
    });
  });

  group('app theme', () {
    test('dark game theme without ink splashes', () {
      final t = buildAppTheme();
      expect(t.brightness, Brightness.dark);
      expect(t.scaffoldBackgroundColor, LmColors.deep);
      expect(t.splashFactory, NoSplash.splashFactory);
      expect(t.textTheme.bodyMedium!.fontFamily, AppFonts.body);
      expect(t.colorScheme.secondary, const Color(0xFFFFC61F));
    });
  });

  test('every family name lives in AppFonts only', () {
    expect({AppFonts.display, AppFonts.body, AppFonts.bangla}, {'LilitaOne', 'Baloo2', 'BalooDa2'});
    expect(AppFonts.fallback.first, AppFonts.bangla);
    expect(AppFonts.weightAxis(FontWeight.w600).single.value, 600);
    expect(AppFonts.displayStyle(size: 20).fontVariations, isNotEmpty);
  });
}
