// Badges: the small red / green counters on tabs, tiles and dock icons.
//
// Colour is meaning (board A §4): red #F2463B = "act now" (a "!" or a count of
// things waiting), green #47BA2B = a count of new things. A badge never shows 0.
// Badges are decoration for the parent's semantics label (which should say "3
// new"), so they are excluded from the semantics tree.

import 'package:flutter/widgets.dart';

import '../motion/motion.dart';
import '../theme/box_paint.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import 'lm_box.dart';

enum BadgeTone {
  /// Red: act now.
  act,

  /// Green: new / ok.
  fresh,
}

class CountBadge extends StatelessWidget {
  const CountBadge({super.key, this.count, this.label, this.tone = BadgeTone.act, this.pop = false});

  /// A red "!" badge.
  const CountBadge.alert({super.key, this.pop = false})
      : count = null,
        label = '!',
        tone = BadgeTone.act;

  /// A green count of new things.
  const CountBadge.fresh(this.count, {super.key, this.pop = false})
      : label = null,
        tone = BadgeTone.fresh;

  /// The number shown; null with a [label] shows the label; 0 hides the badge.
  final int? count;
  final String? label;
  final BadgeTone tone;

  /// Pops in (scale .4 → 1 with overshoot) when first built.
  final bool pop;

  @override
  Widget build(BuildContext context) {
    final text = label ?? (count == null || count! <= 0 ? null : (count! > 99 ? '99+' : '$count'));
    if (text == null) return const SizedBox.shrink();
    Widget badge = LmBox(
      radius: 11,
      color: tone == BadgeTone.act ? LmColors.badgeRed : LmColors.badgeGreen,
      shadows: const [
        LmShadow(Color(0xFFFFFFFF), spread: 2),
        LmShadow(Color(0x40000000), dy: 2, spread: 2),
      ],
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 12),
        child: Center(
          widthFactor: 1,
          child: Text(text, style: LmText.plain(12, shadows: null, height: 1.0), maxLines: 1, softWrap: false),
        ),
      ),
    );
    if (pop && !Motion.reduced(context)) {
      badge = TweenAnimationBuilder<double>(
        tween: Tween(begin: .4, end: 1),
        duration: Motion.modal,
        curve: Motion.popCurve,
        builder: (context, v, child) => Transform.scale(scale: v, child: child),
        child: badge,
      );
    }
    return ExcludeSemantics(child: badge);
  }
}

/// Puts [badge] on the corner of [child] (default: top-right, hanging off by
/// 6 / 8 pt as on the lobby tiles). The badge does not affect layout.
class Badged extends StatelessWidget {
  const Badged({super.key, required this.child, required this.badge, this.top = -8, this.end = -6});

  final Widget child;
  final Widget badge;
  final double top;
  final double end;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          PositionedDirectional(top: top, end: end, child: badge),
        ],
      );
}
