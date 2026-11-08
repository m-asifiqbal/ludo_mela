// Renders the kit to build/screens/*.png at 390 logical width with the real
// bundled fonts, so each image can be opened and compared side by side with the
// artboard renders in design/tools/shots/*.png (Match.png, Main.png, …).
//
// Run: flutter test --no-pub test/core/widgets/kit_capture_test.dart
// Output: build/screens/kit_*.png. These tests only assert that rendering
// completes; the comparison is by eye (and by the numeric checks in the art /
// widget tests).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/widgets/widgets.dart';
import 'package:ludo_mela/features/dev/kit_gallery/collection_mock.dart';
import 'package:ludo_mela/features/dev/kit_gallery/kit_gallery_screen.dart';
import 'package:ludo_mela/features/dev/kit_gallery/lobby_mock.dart';
import 'package:ludo_mela/features/dev/kit_gallery/match_mock.dart';

import '../../helpers/kit_harness.dart';

void main() {
  setUpAll(loadKitFonts);

  testWidgets('match screen, waiting for your roll (vs Match.png)', (tester) async {
    await captureWidget(tester, 'kit_match', const MatchMock(), height: 844, settle: const Duration(milliseconds: 1200));
  });

  testWidgets('match screen, after a roll: movable pieces get rings', (tester) async {
    await captureWidget(tester, 'kit_match_pick', const MatchMock(initialRoll: 5, showTimer: true), height: 844, settle: const Duration(milliseconds: 1200));
  });

  testWidgets('mayhem board in the match frame', (tester) async {
    await captureWidget(tester, 'kit_match_mayhem', const MatchMock(mayhem: true, initialRoll: 3), height: 844, settle: const Duration(milliseconds: 1200));
  });

  testWidgets('lobby (vs Main.png)', (tester) async {
    await captureWidget(tester, 'kit_lobby', const LobbyMock(), height: 844, settle: const Duration(milliseconds: 1500));
  });

  testWidgets('collection dice tab (vs Collection.png)', (tester) async {
    await captureWidget(tester, 'kit_collection', const CollectionMock(), height: 844, settle: const Duration(milliseconds: 1500));
  });

  // Every gallery page, tall enough to show all of it (compare with the boards).
  for (final section in GallerySection.values.where((s) => !const {GallerySection.match, GallerySection.lobbyMock, GallerySection.collectionMock}.contains(s))) {
    testWidgets('gallery page: ${section.title}', (tester) async {
      await captureWidget(
        tester,
        'kit_gallery_${section.name}',
        Stack(children: [const Positioned.fill(child: RoyalBackdrop(spec: BackdropSpec.screen)), kitGalleryPage(section)]),
        height: 3000,
        pixelRatio: 1.5,
        settle: const Duration(milliseconds: 1500),
      );
    });
  }
}
