// RewardButton: the glossy buttons of the reward boards at the sizes they draw them.
//
// The kit's GlossButton comes in three heights (52 / 44 / 36). The reward boards also use
// 60 pt CLAIM and SPIN buttons, 50 / 40 pt row buttons and a yellow "Ad" chip (the green
// "▶ AD" chip of GlossButton is the Earn board's), so this builds the same face — GlossFace on a
// Pressable (haptic, tap sound, 44 pt hit area, semantics) — at any height. A button with no
// handler is greyed (never hidden); a grey button is already the "not available" look.

import 'package:flutter/widgets.dart';

import '../../../core/art/glyph.dart';
import '../../../core/art/glyph_extras.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/pressable.dart';
import '../rewards_palette.dart';

class RewardButton extends StatelessWidget {
  const RewardButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = GlossKind.green,
    this.height = 52,
    this.radius = 18,
    this.fontSize = 20,
    this.lip = 5,
    this.soft = 9,
    this.blur = 14,
    this.width,
    this.leading,
    this.trailing,
    this.semanticLabel,
  });

  final String label;

  /// Null greys the button out.
  final VoidCallback? onTap;
  final GlossKind kind;
  final double height;
  final double radius;
  final double fontSize;
  final double lip;
  final double soft;
  final double blur;

  /// Null fills the width the parent gives.
  final double? width;

  /// Before the label (an [AdChip]) and after it (a [GemCost]).
  final Widget? leading;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final gloss = kind.gloss;
    Widget button = Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: radius,
        lip: lip,
        soft: soft,
        blur: blur,
        press: p,
        width: width,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: LmText.plain(fontSize, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.05),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
    if (onTap == null && kind != GlossKind.grey) button = ColorFiltered(colorFilter: lmDisabledFilter, child: button);
    return button;
  }
}

/// The yellow "Ad" chip in front of a rewarded button (Daily gift and Wheel boards).
class AdChip extends StatelessWidget {
  const AdChip({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: LmBox(
          radius: 4,
          color: RewardsPalette.adChip,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
          child: Text(
            tr('Ad'),
            style: LmText.bodyAt(11, weight: FontWeight.w800, color: RewardsPalette.adChipInk, height: 1.0),
          ),
        ),
      );
}

/// A gem and a number: what a speed-up or an extra spin costs, drawn after a button's label.
class GemCost extends StatelessWidget {
  const GemCost(this.gems, {super.key, this.size = 18});

  final int gems;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LmIcon(LmIcons.gem, size: size),
            const SizedBox(width: 3),
            Text('$gems', style: LmText.plain(size, color: LmColors.white, height: 1.0)),
          ],
        ),
      );
}
