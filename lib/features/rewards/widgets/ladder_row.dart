// A row of the Free Rewards ladder (Earn.dc.html): a step number, the picture of the prize, its
// name and a line of small print, and on the right what the player can do with it.
//
//   done    green rim, a green check
//   next    lit face, gold rim that glows, the green "Collect ▶ AD" button
//   locked  dimmed, a "After 2" pill
// The same row serves the "bonus ads" under a finished ladder (a "+" in the disc). The coin that
// flies up when a prize is collected is passed in as [fly] and drawn over the row's right side.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../rewards_motion.dart';
import '../rewards_palette.dart';
import 'pulse_glow.dart';

enum LadderState { done, next, locked }

class LadderRow extends StatelessWidget {
  const LadderRow({
    super.key,
    required this.state,
    required this.badge,
    required this.icon,
    required this.amount,
    required this.ink,
    required this.caption,
    required this.trailing,
    required this.semanticLabel,
    this.fly,
  });

  final LadderState state;

  /// The text in the number disc: "1", or "+" for a bonus ad.
  final String badge;

  /// The prize picture (fits a 46 pt box).
  final Widget icon;

  /// "250", "2 gems", "Silver pot".
  final String amount;

  /// The amount's colour: gold for coins, pink for gems, white for a pot.
  final Color ink;
  final String caption;

  /// The button, lock pill or check on the right (108 × 44).
  final Widget trailing;

  /// What a screen reader says about the whole row ("Step 2: 2 gems, ready").
  final String semanticLabel;

  /// A [FlyUpText] drawn over the right side while a prize is being collected.
  final Widget? fly;

  @override
  Widget build(BuildContext context) {
    final lit = state == LadderState.next;
    final (rim, disc) = switch (state) {
      LadderState.done => (RewardsPalette.rimDone, LmColors.badgeGreen),
      LadderState.next => (RewardsPalette.rimNext, RewardsPalette.stepNext),
      LadderState.locked => (RewardsPalette.rimWaiting, RewardsPalette.stepWaiting),
    };
    final face = lit
        ? const LmGradient([RewardsPalette.rowLitHi, RewardsPalette.rowLitLo])
        : const LmGradient([RewardsPalette.rowHi, RewardsPalette.rowLo]);
    Widget row = PulseGlow(
      active: lit,
      color: RewardsPalette.rimNext,
      period: RewardsMotion.rowGlow,
      child: LmBox(
        radius: 14,
        gradient: face,
        height: 64,
        shadows: [LmShadow.rim(rim, 2)],
        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 10, 0),
        child: Row(
          children: [
            // The row's label says all of this once; only the button on the right is read on its own.
            Expanded(
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    LmBox(
                      radius: 15,
                      color: disc,
                      width: 30,
                      height: 30,
                      shadows: const [LmShadow(RewardsPalette.discDrop, dy: 2)],
                      child: Center(child: OutlinedText(badge, size: 16, fit: false)),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 46, height: 46, child: Center(child: icon)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OutlinedText(amount, size: 18, color: ink, height: 1.1),
                          Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LmText.bodyAt(11, color: RewardsPalette.rowCaption, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 108, height: 44, child: Center(child: trailing)),
          ],
        ),
      ),
    );
    if (state == LadderState.locked) row = Opacity(opacity: .78, child: row);
    return Semantics(
      container: true,
      label: semanticLabel,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          row,
          if (fly != null) PositionedDirectional(end: 30, top: 4, child: fly!),
        ],
      ),
    );
  }
}

/// The dark "🔒 After 2" pill of a step that cannot be taken yet (108 × 44).
class LadderLock extends StatelessWidget {
  const LadderLock(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 12,
        color: RewardsPalette.lockedPill,
        width: 108,
        height: 44,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LmIcon(LmIcons.lock, size: 16),
                const SizedBox(width: 6),
                Text(text, maxLines: 1, softWrap: false, style: LmText.plain(13, color: LmColors.textDim, shadows: const [], height: 1.0)),
              ],
            ),
          ),
        ),
      );
}

/// The green check of a collected step.
class LadderDone extends StatelessWidget {
  const LadderDone({super.key});

  @override
  Widget build(BuildContext context) => Semantics(label: tr('Collected'), child: const ExcludeSemantics(child: LmIcon(LmIcons.tick, size: 36)));
}
