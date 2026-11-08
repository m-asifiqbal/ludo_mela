// Full-size backdrop captures (390 × 844) to compare with Wheel.png, Win.png and
// Splash.png: build/screens/kit_bg_*.png.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/widgets/widgets.dart';

import '../../helpers/kit_harness.dart';

void main() {
  setUpAll(loadKitFonts);

  for (final entry in {
    'wheel': const PurpleRaysBackdrop(),
    'win': const SunRaysBackdrop(),
    'splash': const SunRaysBackdrop(spec: BackdropSpec.splash),
    'felt': const FeltBackdrop(),
    'night': const NightSkyBackdrop(),
    'royal': const RoyalBackdrop(),
  }.entries) {
    testWidgets('backdrop ${entry.key}', (tester) async {
      await captureWidget(tester, 'kit_bg_${entry.key}', SizedBox.expand(child: entry.value), height: 844, pixelRatio: 1);
    });
  }
}
