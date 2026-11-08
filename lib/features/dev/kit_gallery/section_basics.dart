// Gallery › Basics: colour tokens, the type scale, buttons, pills, badges, tabs,
// segmented controls, switches, bars, level marks, toasts, count-up and entrance.

import 'package:flutter/widgets.dart';

import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/space.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/widgets.dart';
import 'gallery_common.dart';

class BasicsSection extends StatefulWidget {
  const BasicsSection({super.key});

  @override
  State<BasicsSection> createState() => _BasicsSectionState();
}

class _BasicsSectionState extends State<BasicsSection> {
  int _tab = 0;
  int _seg = 1;
  int _glossSeg = 0;
  bool _sound = true;
  bool _music = false;
  int _coins = 12450;
  int _replay = 0;

  @override
  Widget build(BuildContext context) {
    return GalleryPage(
      children: [
        GalleryBlock(title: '1 · Colour tokens', child: _colours()),
        GalleryBlock(title: '2 · Type scale', child: _type()),
        GalleryBlock(title: '4 · Glossy buttons', note: 'L 52 / M 44 / S 36 / tool 42 pt. Press them: they sink 3 pt onto the lip.', child: _buttons()),
        GalleryBlock(title: 'Pills, badges, level', child: _pills()),
        GalleryBlock(title: 'Tabs, segments, switches', child: _controls()),
        GalleryBlock(title: 'Bars', child: _bars()),
        GalleryBlock(title: 'Motion helpers', child: _motion()),
      ],
    );
  }

  Widget _swatch(String name, Color c) => Captioned(
        name,
        Container(
          width: 52,
          height: 26,
          decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0x59FFFFFF), width: 1.5)),
        ),
      );

  Widget _colours() {
    Widget gl(String n, LmGloss g) => Captioned(
          n,
          LmBox(
            radius: 6,
            width: 52,
            height: 26,
            gradient: g.gradient,
            shadows: [LmShadow(g.lip, dy: 3)],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Samples(children: [
          gl('green', LmGloss.green),
          gl('gold', LmGloss.gold),
          gl('blue', LmGloss.blue),
          gl('red', LmGloss.red),
          gl('pink', LmGloss.pink),
          gl('purple', LmGloss.purple),
          gl('navy', LmGloss.navy),
          gl('grey', LmGloss.grey),
        ]),
        const SizedBox(height: 14),
        Samples(spacing: 6, children: [
          for (final s in const [('red', LmColors.red), ('green', LmColors.green), ('yellow', LmColors.yellow), ('blue', LmColors.blue)]) ...[
            _swatch('${s.$1} main', s.$2.main),
            _swatch('dark', s.$2.dark),
            _swatch('light', s.$2.light),
            _swatch('side', s.$2.side),
          ],
        ]),
        const SizedBox(height: 14),
        Samples(spacing: 6, children: [
          _swatch('sky', LmColors.skyHi),
          _swatch('royal', LmColors.royalHi),
          _swatch('deep', LmColors.deep),
          _swatch('panel', LmColors.panelHi),
          _swatch('rim', LmColors.panelRim),
          _swatch('well', LmColors.well),
          _swatch('navy', LmColors.navy),
          _swatch('frame', LmColors.boardFrameHi),
          _swatch('coin', LmColors.coinMid),
          _swatch('gem', LmColors.gemMid),
          _swatch('act', LmColors.badgeRed),
          _swatch('new', LmColors.badgeGreen),
          _swatch('xp', LmColors.xpText),
        ]),
      ],
    );
  }

  Widget _type() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You won!', style: LmText.display),
          Text('Collection', style: LmText.h1),
          Text('Select Mode', style: LmText.h2),
          Text('4 Players', style: LmText.cta),
          Text('Play · Collect · Use', style: LmText.btnL),
          Text('Tap to Unlock', style: LmText.label),
          Text('12,450', style: LmText.value),
          Text('Watch a short ad to collect.', style: LmText.body),
          Text('VS COMPUTER · WIN UP TO 1,500', style: LmText.caption),
          const SizedBox(height: 6),
          const HeroTitle('YOU WON!', size: 40),
        ],
      );

  Widget _buttons() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Samples(spacing: 14, children: [
            GlossButton(onTap: () {}, label: 'Play', size: GlossSize.l, width: 150),
            GlossButton(onTap: () {}, label: 'Use', kind: GlossKind.blue, width: 110),
            GlossButton(onTap: () {}, label: '140', kind: GlossKind.gold, size: GlossSize.s, width: 84),
            GlossButton(onTap: () {}, label: 'Hint ×3', kind: GlossKind.steel, size: GlossSize.tool, icon: LmIcons.bulb),
          ]),
          const SizedBox(height: 14),
          Samples(spacing: 10, children: [
            for (final k in const [GlossKind.green, GlossKind.gold, GlossKind.blue, GlossKind.red, GlossKind.pink, GlossKind.purple, GlossKind.navy])
              GlossButton(onTap: () {}, label: k.name, kind: k, size: GlossSize.s, width: 82),
            GlossButton(onTap: null, label: 'locked', kind: GlossKind.grey, size: GlossSize.s, width: 82),
          ]),
          const SizedBox(height: 14),
          Samples(spacing: 12, children: [
            GlossButton(onTap: () {}, label: 'Collect', subLabel: '+150', width: 100),
            GlossButton(onTap: () {}, label: 'Collect', adTag: true, width: 130),
            GlossButton(onTap: () {}, label: 'Mission', badge: const CountBadge.alert(), kind: GlossKind.blue, width: 110),
            GlossButton(onTap: () {}, label: 'Buy', kind: GlossKind.gold, icon: LmIcons.gem, width: 100),
            GlossIconButton.close(onTap: () {}),
            GlossIconButton.back(onTap: () {}),
            GlossIconButton(icon: LmIcons.menu, semanticLabel: 'Menu', onTap: () {}, kind: GlossKind.steel),
          ]),
        ],
      );

  Widget _pills() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Samples(spacing: 18, children: [
            CurrencyPill(icon: LmIcons.coin, amount: '12,450', onAdd: () {}, width: 114),
            CurrencyPill(icon: LmIcons.gem, amount: '86'),
            PlankPill(icon: LmIcons.gem, amount: '86', onTap: () {}, semanticLabel: '86 gems'),
            PlankPill(icon: LmIcons.coin, amount: '12.4K', onTap: () {}, semanticLabel: '12,450 coins'),
            const GearButton(),
            const LevelStar(level: 7),
            const LevelPill(level: 12),
          ]),
          const SizedBox(height: 18),
          Samples(spacing: 22, children: [
            const CountBadge.alert(),
            const CountBadge.fresh(5),
            const CountBadge(count: 120),
            Badged(badge: const CountBadge.alert(), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: LmGloss.blue.mid, borderRadius: BorderRadius.circular(10)))),
            Badged(badge: const CountBadge.fresh(5), child: Container(width: 40, height: 40, decoration: BoxDecoration(color: LmGloss.blue.mid, borderRadius: BorderRadius.circular(10)))),
          ]),
        ],
      );

  Widget _controls() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TabPills(
            tabs: const [
              TabPillItem(label: 'Dice', icon: LmGlyphs.tabDice, badge: 2),
              TabPillItem(label: 'Pieces', icon: LmGlyphs.tabPieces, badge: 1),
              TabPillItem(label: 'Boards', icon: LmGlyphs.tabBoards),
            ],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 16),
          SegmentedPill<int>(
            options: const [SegmentOption(0, 'Easy'), SegmentOption(1, 'Smart'), SegmentOption(2, 'Master')],
            value: _seg,
            onChanged: (v) => setState(() => _seg = v),
          ),
          const SizedBox(height: 12),
          SegmentedPill<int>(
            style: SegmentedStyle.glossy,
            options: const [SegmentOption(0, 'Day'), SegmentOption(1, 'Mela'), SegmentOption(2, 'Auto')],
            value: _glossSeg,
            onChanged: (v) => setState(() => _glossSeg = v),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              MelaSwitch(value: _sound, onChanged: (v) => setState(() => _sound = v), semanticLabel: 'Sound'),
              const SizedBox(width: 16),
              MelaSwitch(value: _music, onChanged: (v) => setState(() => _music = v), semanticLabel: 'Music'),
              const SizedBox(width: 16),
              const MelaSwitch(value: true, onChanged: null, semanticLabel: 'Locked'),
            ],
          ),
        ],
      );

  Widget _bars() => Column(
        children: const [
          ProgressBar(value: .75, label: '340 / 450', height: 18, fill: BarFill.green),
          SizedBox(height: 8),
          ProgressBar(value: .5, fill: BarFill.gold),
          SizedBox(height: 8),
          ProgressBar(value: .2, fill: BarFill.purple, label: '6 / 33'),
          SizedBox(height: 10),
          StatBar(label: 'Roll fx', value: .6, valueText: '3/5'),
          SizedBox(height: 4),
          StatBar(label: 'XP boost', value: .66, valueText: '+10%', fill: BarFill.green),
        ],
      );

  Widget _motion() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KeyedSubtree(key: ValueKey(_coins), child: CountUpText(value: _coins, size: 28, color: LmColors.xpText, prefix: '+')),
              const SizedBox(width: 14),
              GlossButton(onTap: () => setState(() => _coins = _coins == 12450 ? 1500 : 12450), label: 'Count', size: GlossSize.s, width: 80),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              GlossButton(onTap: () => showToast(context, 'Six! Roll again'), label: 'Toast', kind: GlossKind.blue, size: GlossSize.s, width: 80),
              const SizedBox(width: 10),
              GlossButton(onTap: () => showToast(context, 'Captured Raja!', tone: ToastTone.green), label: 'Good', kind: GlossKind.green, size: GlossSize.s, width: 70),
              const SizedBox(width: 10),
              GlossButton(onTap: () => setState(() => _replay++), label: 'Replay', kind: GlossKind.gold, size: GlossSize.s, width: 80),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(spacing: 8, runSpacing: 8, children: [
            ToastPill(text: 'No move with a 4'),
            ToastPill(text: 'Home! Roll again', tone: ToastTone.green),
            ToastPill(text: 'Three sixes', tone: ToastTone.red),
          ]),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: ValueKey(_replay),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    child: Entrance(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: LmBox(radius: 12, height: 44, gradient: LmGloss.blue.gradient, shadows: LmDepth.raised(LmGloss.blue.lip, lipHeight: 4), child: Center(child: Text('${i + 1}', style: LmText.btnM))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}
