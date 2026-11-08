// A static mock of the Collection screen's dice tab (Collection.dc.html): awning
// header with the wallet pills, the Dice | Pieces | Boards tabs, the rarity
// legend and the first rows of cards (isometric dice, stat bars, Use / Upgrade /
// gem-price buttons, shard progress).
//
// Why it exists: the capture test compares it with Collection.png, proving
// RarityFrame, TabPills, StatBar, DiceIcon, badges and the glossy buttons compose
// into the real screen. Development only: English text.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';

class CollectionMock extends StatelessWidget {
  const CollectionMock({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 390,
      height: 844,
      child: Stack(
        children: [
          const Positioned.fill(child: RoyalBackdrop(spec: BackdropSpec.royal)),
          Column(
            children: [
              AwningHeader(
                title: 'Collection',
                actions: [
                  GlossIconButton(icon: LmIcons.info, semanticLabel: 'How the collection works', onTap: () {}, kind: GlossKind.navy, size: 36, radius: 18),
                  const CurrencyPill(icon: LmIcons.gem, amount: '86'),
                  const CurrencyPill(icon: LmIcons.coin, amount: '12,450'),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TabPills(
                  height: 46,
                  tabs: const [
                    TabPillItem(label: 'Dice', icon: LmGlyphs.tabDice, badge: 2),
                    TabPillItem(label: 'Pieces', icon: LmGlyphs.tabPieces, badge: 1),
                    TabPillItem(label: 'Boards', icon: LmGlyphs.tabBoards),
                  ],
                  index: 0,
                  onChanged: (_) {},
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    for (final r in LmRarity.values) ...[
                      if (r != LmRarity.standard) const SizedBox(width: 6),
                      RarityChip(rarity: r),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Card(skin: DiceSkins.classic, level: 3, stats: const [(2, '2/5'), (2, '2/5'), (0, '—')], button: _use())),
                          const SizedBox(width: 12),
                          Expanded(child: _Card(skin: DiceSkins.rubyJelly, using: true, level: 2, stats: const [(3, '3/5'), (3, '3/5'), (1, '+5%')], button: _upgrade())),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _Card(skin: DiceSkins.oceanGlass, stats: const [(3, '3/5'), (4, '4/5'), (1, '+5%')], shards: (6, 33))),
                          const SizedBox(width: 12),
                          Expanded(child: _Card(skin: DiceSkins.goldMohur, stats: const [(4, '4/5'), (4, '4/5'), (2, '+10%')], button: _gems())),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 22),
                child: RoundDock(
                  height: 64,
                  index: 2,
                  onChanged: (_) {},
                  items: const [
                    DockItem(icon: LmGlyphs.dockHome, label: 'Home'),
                    DockItem(icon: LmGlyphs.dockFriends, label: 'Friends'),
                    DockItem(icon: LmGlyphs.dockCollection, label: 'Collection'),
                    DockItem(icon: LmGlyphs.dockRoad, label: 'Road'),
                    DockItem(icon: LmGlyphs.dockEvents, label: 'Events'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _use() => GlossButton(onTap: () {}, label: 'Use', kind: GlossKind.blue, size: GlossSize.s, expand: true);

  static Widget _upgrade() => GlossButton(onTap: () {}, label: 'Upgrade 1,500', kind: GlossKind.green, size: GlossSize.s, icon: LmIcons.coin, expand: true);

  static Widget _gems() => GlossButton(onTap: () {}, label: '140', kind: GlossKind.gold, size: GlossSize.s, icon: LmIcons.gem, expand: true);
}

class _Card extends StatelessWidget {
  const _Card({required this.skin, required this.stats, this.button, this.using = false, this.level, this.shards});

  final DiceSkin skin;

  /// (filled out of 5 / XP step, value text) for Roll fx, Bounce, XP boost.
  final List<(int, String)> stats;
  final Widget? button;
  final bool using;
  final int? level;
  final (int, int)? shards;

  static const _labels = ['Roll fx', 'Bounce', 'XP boost'];

  @override
  Widget build(BuildContext context) {
    return RarityFrame(
      rarity: skin.rarity,
      onTap: () {},
      semanticLabel: 'Try on ${skin.name}',
      child: Column(
        children: [
          OutlinedText(skin.name, size: 14.5),
          Text(skin.rarity.label.toUpperCase(), style: LmText.plain(10.5, color: const Color(0xD9FFFFFF), shadows: const [], height: 1.2).copyWith(letterSpacing: .6)),
          Container(
            width: 132,
            height: 96,
            margin: const EdgeInsets.fromLTRB(0, 4, 0, 2),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Positioned.fill(child: _Glow()),
                Positioned(left: 23, top: 4, child: IdleMotion(kind: IdleKind.float, child: DiceIcon(skin: skin, size: 86))),
                if (using)
                  Positioned(
                    left: -8,
                    top: -2,
                    child: Transform.rotate(
                      angle: -8 * math.pi / 180,
                      child: Container(
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(color: LmColors.badgeGreen, borderRadius: BorderRadius.circular(5), boxShadow: const [BoxShadow(color: Color(0xFF1D6B0F), offset: Offset(0, 2))]),
                        alignment: Alignment.center,
                        child: Text('USING', style: LmText.outlined(11, height: 1.0)),
                      ),
                    ),
                  ),
                if (level != null)
                  Positioned(
                    right: -6,
                    top: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF5CC2FF), Color(0xFF1C72DA)]),
                        boxShadow: [BoxShadow(color: Color(0xFFFFFFFF), spreadRadius: 2), BoxShadow(color: Color(0x40000000), offset: Offset(0, 2), spreadRadius: 2)],
                      ),
                      alignment: Alignment.center,
                      child: Text('Lv$level', style: LmText.outlined(11, height: 1.0)),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            StatBar(
              label: _labels[i],
              value: i == 2 ? stats[i].$1 * .33 : stats[i].$1 / 5,
              valueText: stats[i].$2,
              fill: i == 2 ? BarFill.green : BarFill.stat,
            ),
          ],
          const SizedBox(height: 8),
          if (shards != null)
            SizedBox(
              height: 36,
              child: Row(
                children: [
                  const LmIcon(_shardGem, size: 22),
                  const SizedBox(width: 4),
                  Expanded(child: ProgressBar(value: shards!.$1 / shards!.$2, fill: BarFill.purple, height: 20, label: '${shards!.$1}/${shards!.$2}')),
                ],
              ),
            ),
          if (button != null) SizedBox(width: double.infinity, child: button),
        ],
      ),
    );
  }

  static const _shardGem = Glyph([GlyphPart('M12 2l7 7-7 13-7-13z', fill: Color(0xFFC77DFF), stroke: Color(0xFFFFFFFF), strokeWidth: 1.6)]);
}

/// `radial-gradient(circle at 50% 45%, rgba(255,255,255,.35), transparent 70%)` behind the art.
class _Glow extends StatelessWidget {
  const _Glow();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          gradient: RadialGradient(center: Alignment(0, -.1), radius: .75, colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)]),
        ),
      );
}
