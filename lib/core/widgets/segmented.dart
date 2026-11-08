// SegmentedPill and TabPills: the two ways the game picks one of a few options.
//
// * [SegmentedPill] — a sunken well holding 2 – 4 choices. `flat` is the
//   "Vs Computer | Pass & Play" and "Easy | Smart | Master" look: a gold pill
//   slides under the selected label. `glossy` is the Settings / Pause look: real
//   glossy buttons, gold for the selected one and blue for the rest.
// * [TabPills] — big tabs with an icon (Dice | Pieces | Boards): gold selected,
//   navy idle, with an optional green "new" badge.

import 'package:flutter/widgets.dart';

import '../art/glyph.dart';
import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/gloss.dart';
import '../theme/space.dart';
import '../theme/text.dart';
import 'badges.dart';
import 'gloss_button.dart';
import 'lm_box.dart';
import 'panel.dart';
import 'pressable.dart';

/// One choice of a [SegmentedPill].
class SegmentOption<T> {
  const SegmentOption(this.value, this.label, {this.semanticLabel});

  final T value;
  final String label;
  final String? semanticLabel;
}

enum SegmentedStyle {
  /// Dark well, sliding gold pill, idle labels as plain text.
  flat,

  /// Well of glossy buttons: gold selected, blue idle.
  glossy,
}

class SegmentedPill<T> extends StatelessWidget {
  const SegmentedPill({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.style = SegmentedStyle.flat,
    this.height,
    this.fontSize,
    this.expand = true,
  });

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final SegmentedStyle style;

  /// Outer height; defaults to 42 (flat) / 38 (glossy).
  final double? height;
  final double? fontSize;

  /// Segments share the width equally (otherwise they hug their labels).
  final bool expand;

  @override
  Widget build(BuildContext context) =>
      style == SegmentedStyle.flat ? _flat(context) : _glossy(context);

  Widget _flat(BuildContext context) {
    final h = height ?? 42;
    final selected = options.indexWhere((o) => o.value == value);
    final fs = fontSize ?? 14;
    return Semantics(
      container: true,
      child: LmBox(
        radius: 13,
        color: const Color(0xFF08245A),
        shadows: const [LmShadow(Color(0x73000000), dy: 2, blur: 4, inset: true)],
        height: h,
        padding: const EdgeInsets.all(4),
        child: LayoutBuilder(
          builder: (context, c) {
            final segW = c.maxWidth / options.length;
            final reduced = Motion.reduced(context);
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: reduced ? Duration.zero : Motion.quick,
                  curve: Motion.standardCurve,
                  left: segW * (selected < 0 ? 0 : selected),
                  top: 0,
                  bottom: 0,
                  width: segW,
                  child: selected < 0
                      ? const SizedBox.shrink()
                      : const Padding(
                          padding: EdgeInsets.only(bottom: 2),
                          child: LmBox(
                            radius: 10,
                            gradient: LmGradient([Color(0xFFFFE27A), Color(0xFFF2B200)]),
                            shadows: [LmShadow(Color(0xFF9A5600), dy: 2)],
                          ),
                        ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < options.length; i++)
                      Expanded(
                        child: Pressable(
                          onTap: () => onChanged(options[i].value),
                          semanticLabel: options[i].semanticLabel ?? options[i].label,
                          selected: i == selected,
                          pressedScale: .97,
                          sink: 0,
                          child: SizedBox(
                            height: double.infinity,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: reduced ? Duration.zero : Motion.quick,
                                style: LmText.plain(fs, color: i == selected ? LmColors.inkOnGold : LmColors.textDim, height: 1.0),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(options[i].label, maxLines: 1, softWrap: false)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _glossy(BuildContext context) {
    final h = height ?? 38;
    final inner = h - 6;
    return Semantics(
      container: true,
      child: Well(
        radius: 14,
        height: h,
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
              _glossSegment(options[i], inner),
            ],
          ],
        ),
      ),
    );
  }

  Widget _glossSegment(SegmentOption<T> o, double h) {
    final on = o.value == value;
    final gloss = on ? LmGloss.gold : LmGloss.blue;
    final seg = Pressable(
      onTap: () => onChanged(o.value),
      semanticLabel: o.semanticLabel ?? o.label,
      selected: on,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: 10,
        lip: 3,
        soft: 0,
        blur: 0,
        press: p,
        height: h - 3,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Center(
          widthFactor: 1,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              o.label,
              style: LmText.plain(fontSize ?? 13, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.0),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
    final padded = Padding(padding: const EdgeInsets.only(bottom: 3), child: seg);
    return expand ? Expanded(child: padded) : ConstrainedBox(constraints: const BoxConstraints(minWidth: 46), child: padded);
  }
}

/// One tab of [TabPills].
class TabPillItem {
  const TabPillItem({required this.label, this.icon, this.badge = 0, this.semanticLabel});

  final String label;
  final Glyph? icon;

  /// Green "new" count (0 hides the badge).
  final int badge;
  final String? semanticLabel;
}

class TabPills extends StatelessWidget {
  const TabPills({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.height = 46,
    this.radius = LmRadius.card,
    this.fontSize = 18,
    this.gap = 8,
  });

  final List<TabPillItem> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final double height;
  final double radius;
  final double fontSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Expanded(child: _tab(i)),
          ],
        ],
      ),
    );
  }

  Widget _tab(int i) {
    final t = tabs[i];
    final on = i == index;
    final gloss = on ? LmGloss.gold : LmGloss.navy;
    final lip = on ? 4.0 : 3.0;
    Widget tab = Pressable(
      onTap: () => onChanged(i),
      semanticLabel: t.semanticLabel ?? (t.badge > 0 ? '${t.label}, ${t.badge} new' : t.label),
      selected: on,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: radius,
        lip: lip,
        soft: on ? 6 : 0,
        blur: 10,
        press: p,
        height: height,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.icon != null) ...[LmIcon(t.icon!, size: fontSize * 1.4), const SizedBox(width: 6)],
                  Text(
                    t.label,
                    style: LmText.plain(fontSize, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.0),
                    maxLines: 1,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (t.badge > 0) tab = Badged(badge: CountBadge.fresh(t.badge), child: tab);
    return tab;
  }
}
