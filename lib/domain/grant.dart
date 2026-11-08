// A reward as a plain value (a "grant").
//
// Why: the daily gift, ladder, wheel, missions, pots, Mela Road, cup and
// achievements all pay out the same few things — coins, gems, a wheel spin, a pot
// for the shelf, a free item, item shards. Each source builds a [Grant]; ONE
// function (grant_apply.dart) puts it into a profile, so duplicates, a full pot
// shelf and shard unlocks are handled in one place and every screen can show
// "what you got" from the same value.

import 'pot_tier.dart';

final class Grant {
  const Grant({
    this.coins = 0,
    this.gems = 0,
    this.spins = 0,
    this.pots = const [],
    this.items = const [],
    this.shards = const {},
  });

  static const none = Grant();

  final int coins;
  final int gems;

  /// Extra free wheel spins.
  final int spins;

  /// Pots for the shelf (waiting in a queue when the shelf is full).
  final List<PotTier> pots;

  /// Catalog item ids handed over for free (an owned one becomes coins).
  final List<String> items;

  /// Item id → shards.
  final Map<String, int> shards;

  bool get isEmpty => coins == 0 && gems == 0 && spins == 0 && pots.isEmpty && items.isEmpty && shards.isEmpty;

  Grant operator +(Grant o) {
    final merged = Map<String, int>.of(shards);
    o.shards.forEach((k, v) => merged[k] = (merged[k] ?? 0) + v);
    return Grant(
      coins: coins + o.coins,
      gems: gems + o.gems,
      spins: spins + o.spins,
      pots: [...pots, ...o.pots],
      items: [...items, ...o.items],
      shards: merged,
    );
  }

  /// Every amount multiplied by [k] ("watch an ad to double it"). Items stay single.
  Grant times(int k) => Grant(
    coins: coins * k,
    gems: gems * k,
    spins: spins * k,
    pots: [for (var i = 0; i < k; i++) ...pots],
    items: items,
    shards: {for (final e in shards.entries) e.key: e.value * k},
  );

  @override
  String toString() => 'Grant(coins: $coins, gems: $gems, spins: $spins, pots: $pots, items: $items, shards: $shards)';
}
