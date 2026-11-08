// The headline of the Win screen: "YOU WON!" slamming in over the podium (Win.dc.html "lm-slam":
// it starts 2.6x big and tilted, lands a little small and settles).
//
// A win wears the gold hero title; a finished-but-not-first headline is the same lettering in
// cool silver-blue, so a loss is calm rather than flashy. The text is announced as a header.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/outlined_text.dart';
import '../result_motion.dart';
import '../result_palette.dart';
import '../result_text.dart';
import 'one_shot.dart';

class ResultTitle extends StatelessWidget {
  const ResultTitle({super.key, required this.text, required this.gold});

  /// Already translated.
  final String text;

  /// Gold (a win) or silver (anything else).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final title = gold
        ? HeroTitle(text, semanticsLabel: text)
        : HeroTitle(
            text,
            fillColors: ResultPalette.placedFill,
            outline: ResultPalette.placedOutline,
            drop: ResultPalette.placedDrop,
            semanticsLabel: text,
          );
    return Semantics(
      header: true,
      label: text,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 330,
          height: 92,
          child: OneShot(
            duration: ResultMotion.slam,
            curve: Motion.popCurve,
            child: FittedBox(fit: BoxFit.scaleDown, child: title),
            builder: (context, t, child) => Opacity(
              opacity: (t * 1.6).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -8 * math.pi / 180 * (1 - t),
                child: Transform.scale(scale: 1 + 1.6 * (1 - t), child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small line under the headline ("Lantern Bazaar · 4 players · 21 turns").
class ResultSubtitle extends StatelessWidget {
  const ResultSubtitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => OneShot(
        delay: ResultMotion.subtitleDelay,
        builder: (context, t, child) => Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedText(text, size: 15, color: LmColors.textPale, textAlign: TextAlign.center, height: kDisplayLine),
        ),
      );
}
