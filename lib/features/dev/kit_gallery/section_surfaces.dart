// Gallery › Surfaces: panels, wells, cards, ribbons, dialogs (both styles), rarity
// frames, screen headers and a replica of the Free Rewards pop-up (Earn.dc.html).

import 'package:flutter/widgets.dart';

import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class SurfacesSection extends StatelessWidget {
  const SurfacesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(title: '3 · Depth: panel, well, card', child: _depth()),
        GalleryBlock(title: 'Ribbons', child: _ribbons()),
        GalleryBlock(
          title: 'Dialogs',
          note: 'Ribbon title overlaps the top by 24, the red X closes it (so do back and the scrim).',
          child: Samples(children: [
            GlossButton(
              onTap: () => showMelaDialog<void>(context, title: 'Free Rewards', builder: (_) => const FreeRewardsBody()),
              label: 'Free rewards',
              kind: GlossKind.gold,
              size: GlossSize.s,
              width: 120,
            ),
            GlossButton(
              onTap: () => showMelaDialog<void>(context, title: 'Daily Missions', tone: RibbonTone.green, builder: (_) => const SizedBox(height: 120, child: Center(child: OutlinedText('Missions go here', size: 18)))),
              label: 'Missions',
              kind: GlossKind.green,
              size: GlossSize.s,
              width: 100,
            ),
            GlossButton(
              onTap: () => showMelaDialog<void>(context, title: 'Paused', style: MelaDialogStyle.band, builder: (_) => const SizedBox(height: 100, child: Center(child: OutlinedText('Sheet with a header band', size: 16)))),
              label: 'Band sheet',
              kind: GlossKind.blue,
              size: GlossSize.s,
              width: 110,
            ),
          ]),
        ),
        GalleryBlock(title: 'Rarity frames', child: _rarity()),
        GalleryBlock(
          title: 'Headers',
          child: Column(
            children: [
              ScreenHeader(title: 'SETTINGS', onBack: () {}, padding: EdgeInsets.zero),
              const SizedBox(height: 12),
              ClipRect(child: SkyHeader(title: 'MELA TOUR', onBack: () {}, trailing: const LevelPill(level: 7))),
            ],
          ),
        ),
        GalleryBlock(title: 'Free Rewards, as a static panel', child: const Center(child: SizedBox(width: 360, child: _EarnReplica()))),
      ],
    );
  }

  Widget _depth() => Column(
        children: [
          Samples(spacing: 18, children: [
            const SizedBox(width: 150, height: 70, child: Panel(child: Center(child: OutlinedText('Panel · .pnl', size: 16)))),
            const SizedBox(width: 150, height: 70, child: Panel(tone: PanelTone.purple, child: Center(child: OutlinedText('Purple', size: 16)))),
            const SizedBox(width: 150, height: 70, child: Panel(tone: PanelTone.modal, child: Center(child: OutlinedText('Modal · .sec', size: 16)))),
          ]),
          const SizedBox(height: 22),
          Samples(spacing: 18, children: [
            const Well(width: 150, height: 56, alignment: Alignment.center, child: OutlinedText('Well', size: 16)),
            const Well.purple(width: 150, height: 56, alignment: Alignment.center, child: OutlinedText('Purple well', size: 16)),
            KitCard(width: 150, height: 56, onTap: () {}, semanticLabel: 'Card', child: const Center(child: OutlinedText('Card', size: 16))),
          ]),
        ],
      );

  Widget _ribbons() => Column(
        children: const [
          RibbonBanner(title: 'Free Rewards'),
          SizedBox(height: 10),
          RibbonBanner(title: 'Daily Missions', tone: RibbonTone.green),
          SizedBox(height: 10),
          RibbonBanner(title: 'Game Options', tone: RibbonTone.blue),
        ],
      );

  Widget _rarity() => Column(
        children: [
          Row(
            children: [
              for (final r in LmRarity.values) ...[
                if (r != LmRarity.standard) const SizedBox(width: 6),
                RarityChip(rarity: r),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final r in LmRarity.values) ...[
                if (r != LmRarity.standard) const SizedBox(width: 10),
                Expanded(
                  child: RarityFrame(
                    rarity: r,
                    height: 58,
                    padding: EdgeInsets.zero,
                    child: Center(child: OutlinedText(r.label, size: 15)),
                  ),
                ),
              ],
            ],
          ),
        ],
      );
}

/// The body of the Free Rewards pop-up (Earn.dc.html): the free-coins card and
/// the ladder rows.
class FreeRewardsBody extends StatelessWidget {
  const FreeRewardsBody({super.key});

  Widget _ladder(int n, Widget icon, String title, String sub, Widget trailing, {bool done = false, bool current = false}) => LmBox(
        radius: 14,
        height: 58,
        gradient: LmGradient(done ? const [Color(0xFF2C6FCC), Color(0xFF1F5AB0)] : const [Color(0xFF2258AE), Color(0xFF1A4A98)]),
        shadows: [LmShadow.rim(current ? LmColors.xpText : (done ? LmColors.badgeGreen : const Color(0xFF3F78D6)), 2)],
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: done ? LmColors.badgeGreen : (current ? const Color(0xFFFFC61F) : const Color(0xFF3F6FB8)), shape: BoxShape.circle, border: Border.all(color: LmColors.white, width: 2)),
              alignment: Alignment.center,
              child: Text('$n', style: LmText.plain(14, color: current ? LmColors.inkOnGold : LmColors.white, shadows: const [], height: 1.0)),
            ),
            const SizedBox(width: 12),
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedText(title, size: 17, color: current ? const Color(0xFFFF92D4) : LmColors.xpText),
                  Text(sub, style: LmText.bodyAt(10.5, weight: FontWeight.w800, color: LmColors.textSoft, height: 1.1), maxLines: 1),
                ],
              ),
            ),
            trailing,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LmBox(
            radius: 14,
            gradient: const LmGradient([Color(0xFFFFE27A), Color(0xFFF2B200)]),
            shadows: const [LmShadow.rim(Color(0xFFFFF3B8), 2), LmShadow(Color(0xFF9A5600), dy: 3)],
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                const LmIcon(LmGlyphs.coinStack, size: 46),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const OutlinedText('Free coins', size: 17),
                      Text('+150 coins every 4 hours', style: LmText.bodyAt(12, weight: FontWeight.w800, color: const Color(0xFF6B3A00), height: 1.1)),
                    ],
                  ),
                ),
                GlossButton(onTap: () {}, label: 'Collect', subLabel: '+150', width: 96),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Center(child: OutlinedText('Watch & collect · one by one', size: 13.5)),
          const SizedBox(height: 8),
          _ladder(1, const LmIcon(LmGlyphs.coinStack, size: 36), '250', 'Coins · one short ad', const LmIcon(LmIcons.tick, size: 36), done: true),
          const SizedBox(height: 8),
          _ladder(2, const LmIcon(LmGlyphs.gemCluster, size: 36), '2 gems', 'Gems · one short ad', GlossButton(onTap: () {}, label: 'Collect', adTag: true, width: 108), current: true),
          const SizedBox(height: 8),
          _ladder(3, const LmIcon(LmGlyphs.coinStack, size: 36), '600', 'Coins · one short ad', const _Locked('After 2')),
        ],
      );
}

class _Locked extends StatelessWidget {
  const _Locked(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 10,
        width: 108,
        height: 44,
        color: const Color(0x4D0A2A6B),
        shadows: const [LmShadow(Color(0x4D000000), dy: 2, blur: 4, inset: true)],
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LmIcon(LmIcons.lock, size: 16),
            const SizedBox(width: 6),
            Text(text, style: LmText.plain(13, color: LmColors.textDim, shadows: const [])),
          ],
        ),
      );
}

class _EarnReplica extends StatelessWidget {
  const _EarnReplica();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 28),
        child: MelaDialog(title: 'Free Rewards', onClose: _noop, child: FreeRewardsBody()),
      );
}

void _noop() {}
