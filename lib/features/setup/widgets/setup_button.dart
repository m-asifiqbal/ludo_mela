// SetupButton: the glossy button of the setup boards in the sizes they use (Mela Tour PLAY 34 pt,
// VS 58 pt, START 60 pt), which the kit's three sizes do not cover.
//
// It is a GlossFace on a Pressable, exactly like GlossButton (same press dip, haptic, tap sound,
// 44 pt hit area and disabled look), with the height, radius and label size of the board. A null
// [onTap] greys it out (never hides it).

import 'package:flutter/widgets.dart';

import '../../../core/art/glyph.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart' show GlossFace, lmDisabledFilter;
import '../../../core/widgets/pressable.dart';

class SetupButton extends StatelessWidget {
  const SetupButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gloss = LmGloss.green,
    this.height = 58,
    this.radius = 20,
    this.fontSize = 22,
    this.lip = 5,
    this.soft = 9,
    this.blur = 14,
    this.width,
    this.minWidth,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.semanticLabel,
  });

  final String label;

  /// Null greys the button out.
  final VoidCallback? onTap;
  final LmGloss gloss;
  final double height;
  final double radius;
  final double fontSize;
  final double lip;
  final double soft;
  final double blur;

  /// Fixed width, or null to fill the parent (or [minWidth] at least when it hugs its label).
  final double? width;
  final double? minWidth;

  /// A small glyph before the label (the lock of a closed venue).
  final Glyph? icon;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final content = FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[LmIcon(icon!, size: fontSize * .9), const SizedBox(width: 6)],
          Text(
            label,
            style: LmText.plain(fontSize, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.05),
            maxLines: 1,
            softWrap: false,
          ),
        ],
      ),
    );
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
        padding: padding,
        child: Center(widthFactor: 1, heightFactor: 1, child: content),
      ),
    );
    if (minWidth != null) button = ConstrainedBox(constraints: BoxConstraints(minWidth: minWidth!), child: button);
    if (onTap == null) button = ColorFiltered(colorFilter: lmDisabledFilter, child: button);
    return button;
  }
}
