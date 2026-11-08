// The test harness is shared by every feature wave, so it is tested too:
// the real fonts load, a capture is a 390 × 844 PNG, pumpScreen mounts a screen
// inside the app frame with the sample save, and a language option reaches tr().

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ludo_mela/core/feedback/feedback.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/tr.dart';
import 'package:ludo_mela/core/router/app_router.dart';
import 'package:ludo_mela/core/router/routes.dart';
import 'package:ludo_mela/core/theme/fonts.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../helpers/app_harness.dart';
import '../helpers/fake_feedback.dart';
import '../helpers/screen_capture.dart';
import '../helpers/screen_harness.dart' as screen;

/// Width and height from a PNG's IHDR chunk.
(int, int) pngSize(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  return (d.getUint32(16), d.getUint32(20));
}

double widthOf(String text, TextStyle style) {
  final p = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
  return p.width;
}

void main() {
  test('the sample save is a player part-way through (Settings board: level 7, 340 / 450 XP)', () {
    final p = sampleSave().activeProfile;
    expect((p.name, p.level, p.xpIntoLevel, p.xpToNext), ('Mitu', 7, 340, 450));
    expect(sampleSave().device.onboarded, isTrue);
    expect(testNow, DateTime(2026, 11, 7, 19, 30));
  });

  testWidgets('loadAppFonts registers the real Lilita One, Baloo 2 and Baloo Da 2', (tester) async {
    await loadAppFonts();
    await loadAppFonts(); // idempotent
    // The test font ("Ahem") is exactly one em wide per character; the real faces are not.
    final display = widthOf('Ludo Mela', TextStyle(fontFamily: AppFonts.display, fontSize: 40));
    expect(display, lessThan(40 * 9 * .8), reason: 'Lilita One is narrower than the 360 px Ahem would give');
    final bangla = widthOf('মেলা', TextStyle(fontFamily: AppFonts.bangla, fontSize: 40));
    expect(bangla, greaterThan(20));
  });

  group('pumpScreen', () {
    testWidgets('mounts a screen in the app frame on the sample save, with silent feedback', (tester) async {
      final c = await screen.pumpScreen(
        tester,
        (context, state) => Scaffold(body: Center(child: Text(viewSize(context)))),
      );
      expect(find.text('390.0 x 844.0'), findsOneWidget, reason: 'the reference phone');
      expect(c.read(activeProfileProvider).name, 'Mitu');
      expect(c.read(clockProvider)(), testNow);
      expect(c.read(feedbackProvider), isA<FakeFeedback>());
      await screen.closeScreen(tester, c);
    });

    testWidgets('unknown paths show their name, so a navigation can be asserted', (tester) async {
      final c = await screen.pumpScreen(
        tester,
        (context, state) => Scaffold(
          body: Center(child: TextButton(onPressed: () => context.push(Routes.settings), child: const Text('go'))),
        ),
      );
      await tester.tap(find.text('go'));
      await screen.settle(tester);
      expect(find.text('route /settings'), findsOneWidget);
      await screen.closeScreen(tester, c);
    });

    testWidgets('language: switches tr() to the bundled pack for the test, and back afterwards', (tester) async {
      final c = await screen.pumpScreen(tester, (context, state) => Scaffold(body: Text(tr('Stay'))), language: AppLanguage.bn);
      expect(find.text('থাকো'), findsOneWidget);
      await screen.closeScreen(tester, c);
    });

    testWidgets('textScale and reduceMotion reach the screen', (tester) async {
      final c = await screen.pumpScreen(
        tester,
        (context, state) => Scaffold(body: Text('${MediaQuery.textScalerOf(context).scale(10)} ${MediaQuery.disableAnimationsOf(context)}')),
        textScale: 1.2,
        reduceMotion: true,
      );
      expect(find.text('12.0 true'), findsOneWidget);
      await screen.closeScreen(tester, c);
    });
  });

  testWidgets('language stays English in the next test (the harness resets it)', (tester) async {
    expect(tr('Stay'), 'Stay');
  });

  testWidgets('capture writes a PNG of exactly 390 × 844 pixels at pixelRatio 1', (tester) async {
    final c = await screen.pumpScreen(
      tester,
      (context, state) => Scaffold(
        backgroundColor: const Color(0xFF0F45A6),
        body: Center(child: Text('Ludo Mela', style: AppFonts.displayStyle(size: 40))),
      ),
    );
    final file = await capture(tester, 'harness_smoke');
    expect(file.path.replaceAll(r'\', '/'), 'build/screens/harness_smoke.png');
    final bytes = file.readAsBytesSync();
    expect(bytes.sublist(1, 4), 'PNG'.codeUnits);
    expect(pngSize(bytes), (390, 844));
    final big = await capture(tester, 'harness_smoke_2x', pixelRatio: 2);
    expect(pngSize(big.readAsBytesSync()), (780, 1688));
    File('build/screens/harness_smoke_2x.png').deleteSync();
    await screen.closeScreen(tester, c);
  });

  testWidgets('pumpApp runs the real router from any route', (tester) async {
    final c = await pumpApp(tester, route: Routes.settings);
    expect(c.read(routerProvider).routerDelegate.currentConfiguration.last.matchedLocation, Routes.settings);
    expect(tester.takeException(), isNull);
    await closeApp(tester, c);
  });
}

String viewSize(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return '${size.width} x ${size.height}';
}
