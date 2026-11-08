// A static mock of the lobby (Main.dc.html "Mela ground") built only from the
// kit: night sky, awning, header with the XP ring and plank wallets, four stall
// tiles, the PLAY tile with its tilted mini board, the 2 × 2 mode tiles, the pot
// shelf and the round dock.
//
// Why it exists: the capture test compares it with Main.png, and the lobby builder
// has a worked example of every kit widget in its real place. Development only.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../../../core/art/engine_geometry.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import '../../../domain/avatar_choice.dart';

class LobbyMock extends StatefulWidget {
  const LobbyMock({super.key});

  @override
  State<LobbyMock> createState() => _LobbyMockState();
}

class _LobbyMockState extends State<LobbyMock> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 844,
      child: Stack(
        children: [
          const Positioned.fill(child: NightSkyBackdrop()),
          Column(
            children: [
              const Awning(),
              _header(),
              _stalls(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [_play(), _changeMode(), _modes(), _pots()],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 20),
                child: RoundDock(
                  index: _tab,
                  onChanged: (i) => setState(() => _tab = i),
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
          ),
        ],
      ),
    );
  }

  Widget _header() => SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 8, 0),
          child: Row(
            children: [
              const XpAvatar(choice: AvatarChoice(), progress: .75, level: 7, semanticLabel: 'Your profile, level 7, 340 of 450 XP'),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OutlinedText('Player', size: 16),
                    const SizedBox(height: 2),
                    Text('Level 7 · 340/450 XP', style: LmText.bodyAt(10.5, weight: FontWeight.w800, color: const Color(0xFFCFE0FF)), maxLines: 1),
                  ],
                ),
              ),
              PlankPill(icon: LmIcons.gem, amount: '86', onTap: () {}, semanticLabel: '86 gems. Get more'),
              const SizedBox(width: 10),
              PlankPill(icon: LmIcons.coin, amount: '12.4K', onTap: () {}, semanticLabel: '12,450 coins. Get more'),
              const SizedBox(width: 6),
              GearButton(onTap: () {}),
            ],
          ),
        ),
      );

  Widget _stalls() => Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: Entrance(
                  index: i,
                  rise: 16,
                  child: [
                    StallTile(colors: LmColors.stallCoins, icon: LmGlyphs.stallCoins, label: 'Free coins', sub: '4 ready', badge: const CountBadge.fresh(4), semanticLabel: 'Free coins and gems, 4 ready', onTap: () {}),
                    StallTile(colors: LmColors.stallWheel, icon: LmGlyphs.stallWheel, label: 'Lucky wheel', sub: 'Free spin', badge: const CountBadge.alert(), motion: IdleKind.spin, semanticLabel: 'Lucky wheel, free spin ready', onTap: () {}),
                    StallTile(colors: LmColors.stallGift, icon: LmGlyphs.stallGift, label: 'Daily gift', sub: 'Day 4', badge: const CountBadge.alert(), motion: IdleKind.wiggle, semanticLabel: 'Daily gift, day 4 ready', onTap: () {}),
                    StallTile(colors: LmColors.stallMissions, icon: LmGlyphs.stallMissions, label: 'Missions', sub: '2 to claim', badge: const CountBadge(count: 2), semanticLabel: 'Daily missions, 2 rewards to claim', onTap: () {}),
                  ][i],
                ),
              ),
            ],
          ],
        ),
      );

  Widget _play() => Pressable(
        onTap: () {},
        semanticLabel: 'Play vs computer: Classic, 4 players, entry 500 coins',
        child: MelaTile.play(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              PositionedDirectional(
                start: 16,
                top: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const LmIcon(_robot, size: 22),
                        const SizedBox(width: 6),
                        Text('VS COMPUTER', style: LmText.bodyAt(12, weight: FontWeight.w800, color: LmColors.inkOnGold).copyWith(letterSpacing: .6)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const OutlinedText('PLAY', size: 34, height: 1.0),
                    const SizedBox(height: 3),
                    Text('Lantern Bazaar · win 2,000', style: LmText.bodyAt(12, weight: FontWeight.w800, color: LmColors.inkOnGold)),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 14,
                bottom: 12,
                child: Row(
                  children: [
                    _chip(child: Text('Classic', style: LmText.plain(12.5, color: LmColors.xpText, shadows: const []))),
                    const SizedBox(width: 6),
                    _chip(
                      child: Row(
                        children: [
                          for (final s in Seat.values) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: LmColors.seat(s).main, shape: BoxShape.circle, border: Border.all(color: LmColors.white, width: 1)),
                            ),
                            const SizedBox(width: 2),
                          ],
                          const SizedBox(width: 2),
                          Text('4 players', style: LmText.plain(12.5, shadows: const [])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(end: 6, top: 10, width: 150, height: 130, child: IdleMotion(kind: IdleKind.float, child: _tiltedBoard())),
              PositionedDirectional(
                end: 12,
                bottom: 10,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(color: LmColors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0xFF9A4A00), offset: Offset(0, 3))]),
                  child: const Center(child: LmIcon(Glyph([GlyphPart('M8 5l11 7-11 7z', fill: Color(0xFFF07800))]), size: 22)),
                ),
              ),
            ],
          ),
        ),
      );

  static const _robot = Glyph([
    GlyphPart('M5.5 7h13a3 3 0 0 1 3 3v8a2 2 0 0 1-2 2h-15a2 2 0 0 1-2-2v-8a3 3 0 0 1 3-3z', fill: Color(0xFFFFFFFF), stroke: Color(0xFF0A2A6B), strokeWidth: 1.8),
    GlyphPart('M12 3v4', stroke: Color(0xFF0A2A6B), strokeWidth: 1.8),
    GlyphPart('M12 1.4a1.6 1.6 0 1 0 .01 0z', fill: Color(0xFFE8322B)),
    GlyphPart('M7.4 13a1.6 1.6 0 1 0 .01 0zM13.4 13a1.6 1.6 0 1 0 .01 0z', fill: Color(0xFF0A2A6B)),
    GlyphPart('M9.5 16.8h5', stroke: Color(0xFF0A2A6B), strokeWidth: 1.6),
  ]);

  Widget _chip({required Widget child}) => Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: const Color(0xD95A2E00), borderRadius: BorderRadius.circular(13)),
        alignment: Alignment.center,
        child: child,
      );

  /// The board floating in perspective with four standing pawns (150 × 130 box).
  Widget _tiltedBoard() => Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 20,
            top: 8,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, -1 / 360)
                ..rotateX(50 * math.pi / 180)
                ..rotateZ(-16 * math.pi / 180),
              child: BoardView.mini(skin: BoardSkins.melaWood, width: 108),
            ),
          ),
          const Positioned(left: 34, top: 20, child: StandingPawn(seat: Seat.green, height: 27)),
          const Positioned(left: 96, top: 12, child: StandingPawn(seat: Seat.yellow, height: 27)),
          const Positioned(left: 40, top: 74, child: StandingPawn(seat: Seat.red, height: 27)),
          const Positioned(left: 100, top: 66, child: StandingPawn(seat: Seat.blue, height: 27)),
        ],
      );

  Widget _changeMode() => Transform.translate(offset: const Offset(0, -4), child: _changeModeChip());

  Widget _changeModeChip() => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0x8C061646),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x4DFFFFFF), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LmIcon(Glyph(box: 24, [GlyphPart('M4 7h10M18 7h2M4 17h4M12 17h8M16 4.8a2.2 2.2 0 1 0 .01 0zM10 14.8a2.2 2.2 0 1 0 .01 0z', stroke: Color(0xFFFFE27A), strokeWidth: 2.8)]), size: 15),
            const SizedBox(width: 6),
            Text('Change mode, players or level', style: LmText.plain(12.5, shadows: const [])),
          ],
        ),
      );

  Widget _modes() => Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Entrance(index: 4, rise: 16, child: ModeTile(colors: LmColors.modePass, title: 'Pass & Play', sub: 'Friends on one phone', art: LmGlyphs.modePass, semanticLabel: 'Pass and play', onTap: () {})),
                const SizedBox(height: 10),
                Entrance(index: 6, rise: 16, child: ModeTile(colors: LmColors.modeMayhem, title: 'Mela Mayhem', sub: 'Power cards & chaos', art: LmGlyphs.modeMayhem, tag: 'NEW', motion: IdleKind.wiggle, semanticLabel: 'Mela Mayhem', onTap: () {})),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                Entrance(index: 5, rise: 16, child: ModeTile(colors: LmColors.modeWifi, title: 'Wi-Fi Party', sub: 'Nearby · no internet', art: LmGlyphs.modeWifi, semanticLabel: 'Wi-Fi party', onTap: () {})),
                const SizedBox(height: 10),
                Entrance(index: 7, rise: 16, child: ModeTile(colors: LmColors.modePuzzle, title: 'Daily Puzzle', sub: 'One smart move a day', art: LmGlyphs.modePuzzle, tag: '5-day streak', motion: IdleKind.float, semanticLabel: 'Daily puzzle', onTap: () {})),
              ],
            ),
          ),
        ],
      );

  Widget _pots() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const OutlinedText('Mela pots', size: 15),
                Text('Win a match to earn one', style: LmText.bodyAt(11, weight: FontWeight.w800, color: const Color(0xFFCFE0FF))),
              ],
            ),
          ),
          SizedBox(
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 4,
                  height: 13,
                  child: LmBox(
                    radius: 5,
                    gradient: const LmGradient([LmColors.plankHi, LmColors.plankMid, LmColors.plankLo], stops: [0, .6, 1]),
                    shadows: const [LmShadow.rim(LmColors.plankRim, 1.5), LmShadow(Color(0x4DFFFFFF), dy: 2, inset: true), LmShadow(LmColors.plankLip, dy: 3)],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 17,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _pot(PotKind.clay, const Color(0xFFE8322B), 'Tap to open', ready: true),
                      _pot(PotKind.clay, const Color(0xFF2F95F2), '2h 59m'),
                      _pot(PotKind.clay, const Color(0xFF8B55F0), '8h 00m'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _pot(PotKind kind, Color cloth, String tag, {bool ready = false}) => Expanded(
        child: SizedBox(
          height: 62,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(bottom: 0, child: MelaPot(kind: kind, cloth: cloth, ready: ready, size: 48, semanticLabel: tag)),
              Positioned(
                bottom: -16,
                child: Container(
                  height: 17,
                  constraints: const BoxConstraints(minWidth: 62),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(color: ready ? LmColors.badgeGreen : const Color(0xFF0A2464), borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text(tag, maxLines: 1, style: LmText.plain(11, color: ready ? LmColors.white : const Color(0xFFFFE7A8), height: 1.0, shadows: const [])),
                ),
              ),
            ],
          ),
        ),
      );
}
