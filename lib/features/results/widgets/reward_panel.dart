// The reward card of the Win screen (Win.dc.html ".pnl"): coins won and the pot earned side by
// side, the XP line, and the chips that say what happened in the match.
//
// What shows depends on the match: coins only where coins are at stake (a venue table) or were
// won anyway (Mayhem chests), gems only when achievements or a cup title paid some, the pot only
// after a win (or a note when the pot shelf was full). The pot is NOT opened here: pots are
// earned, kept on the lobby shelf and opened after their countdown (board C), so the tile
// says where it went.

import 'package:flutter/widgets.dart';

import '../../../core/art/art.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/gloss.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/count_up_text.dart';
import '../../../core/widgets/idle_motion.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/panel.dart';
import '../../../domain/pot_tier.dart';
import '../result_extras.dart';
import '../result_model.dart';
import '../result_motion.dart';
import '../result_palette.dart';
import 'one_shot.dart';
import 'xp_progress.dart';

/// The pot tile's label wraps at this width, so "Silver pot" reads as two lines like the board.
const double _potLabelWidth = 52;

class RewardPanel extends StatelessWidget {
  const RewardPanel({super.key, required this.model, this.onCoinStep, this.onLevelUp});

  final ResultModel model;

  /// Called as the coin count ticks up (for the coin sound).
  final ValueChanged<int>? onCoinStep;
  final VoidCallback? onLevelUp;

  @override
  Widget build(BuildContext context) {
    final hasPot = model.pot != null || model.potShelfFull;
    final hasRow = model.showCoins || model.gems > 0 || hasPot;
    return OneShot(
      delay: ResultMotion.panelDelay,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: Panel(
        width: 358,
        radius: 24,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasRow) ...[
              Row(
                children: [
                  if (model.showCoins) Expanded(child: _CoinsWell(coins: model.coins, onStep: onCoinStep)),
                  if (model.gems > 0) ...[
                    if (model.showCoins) const SizedBox(width: 10),
                    Expanded(child: _GemsWell(gems: model.gems)),
                  ],
                  if (hasPot) ...[
                    if (model.showCoins || model.gems > 0) const SizedBox(width: 10),
                    SizedBox(width: 120, child: _PotWell(tier: model.pot, shelfFull: model.potShelfFull)),
                  ],
                ],
              ),
              const SizedBox(height: 10),
            ],
            XpProgress(stages: model.xp, onLevelUp: onLevelUp),
            if (model.chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [for (final c in model.chips) _Chip(c)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CoinsWell extends StatelessWidget {
  const _CoinsWell({required this.coins, this.onStep});

  final int coins;
  final ValueChanged<int>? onStep;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: tr('Coins won: {n}', {'n': lmGroupDigits(coins)}),
        child: ExcludeSemantics(
          child: Well(
            height: 56,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LmIcon(LmGlyphs.coinStack, size: 34),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CountUpText(
                      value: coins,
                      prefix: '+',
                      size: 24,
                      color: coins > 0 ? LmColors.xpText : LmColors.textDim,
                      onStep: onStep,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _GemsWell extends StatelessWidget {
  const _GemsWell({required this.gems});

  final int gems;

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        label: tr('Gems won: {n}', {'n': gems}),
        child: ExcludeSemantics(
          child: Well(
            height: 56,
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const LmIcon(LmIcons.gem, size: 26),
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: CountUpText(value: gems, prefix: '+', size: 22, color: LmColors.gemHi),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// The pot this win put on the lobby shelf, or "Shelf full".
class _PotWell extends StatelessWidget {
  const _PotWell({required this.tier, required this.shelfFull});

  final PotTier? tier;
  final bool shelfFull;

  PotKind get _kind => switch (tier) {
        PotTier.silver => PotKind.silver,
        PotTier.gold || PotTier.epic => PotKind.gold,
        PotTier.mela => PotKind.mela,
        _ => PotKind.clay,
      };

  @override
  Widget build(BuildContext context) {
    final full = tier == null;
    final label = full ? tr('Shelf full') : tier!.title;
    return Semantics(
      container: true,
      label: full ? tr('Your pot shelf is full, no pot this time') : tr('{pot} added to your shelf', {'pot': label}),
      child: ExcludeSemantics(
        child: Well(
          height: 56,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OneShot(
                delay: ResultMotion.potDelay,
                duration: ResultMotion.pop,
                curve: Motion.popCurve,
                builder: (context, t, child) => Transform.scale(scale: t.clamp(0.0, 1.3), child: child),
                child: IdleMotion(
                  kind: full ? IdleKind.none : IdleKind.wiggle,
                  child: Opacity(opacity: full ? .45 : 1, child: MelaPot(kind: _kind, cloth: LmGloss.blue.mid, size: 36)),
                ),
              ),
              const SizedBox(width: 6),
              // Two short lines, as on the board ("Silver" over "pot"); a longer translation wraps the same way.
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _potLabelWidth),
                  child: OutlinedText(label, size: 14, maxLines: 2, height: 1.05),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.chip);

  final ResultChip chip;

  Color get _tint => switch (chip.kind) {
        ChipKind.fact => ResultPalette.chipFact,
        ChipKind.mission => ResultPalette.chipMission,
        ChipKind.achievement => ResultPalette.chipAchievement,
        ChipKind.cup => ResultPalette.chipCup,
      };

  @override
  Widget build(BuildContext context) => LmBox(
        radius: 13,
        height: 26,
        color: _tint,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Center(
          widthFactor: 1,
          child: Text(chip.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: LmText.bodyAt(12, weight: FontWeight.w800, height: 1.0)),
        ),
      );
}
