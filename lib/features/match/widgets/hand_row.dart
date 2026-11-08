// HandRow: the Mela Mayhem power cards in your hand and the USE button (Mayhem.dc.html).
//
// Up to two cards as glossy chips (icon, name). Tap a card to lift it (the line above the tool row then says what
// it does); USE plays a card that needs no target (Double, Reroll) or asks for the piece to tap (Shield, Hop +3,
// Swap, Freeze) — pressing it again cancels. Cards that cannot be played right now (not your turn, one card per
// turn, no legal target) are dimmed, never hidden. With an empty hand a line says how to draw one. The row keeps
// its height so the board never jumps.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show PowerCard;

import '../../../core/art/art.dart';
import '../../../core/feedback/feedback.dart' show Sfx;
import '../../../core/l10n/tr.dart';
import '../../../core/motion/motion.dart';
import '../../../core/theme/box_paint.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/gloss_button.dart';
import '../../../core/widgets/lm_box.dart';
import '../../../core/widgets/outlined_text.dart';
import '../../../core/widgets/pressable.dart';
import '../match_controller.dart';
import '../mayhem/power_cards.dart';

class HandRow extends StatelessWidget {
  const HandRow({super.key, required this.c});

  final MatchController c;

  /// Room the row takes (chip 56 + the lift of a selected card).
  static const double height = 64;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) {
      final hand = c.hand;
      final sel = c.cards.selected;
      final usable = sel != null && c.cardPlayable(sel);
      final label = sel == null
          ? tr('PICK A CARD')
          : c.cards.targeting
          ? tr('CANCEL')
          : tr('USE {card}', {'card': cardName(sel)});
      return SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: hand.isEmpty
              ? Center(
                  child: Text(
                    tr('No cards — land on a purple power tile to draw one.'),
                    textAlign: TextAlign.center,
                    style: LmText.bodyAt(12, color: LmColors.textPale, height: 1.3),
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final card in hand) ...[_Chip(c: c, card: card), const SizedBox(width: 8)],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GlossButton(
                          onTap: usable ? c.useSelectedCard : null,
                          kind: c.cards.targeting ? GlossKind.red : (usable ? GlossKind.green : GlossKind.dim),
                          size: GlossSize.m,
                          label: label,
                          expand: true,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    },
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.c, required this.card});

  final MatchController c;
  final PowerCard card;

  @override
  Widget build(BuildContext context) {
    final look = cardLook(card);
    final on = c.cards.selected == card;
    final playable = c.cardPlayable(card);
    return Semantics(
      button: true,
      selected: on,
      enabled: playable,
      label: '${cardName(card)}. ${cardText(card)}',
      excludeSemantics: true,
      child: Pressable(
        onTap: playable ? () => c.selectCard(card) : null,
        sfx: Sfx.card,
        child: AnimatedSlide(
          duration: Motion.of(context, Motion.quick),
          curve: Motion.popCurve,
          offset: Offset(0, on ? -.14 : 0),
          child: Opacity(
            opacity: playable ? 1 : .55,
            child: LmBox(
              radius: 16,
              width: 96,
              height: 52,
              gradient: look.gradient,
              shadows: [
                LmShadow(LmColors.white.withValues(alpha: .4), spread: 0, dy: 3, inset: true),
                LmShadow(look.edge, dy: 4),
                if (on) const LmShadow.rim(LmColors.xpText, 3),
              ],
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  LmBox(
                    radius: 15,
                    width: 30,
                    height: 30,
                    color: LmColors.white.withValues(alpha: .25),
                    child: Center(child: LmIcon(cardGlyph(card), size: 18)),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedText(cardName(card), size: 13, height: 1.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
