// The kit on small phones and with big system text: header, pills, tabs, segments,
// lobby tiles, dock and buttons must lay out without overflow from 320 to 430 pt
// wide at text scale 0.85 - 1.3 (titles shrink to fit, they never wrap mid-word).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/theme/colors.dart';
import 'package:ludo_mela/core/widgets/widgets.dart';

import '../../helpers/kit_harness.dart';

Widget _screen() => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Collection',
              onBack: () {},
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                CurrencyPill(icon: LmGlyphs.gemCluster, amount: '86', onAdd: () {}, width: 80),
                const SizedBox(width: 6),
                CurrencyPill(icon: LmGlyphs.coinStack, amount: '12,450', onAdd: () {}, width: 98),
              ]),
            ),
            TabPills(
              index: 0,
              onChanged: (_) {},
              tabs: const [
                TabPillItem(label: 'Dice', badge: 2),
                TabPillItem(label: 'Pieces', badge: 1),
                TabPillItem(label: 'Boards'),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedPill<int>(options: const [SegmentOption(0, 'Smart'), SegmentOption(1, 'Master'), SegmentOption(2, 'Expert')], value: 0, onChanged: (_) {}),
            const SizedBox(height: 8),
            Row(children: [
              for (final (colors, glyph, label, sub) in [
                (LmColors.stallCoins, LmGlyphs.stallCoins, 'Free coins', '4 ready'),
                (LmColors.stallWheel, LmGlyphs.stallWheel, 'Lucky wheel', 'Free spin'),
                (LmColors.stallGift, LmGlyphs.stallGift, 'Daily gift', 'Day 4'),
                (LmColors.stallMissions, LmGlyphs.stallMissions, 'Missions', '2 to claim'),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: StallTile(colors: colors, icon: glyph, label: label, sub: sub, semanticLabel: label, badge: const CountBadge(count: 4), onTap: () {}),
                  ),
                ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ModeTile(colors: LmColors.modePass, title: 'Pass & Play', sub: 'Friends on one phone', art: LmGlyphs.modePass, semanticLabel: 'Pass and play', onTap: () {})),
              const SizedBox(width: 8),
              Expanded(child: ModeTile(colors: LmColors.modeWifi, title: 'Wi-Fi Party', sub: 'Nearby · no internet', art: LmGlyphs.modeWifi, semanticLabel: 'Wi-Fi party', onTap: () {})),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GlossButton(onTap: () {}, label: 'Upgrade 1,500', icon: LmIcons.coin, kind: GlossKind.green, size: GlossSize.m, expand: true)),
              const SizedBox(width: 8),
              Expanded(child: GlossButton(onTap: () {}, label: 'Watch an ad for double coins', kind: GlossKind.gold, size: GlossSize.l, adTag: true, expand: true)),
            ]),
            const SizedBox(height: 8),
            const OutlinedText('Lantern Bazaar · win 2,000 coins and a Silver pot', size: 26),
            const SizedBox(height: 8),
            RoundDock(
              index: 2,
              onChanged: (_) {},
              items: const [
                DockItem(icon: LmGlyphs.dockHome, label: 'Home'),
                DockItem(icon: LmGlyphs.dockFriends, label: 'Friends'),
                DockItem(icon: LmGlyphs.dockCollection, label: 'Collection', badge: 3),
                DockItem(icon: LmGlyphs.dockRoad, label: 'Road'),
                DockItem(icon: LmGlyphs.dockEvents, label: 'Events', alert: true),
              ],
            ),
          ],
        ),
      ),
    );

void main() {
  setUpAll(loadKitFonts);

  for (final width in const [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in const [.85, 1.0, 1.3]) {
      testWidgets('no overflow at $width pt wide, text scale $scale', (tester) async {
        useSurface(tester, width: width, height: 900, pixelRatio: 1);
        await tester.pumpWidget(kitApp(_screen(), textScaler: TextScaler.linear(scale)));
        await tester.pump(const Duration(milliseconds: 700));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('a long title shrinks to fit on one line instead of wrapping', (tester) async {
    useSurface(tester, width: 320, height: 200, pixelRatio: 1);
    await tester.pumpWidget(kitApp(const Align(alignment: Alignment.topLeft, child: Padding(padding: EdgeInsets.all(16), child: OutlinedText('Lantern Bazaar · win 2,000 coins', size: 26))), textScaler: const TextScaler.linear(1.3)));
    expect(tester.takeException(), isNull);
    final size = tester.getSize(find.byType(OutlinedText));
    expect(size.width, lessThanOrEqualTo(288 + .01));
    expect(size.height, lessThan(26 * 1.3 * 1.5), reason: 'one line, scaled down');
  });
}
