// The kit gallery is the showcase the design is checked against: every page must
// build, switch from the header strip and keep animating without exceptions.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/features/dev/kit_gallery_screen.dart';

import '../../helpers/kit_harness.dart';

void main() {
  setUpAll(loadKitFonts);

  testWidgets('every gallery page builds from the section strip', (tester) async {
    useSurface(tester, height: 844, pixelRatio: 1);
    await tester.pumpWidget(kitApp(const KitGalleryScreen()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    for (final section in GallerySection.values) {
      final chip = find.text(section.title).first;
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(tester.takeException(), isNull, reason: section.title);
    }
  });

  testWidgets('the gallery opens on any section and works with Reduce Motion', (tester) async {
    useSurface(tester, height: 844, pixelRatio: 1);
    for (final section in GallerySection.values) {
      await tester.pumpWidget(kitApp(KitGalleryScreen(initial: section), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: section.title);
    }
  });
}
