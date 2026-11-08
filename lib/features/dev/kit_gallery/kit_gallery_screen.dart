// The kit gallery: a scrollable showcase of every design-kit widget and art piece
// of Ludo Mela — all skins, all states, animations running — for developers and
// for design-fidelity captures (test/core/widgets/kit_capture_test.dart).
//
// Why: the artboards are the spec, and this screen is the quickest way to put
// the Flutter kit next to them (and to check Reduce Motion, text scale and dark
// corners) without playing through the game. Development only: English text,
// not translated, and not reachable from the shipped app unless a debug route
// is registered for it (see KitGalleryScreen.route).
//
// Pages (chips along the top): Basics, Surfaces, Lobby, Backdrops, Avatars, Board,
// Pieces, Dice, Pots & icons, and two playable mocks of the match and lobby screens.

import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/widgets.dart';
import 'collection_mock.dart';
import 'gallery_common.dart';
import 'lobby_mock.dart';
import 'match_mock.dart';
import 'section_avatars.dart';
import 'section_backdrops.dart';
import 'section_basics.dart';
import 'section_board.dart';
import 'section_dice.dart';
import 'section_lobby.dart';
import 'section_pieces.dart';
import 'section_pots.dart';
import 'section_surfaces.dart';

export 'gallery_common.dart' show GallerySection;

/// The page for [s] (also used by the capture tests).
Widget kitGalleryPage(GallerySection s) => switch (s) {
      GallerySection.basics => const BasicsSection(),
      GallerySection.surfaces => const SurfacesSection(),
      GallerySection.lobby => const LobbySection(),
      GallerySection.backdrops => const BackdropsSection(),
      GallerySection.avatars => const AvatarsSection(),
      GallerySection.board => const BoardSection(),
      GallerySection.pieces => const PiecesSection(),
      GallerySection.dice => const DiceSection(),
      GallerySection.pots => const PotsSection(),
      GallerySection.match => const _Mock(child: MatchMock()),
      GallerySection.lobbyMock => const _Mock(child: LobbyMock()),
      GallerySection.collectionMock => const _Mock(child: CollectionMock()),
    };

class KitGalleryScreen extends StatefulWidget {
  const KitGalleryScreen({super.key, this.initial = GallerySection.basics});

  /// The suggested debug path for the router (`/dev/kit`).
  static const route = '/dev/kit';

  final GallerySection initial;

  @override
  State<KitGalleryScreen> createState() => _KitGalleryScreenState();
}

class _KitGalleryScreenState extends State<KitGalleryScreen> {
  late GallerySection _section = widget.initial;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return ColoredBox(
      color: LmColors.deep,
      child: Stack(
        children: [
          const Positioned.fill(child: RoyalBackdrop(spec: BackdropSpec.screen)),
          SafeArea(
            child: ToastHost(
              padding: const EdgeInsets.only(top: 120),
              child: Column(
                children: [
                  ScreenHeader(title: 'Kit gallery', onBack: canPop ? () => Navigator.of(context).maybePop() : null),
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final s in GallerySection.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GlossButton(
                              onTap: () => setState(() => _section = s),
                              label: s.title,
                              kind: s == _section ? GlossKind.gold : GlossKind.navy,
                              size: GlossSize.s,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: KeyedSubtree(key: ValueKey(_section), child: kitGalleryPage(_section))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A 390 × 844 mock scaled down to fit the page width.
class _Mock extends StatelessWidget {
  const _Mock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: ClipRRect(borderRadius: BorderRadius.circular(28), child: child),
        ),
      );
}
