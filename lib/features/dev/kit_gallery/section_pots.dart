// Gallery › Pots & icons: the Mela pots (clay, silver, gold, event) with their
// ready shake and crack-open, and every vector glyph of the game in one grid.

import 'package:flutter/widgets.dart';
import '../../../core/art/engine_geometry.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class PotsSection extends StatefulWidget {
  const PotsSection({super.key});

  @override
  State<PotsSection> createState() => _PotsSectionState();
}

class _PotsSectionState extends State<PotsSection> {
  final MelaPotController _pot = MelaPotController();

  static const _icons = <(String, Glyph)>[
    ('coin', LmIcons.coin),
    ('gem', LmIcons.gem),
    ('star', LmIcons.star),
    ('gear', LmIcons.gear),
    ('chart', LmIcons.chart),
    ('lock', LmIcons.lock),
    ('tick', LmIcons.tick),
    ('check', LmIcons.check),
    ('close', LmIcons.close),
    ('back', LmIcons.back),
    ('forward', LmIcons.forward),
    ('plus', LmIcons.plus),
    ('play', LmIcons.play),
    ('bulb', LmIcons.bulb),
    ('menu', LmIcons.menu),
    ('trophy', LmIcons.trophy),
    ('sparkle', LmIcons.sparkle),
    ('shield', LmIcons.shield),
    ('freeze', LmIcons.freeze),
    ('swap', LmIcons.swap),
    ('hop', LmIcons.hop),
    ('reroll', LmIcons.reroll),
    ('double', LmIcons.double2),
    ('lightning', LmIcons.lightning),
    ('chevrons', LmIcons.chevrons),
    ('chest', LmIcons.chest),
    ('stall coins', LmGlyphs.stallCoins),
    ('stall wheel', LmGlyphs.stallWheel),
    ('stall gift', LmGlyphs.stallGift),
    ('stall missions', LmGlyphs.stallMissions),
    ('mode pass', LmGlyphs.modePass),
    ('mode wifi', LmGlyphs.modeWifi),
    ('mode mayhem', LmGlyphs.modeMayhem),
    ('mode puzzle', LmGlyphs.modePuzzle),
    ('dock home', LmGlyphs.dockHome),
    ('dock friends', LmGlyphs.dockFriends),
    ('dock collection', LmGlyphs.dockCollection),
    ('dock road', LmGlyphs.dockRoad),
    ('dock events', LmGlyphs.dockEvents),
    ('tab dice', LmGlyphs.tabDice),
    ('tab pieces', LmGlyphs.tabPieces),
    ('tab boards', LmGlyphs.tabBoards),
    ('coin stack', LmGlyphs.coinStack),
    ('gem cluster', LmGlyphs.gemCluster),
    ('pot clay', LmGlyphs.potClay),
    ('rule classic', LmGlyphs.ruleClassic),
    ('rule quick', LmGlyphs.ruleQuick),
    ('rule mayhem', LmGlyphs.ruleMayhem),
    ('rule cup', LmGlyphs.ruleCup),
    ('tray arrow', LmIcons.trayArrow),
  ];

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(
          title: 'Mela pots',
          note: 'Clay 3 h, silver 8 h, gold 12 h, event pot. The cloth colour shows the state: red ready, blue waiting, purple big.',
          child: Samples(spacing: 14, runSpacing: 22, children: [
            Captioned('clay · ready', const MelaPot(ready: true, size: 64)),
            Captioned('clay · waiting', const MelaPot(cloth: Color(0xFF2F95F2), size: 64)),
            Captioned('silver', const MelaPot(kind: PotKind.silver, cloth: Color(0xFF2F95F2), size: 64)),
            Captioned('gold', const MelaPot(kind: PotKind.gold, cloth: Color(0xFF8B55F0), size: 64)),
            Captioned('mela', const MelaPot(kind: PotKind.mela, cloth: Color(0xFFFFC61F), ready: true, size: 64)),
            const Captioned('empty', EmptyPotSlot()),
          ]),
        ),
        GalleryBlock(
          title: 'Crack open',
          child: Row(
            children: [
              SizedBox(width: 120, height: 110, child: Center(child: MelaPot(controller: _pot, ready: true, size: 80))),
              const SizedBox(width: 12),
              Column(
                children: [
                  GlossButton(onTap: () => _pot.open(), label: 'Open', kind: GlossKind.gold, size: GlossSize.s, width: 90),
                  const SizedBox(height: 10),
                  GlossButton(onTap: () => setState(() => _pot.reset()), label: 'Reset', kind: GlossKind.blue, size: GlossSize.s, width: 90),
                ],
              ),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Standing pawns (illustration)',
          child: Row(children: [for (final s in Seat.values) Padding(padding: const EdgeInsets.only(right: 12), child: StandingPawn(seat: s, height: 40))]),
        ),
        GalleryBlock(
          title: 'Glyphs',
          child: Samples(spacing: 10, runSpacing: 14, children: [
            for (final i in _icons)
              SizedBox(
                width: 64,
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: const Color(0xFF2D7AD6), borderRadius: BorderRadius.circular(8)),
                      alignment: Alignment.center,
                      child: LmIcon(i.$2, size: 32),
                    ),
                    const SizedBox(height: 3),
                    Text(i.$1, textAlign: TextAlign.center, style: LmText.bodyAt(9.5, weight: FontWeight.w700, color: LmColors.textLabel, height: 1.1)),
                  ],
                ),
              ),
          ]),
        ),
      ],
    );
  }
}
