// RulesDialog: the short rules of the mode being played, opened from the pause menu (board B · GameRules).
//
// A pop-up with the lines every game shares (a 6 brings a piece out and rolls again, three 6s end the turn, a
// capture sends a rival to its yard, the exact number is needed for home) and what is special about this mode.
// Quick shows its real target (`Rules.quickTarget`), so the text never disagrees with the game.

import 'package:flutter/widgets.dart';
import 'package:ludo_engine/ludo_engine.dart' show GameMode, Rules;

import '../../../core/l10n/tr.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text.dart';
import '../../../core/widgets/mela_dialog.dart';
import '../../../core/widgets/ribbon_banner.dart';
import '../mode_name.dart';

/// The lines of the rules for [mode] (English text through tr).
List<String> rulesFor(GameMode mode, Rules rules) => [
  switch (mode) {
    GameMode.classic => tr('Bring all four of your pieces home first.'),
    GameMode.quick => tr('Pieces start on the board. The first {n, plural, one {piece} other {# pieces}} home wins.', {'n': rules.quickTarget}),
    GameMode.master => tr('Capture once before any piece may turn into your home lane. Two pieces on one square form a blockade nobody can pass.'),
    GameMode.rush => tr('Five minutes on the clock, points decide: +1 per square, +20 per capture, −10 when captured, +50 per piece home.'),
    GameMode.mayhem => tr('Arrow tiles zip you 4 squares ahead. Power tiles draw a card: hold two, play one per turn. Chests pay coins if you finish. Mela events change the rules for 2 rounds.'),
    GameMode.teams => tr('Partners sit opposite and win together. When you finish, you roll for your partner.'),
  },
  if (mode != GameMode.quick && mode != GameMode.rush) tr('A 6 brings a piece out. A 6, a capture or a piece reaching home gives one more roll.'),
  tr('Three 6s in a row: the turn ends and the third move is not played.'),
  tr('Landing on a rival outside a star or start square sends it back to its yard.'),
  tr('You need the exact number to reach home. No legal move: the turn passes.'),
];

/// Opens the rules pop-up for [mode].
Future<void> showRulesDialog(BuildContext context, GameMode mode, [Rules rules = const Rules()]) => showMelaDialog<void>(
  context,
  title: tr('RULES'),
  tone: RibbonTone.blue,
  builder: (context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(modeName(mode), style: LmText.outlined(18, color: LmColors.xpText)),
      const SizedBox(height: 8),
      for (final line in rulesFor(mode, rules))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: LmText.bodyAt(13.5, color: LmColors.xpText)),
              Expanded(child: Text(line, style: LmText.bodyAt(13.5, color: LmColors.textPale, height: 1.35))),
            ],
          ),
        ),
    ],
  ),
);
