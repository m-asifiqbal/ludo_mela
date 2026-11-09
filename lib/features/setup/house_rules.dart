// The six house rules of the setup boards ("House rules" on Pass & play, shared by Game options): their
// words, where they live in `SetupPrefs`, and when a mode or a table settles one of them for the player.
//
// The engine lays the mode's own requirements over the house rules (`Rules.forMode`: Master always has
// blockades, Quick and Rush start with pieces out), and Helping dice are never used at a coin table
// (`MatchSetup.normalized`). A switch the game will not honour is shown as it will really play and is
// disabled with the reason, instead of letting the player flip it to no effect.

import 'package:ludo_engine/ludo_engine.dart' show GameMode;

import '../../core/l10n/tr.dart';
import '../../domain/setup_prefs.dart';

enum HouseRule {
  sixToEnter,
  threeSixes,
  exactHome,
  blockades,
  gentleCaptures,
  helpingDice;

  /// The switch's title ("Need a 6 to leave the yard").
  String get title => switch (this) {
        HouseRule.sixToEnter => tr('Need a 6 to leave the yard'),
        HouseRule.threeSixes => tr('Three 6s in a row lose the turn'),
        HouseRule.exactHome => tr('Exact roll to reach home'),
        HouseRule.blockades => tr('Blockades'),
        HouseRule.gentleCaptures => tr('Gentle captures (kids)'),
        HouseRule.helpingDice => tr('Helping dice'),
      };

  /// What the switch does, in a line.
  String get sub => switch (this) {
        HouseRule.sixToEnter => tr('Off: a 1 or a 6 lets a piece out'),
        HouseRule.threeSixes => tr('Stops endless sixes'),
        HouseRule.exactHome => tr('Off: overshooting still counts'),
        HouseRule.blockades => tr('Two of your pieces on one square block everyone'),
        HouseRule.gentleCaptures => tr('A captured piece steps back 6 squares, not to the yard'),
        HouseRule.helpingDice => tr('Stuck in the yard for 5 rolls? The next roll is a 6 — shown to all'),
      };

  /// The remembered value.
  bool read(SetupPrefs p) => switch (this) {
        HouseRule.sixToEnter => p.sixToEnter,
        HouseRule.threeSixes => p.threeSixesForfeit,
        HouseRule.exactHome => p.exactHome,
        HouseRule.blockades => p.blockades,
        HouseRule.gentleCaptures => p.gentleCaptures,
        HouseRule.helpingDice => p.helpingDice,
      };

  /// [p] with this rule set to [on].
  SetupPrefs write(SetupPrefs p, bool on) => switch (this) {
        HouseRule.sixToEnter => p.copyWith(sixToEnter: on),
        HouseRule.threeSixes => p.copyWith(threeSixesForfeit: on),
        HouseRule.exactHome => p.copyWith(exactHome: on),
        HouseRule.blockades => p.copyWith(blockades: on),
        HouseRule.gentleCaptures => p.copyWith(gentleCaptures: on),
        HouseRule.helpingDice => p.copyWith(helpingDice: on),
      };
}

/// A house rule as the game will play it.
class RuleView {
  const RuleView({required this.value, this.lockNote});

  /// The switch position that will really be played.
  final bool value;

  /// Why the player cannot change it right now (null when they can).
  final String? lockNote;

  bool get locked => lockNote != null;
}

/// How [rule] plays in [mode] ([coinTable]: an entry is paid, so no Helping dice) with the remembered [prefs].
RuleView ruleView(HouseRule rule, SetupPrefs prefs, {required GameMode mode, bool coinTable = false}) {
  final remembered = rule.read(prefs);
  switch (rule) {
    case HouseRule.blockades when mode == GameMode.master:
      return RuleView(value: true, lockNote: tr('Always on in Master'));
    case HouseRule.sixToEnter when mode == GameMode.quick || mode == GameMode.rush:
      return RuleView(value: remembered, lockNote: tr('Pieces start out in this mode'));
    case HouseRule.helpingDice when coinTable:
      return RuleView(value: false, lockNote: tr('Not at coin tables'));
    default:
      return RuleView(value: remembered);
  }
}
