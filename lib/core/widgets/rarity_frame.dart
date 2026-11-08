// RarityFrame and RarityChip: the colour of a Collection card tells how rare it is
// (board A §4): Standard blue, Rare orange, Epic red, Legendary purple.
//
// A frame is a rounded card with a vertical gradient, a 2.5 pt light rim, a faint
// top light, a hard lip and a soft drop. The chip is the small pill of the legend
// under the tabs. Rarity is never colour alone: cards also print the rarity name.

import 'package:flutter/widgets.dart';

import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'lm_box.dart';
import 'pressable.dart';

class RarityFrame extends StatelessWidget {
  const RarityFrame({
    super.key,
    required this.rarity,
    this.child,
    this.padding = const EdgeInsets.fromLTRB(8, 8, 8, 10),
    this.radius = 14,
    this.width,
    this.height,
    this.onTap,
    this.semanticLabel,
  });

  final LmRarity rarity;
  final Widget? child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double? width;
  final double? height;

  /// Makes the whole card tappable (open try-on).
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = rarity.colors;
    final box = LmBox(
      radius: radius,
      gradient: LmGradient([c.top, c.bottom]),
      shadows: [
        LmShadow.rim(c.rim, 2.5),
        const LmShadow(Color(0x40FFFFFF), dy: 4, inset: true),
        LmShadow(c.lip, dy: 4),
        const LmShadow(Color(0x4D00143C), dy: 8, blur: 12),
      ],
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: box);
  }
}

/// A small legend pill: the rarity name on its frame colour.
class RarityChip extends StatelessWidget {
  const RarityChip({super.key, required this.rarity, this.label});

  final LmRarity rarity;

  /// The translated rarity name; defaults to the English one.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = rarity.colors;
    return LmBox(
      radius: 10,
      height: 20,
      gradient: LmGradient([c.top, c.bottom]),
      shadows: [LmShadow.rim(c.rim, 1.5)],
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        widthFactor: 1,
        child: Text(
          label ?? c.name,
          maxLines: 1,
          style: LmText.plain(11, height: 1.0, shadows: const [Shadow(color: Color(0x59000000), offset: Offset(0, 1))]),
        ),
      ),
    );
  }
}
