// Test harness for the design kit: loads the bundled fonts, wraps widgets in the
// app theme + a ProviderScope, and renders a widget to build/screens/<name>.png
// at a logical width of 390 pt so it can be compared side by side with the
// artboard renders in design/tools/shots/*.png.
//
// Why load fonts by hand: flutter_test only ships the "Ahem" test font, so text
// would render as blocks. The real Lilita One / Baloo 2 / Baloo Da 2 files from
// assets/fonts are registered under the same family names AppFonts uses.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/theme/app_theme.dart';
import 'package:ludo_mela/core/theme/fonts.dart';

import 'fake_feedback.dart';

/// Registers Lilita One, Baloo 2 and Baloo Da 2 from assets/fonts (call once in setUpAll).
Future<void> loadKitFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    }
    await loader.load();
  }

  await family(AppFonts.display, ['LilitaOne-Regular.ttf']);
  await family(AppFonts.body, ['Baloo2-Variable.ttf']);
  await family(AppFonts.bangla, ['BalooDa2-Variable.ttf']);
}

/// The widget under test inside the app theme, a ProviderScope and a Material.
Widget kitApp(Widget child, {List<Override> overrides = const [], TextScaler? textScaler, bool disableAnimations = false}) {
  return ProviderScope(
    overrides: [fakeFeedbackOverride, ...overrides],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler ?? TextScaler.noScaling,
          disableAnimations: disableAnimations,
        ),
        child: c!,
      ),
      home: Material(type: MaterialType.transparency, child: child),
    ),
  );
}

/// Sets a 390 × [height] logical surface at [pixelRatio].
void useSurface(WidgetTester tester, {double height = 844, double pixelRatio = 2, double width = 390}) {
  tester.view.physicalSize = Size(width * pixelRatio, height * pixelRatio);
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps [child] on a [width] × [height] surface, lets [settle] elapse (for
/// entrance animations), and writes build/screens/[name].png.
Future<File> captureWidget(
  WidgetTester tester,
  String name,
  Widget child, {
  double width = 390,
  double height = 844,
  double pixelRatio = 2,
  Duration settle = const Duration(milliseconds: 900),
  Color background = const Color(0xFF1250C2),
  List<Override> overrides = const [],
  Future<void> Function(WidgetTester tester)? beforeCapture,
}) async {
  useSurface(tester, height: height, pixelRatio: pixelRatio, width: width);
  final key = GlobalKey();
  await tester.pumpWidget(
    kitApp(
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: width, height: height, child: ColoredBox(color: background, child: child)),
        ),
      ),
      overrides: overrides,
    ),
  );
  await tester.pump();
  await tester.pump(settle);
  if (beforeCapture != null) await beforeCapture(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  final file = File('build/screens/$name.png');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  return file;
}

/// A rendered widget as raw pixels, with logical-point lookups.
class RenderedPixels {
  RenderedPixels(this.image, this.rgba, this.pixelRatio);

  final ui.Image image;
  final ByteData rgba;
  final double pixelRatio;

  /// The colour at the logical point ([x], [y]).
  Color at(double x, double y) {
    final px = (x * pixelRatio).round().clamp(0, image.width - 1);
    final py = (y * pixelRatio).round().clamp(0, image.height - 1);
    final i = (py * image.width + px) * 4;
    return Color.fromARGB(rgba.getUint8(i + 3), rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2));
  }
}

/// Pumps [child] at [width] × [height] and returns its pixels (for colour
/// assertions). The widget is wrapped in the app theme and a Material.
Future<RenderedPixels> renderPixels(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 844,
  double pixelRatio = 1,
  Duration settle = const Duration(milliseconds: 100),
  Color background = const Color(0x00000000),
  bool disableAnimations = false,
}) async {
  useSurface(tester, height: height, pixelRatio: pixelRatio, width: width);
  final key = GlobalKey();
  await tester.pumpWidget(
    kitApp(
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: SizedBox(width: width, height: height, child: ColoredBox(color: background, child: child)),
        ),
      ),
      disableAnimations: disableAnimations,
    ),
  );
  await tester.pump();
  await tester.pump(settle);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final out = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return (image, data!);
  });
  return RenderedPixels(out!.$1, out.$2, pixelRatio);
}
