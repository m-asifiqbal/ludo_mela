// The kinds of Mela pot (board C · "Mela pots"): clay 3 h, silver 8 h, gold 12 h,
// plus the Epic pot of the Mela Road and the festive Mela pot of the daily gift.
//
// Kept apart from the shelf logic (pots.dart) because rewards of every kind
// (a [Grant]) name a tier, and the shelf needs rewards to describe its contents.

import '../core/l10n/tr.dart';

enum PotTier {
  clay('Clay pot', Duration(hours: 3)),
  silver('Silver pot', Duration(hours: 8)),
  gold('Gold pot', Duration(hours: 12)),

  /// Road reward at level 10: drawn with the gold pot art.
  epic('Epic pot', Duration(hours: 12)),

  /// The festive pot (daily gift day 7, board "Daily gift"): exactly 1,500 coins + 15 gems + a Rare
  /// item you do not own yet.
  mela('Mela pot', Duration(hours: 12));

  const PotTier(this.label, this.duration);

  /// English name (translate with [title]).
  final String label;

  /// How long its countdown runs once started.
  final Duration duration;

  String get title => tr(label);

  /// A stored tier name, or null.
  static PotTier? byName(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}
