// Renders the app at phone size with the REAL bundled fonts and writes a PNG to
// build/screens/<name>.png — for eyeballing screens next to the artboard renders
// in design/tools/shots/*.png (390 × 844 px) without a device.
// (The file name must not end in _test.dart: it is a helper, not a test.)
//
// Why fonts are loaded by hand: flutter_test only ships the "Ahem" test font, so
// text would render as blocks. The real Lilita One / Baloo 2 / Baloo Da 2 files
// are registered under the family names AppFonts uses (and the Material icon
// font, so `Icons.*` draw).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/theme/fonts.dart';

bool _fontsLoaded = false;

/// Registers Lilita One, Baloo 2, Baloo Da 2 and the Material icon font so
/// captures look real. Call once per test file (it is idempotent).
Future<void> loadAppFonts() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  Future<void> family(String name, String file) async {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    final loader = FontLoader(name)..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();
  }

  await family(AppFonts.display, 'LilitaOne-Regular.ttf');
  await family(AppFonts.body, 'Baloo2-Variable.ttf');
  await family(AppFonts.bangla, 'BalooDa2-Variable.ttf');
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(icons.readAsBytesSync()))));
      await loader.load();
    }
  }
}

/// The reference phone of the design: 390 × 844 pt at 3×, with a notch (47 pt)
/// and a home indicator (34 pt).
void usePhoneView(WidgetTester tester, {Size size = const Size(390, 844), double pixelRatio = 3}) {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  final padding = FakeViewPadding(top: 47 * pixelRatio, bottom: 34 * pixelRatio);
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
}

/// The boundary [capture] renders; the harnesses wrap the app in it.
final GlobalKey captureKey = GlobalKey();

/// Writes the current frame of the harness' root boundary to
/// build/screens/[name].png at [pixelRatio] (1 = 390 × 844 px, exactly the size
/// of the artboard renders; use 2–3 to look at details).
Future<File> capture(WidgetTester tester, String name, {double pixelRatio = 1}) async {
  final boundary = captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final file = File('build/screens/$name.png')..parent.createSync(recursive: true);
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  return file;
}
