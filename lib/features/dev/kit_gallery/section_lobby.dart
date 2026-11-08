// Gallery › Lobby: the awning and bunting, stall and mode tiles, the XP avatar,
// the round dock and the backdrops.

import 'package:flutter/widgets.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/avatar_choice.dart';
import 'gallery_common.dart';

class LobbySection extends StatefulWidget {
  const LobbySection({super.key});

  @override
  State<LobbySection> createState() => _LobbySectionState();
}

class _LobbySectionState extends State<LobbySection> {
  int _dock = 0;

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(
          title: 'Awning & bunting',
          child: Column(
            children: [
              const ClipRect(child: Awning()),
              const SizedBox(height: 12),
              const ClipRect(child: Awning(bulbs: true)),
              const SizedBox(height: 4),
              SizedBox(height: 90, child: ClipRect(child: Bunting(height: 90, sag: 28, radius: 5, top: 10))),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Stall tiles',
          child: Row(
            children: [
              Expanded(child: StallTile(colors: LmColors.stallCoins, icon: LmGlyphs.stallCoins, label: 'Free coins', sub: '4 ready', badge: const CountBadge.fresh(4), semanticLabel: 'Free coins', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: StallTile(colors: LmColors.stallWheel, icon: LmGlyphs.stallWheel, label: 'Lucky wheel', sub: 'Free spin', badge: const CountBadge.alert(), motion: IdleKind.spin, semanticLabel: 'Lucky wheel', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: StallTile(colors: LmColors.stallGift, icon: LmGlyphs.stallGift, label: 'Daily gift', sub: 'Day 4', badge: const CountBadge.alert(), motion: IdleKind.wiggle, semanticLabel: 'Daily gift', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: StallTile(colors: LmColors.stallMissions, icon: LmGlyphs.stallMissions, label: 'Missions', sub: '2 to claim', badge: const CountBadge(count: 2), semanticLabel: 'Missions', onTap: () {})),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Mode tiles',
          child: Column(
            children: [
              Row(children: [
                Expanded(child: ModeTile(colors: LmColors.modePass, title: 'Pass & Play', sub: 'Friends on one phone', art: LmGlyphs.modePass, semanticLabel: 'Pass and play', onTap: () {})),
                const SizedBox(width: 10),
                Expanded(child: ModeTile(colors: LmColors.modeWifi, title: 'Wi-Fi Party', sub: 'Nearby · no internet', art: LmGlyphs.modeWifi, semanticLabel: 'Wi-Fi party', onTap: () {})),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: ModeTile(colors: LmColors.modeMayhem, title: 'Mela Mayhem', sub: 'Power cards & chaos', art: LmGlyphs.modeMayhem, tag: 'NEW', motion: IdleKind.wiggle, semanticLabel: 'Mela Mayhem', onTap: () {})),
                const SizedBox(width: 10),
                Expanded(child: ModeTile(colors: LmColors.modePuzzle, title: 'Daily Puzzle', sub: 'One smart move a day', art: LmGlyphs.modePuzzle, tag: '5-day streak', motion: IdleKind.float, semanticLabel: 'Daily puzzle', onTap: () {})),
              ]),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Header parts',
          child: Row(
            children: [
              const XpAvatar(choice: AvatarChoice(animal: 'tiger'), progress: .4, level: 12, semanticLabel: 'Profile'),
              const SizedBox(width: 18),
              PlankPill(icon: LmIcons.gem, amount: '86', onTap: () {}, semanticLabel: 'Gems'),
              const SizedBox(width: 12),
              PlankPill(icon: LmIcons.coin, amount: '12.4K', onTap: () {}, semanticLabel: 'Coins'),
              const SizedBox(width: 18),
              const GearButton(),
            ],
          ),
        ),
        GalleryBlock(
          title: 'Round dock',
          child: RoundDock(
            index: _dock,
            onChanged: (i) => setState(() => _dock = i),
            items: const [
              DockItem(icon: LmGlyphs.dockHome, label: 'Home'),
              DockItem(icon: LmGlyphs.dockFriends, label: 'Friends'),
              DockItem(icon: LmGlyphs.dockCollection, label: 'Collection', badge: 3),
              DockItem(icon: LmGlyphs.dockRoad, label: 'Road'),
              DockItem(icon: LmGlyphs.dockEvents, label: 'Events', alert: true),
            ],
          ),
        ),
      ],
    );
  }
}
