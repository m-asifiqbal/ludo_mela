// The bottom buttons of the results screens (Win.dc.html, MatchReport.dc.html): glossy buttons
// with an 18 pt corner, side by side, 58 pt high on the Win screen and 56 pt on the report.
//
//   Win screen:     [ home ]  [ INSIGHTS ]  [ PLAY AGAIN (green, wider) ]
//   Match insights: [ home ]  [ PLAY AGAIN ]
//
// The kit's GlossButton tops out at 52 pt, so these use the same GlossFace + Pressable the kit
// buttons are made of, at the board's size. A button with no handler is greyed (while the break
// ad is on its way) rather than hidden.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart';
import '../../../core/widgets/pressable.dart';
import '../result_model.dart';

/// A labelled glossy button, 58 pt high on the Win board and 56 pt on the match report.
class ResultButton extends StatelessWidget {
  const ResultButton({
    super.key,
    required this.label,
    required this.onTap,
    this.kind = GlossKind.blue,
    this.fontSize = 17,
    this.height = 58,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final GlossKind kind;
  final double fontSize;
  final double height;
  final Glyph? icon;

  @override
  Widget build(BuildContext context) {
    final gloss = kind.gloss;
    final button = Pressable(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, p) => GlossFace(
        gloss: gloss,
        radius: 18,
        lip: 5,
        soft: 9,
        blur: 14,
        press: p,
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[LmIcon(icon!, size: 20, tint: gloss.ink), const SizedBox(width: 6)],
                Text(label, maxLines: 1, softWrap: false, style: LmText.plain(fontSize, color: gloss.ink, shadows: [gloss.labelShadow], height: 1.05)),
              ],
            ),
          ),
        ),
      ),
    );
    return onTap == null ? ColorFiltered(colorFilter: lmDisabledFilter, child: button) : button;
  }
}

/// The "back to the lobby" button: a house on blue, [size] pt square (58 on the Win board, 56 on the report).
class HomeButton extends StatelessWidget {
  const HomeButton({super.key, required this.onTap, this.size = 58});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) => GlossIconButton(
        icon: LmGlyphs.dockHome,
        semanticLabel: tr('Back to lobby'),
        onTap: onTap,
        size: size,
        radius: 18,
        lip: 5,
        iconSize: 28,
      );
}

/// What the main button says for [step].
String nextStepLabel(NextStep step) => switch (step) {
      NextStep.playAgain => tr('PLAY AGAIN'),
      NextStep.theCup => tr('MELA CUP'),
      NextStep.wifiParty => tr('WI-FI PARTY'),
    };
