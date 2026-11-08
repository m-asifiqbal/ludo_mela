// One profile's Collection: what it owns, what it uses, upgrade levels, shards.
//
// Everything here is a pure function from one [Collection] (+ a [Wallet]) to the
// next, so the Collection screen, the try-on pop-up, pots, the wheel and the Mela
// Road all change it the same way. Rules (board C):
//   * the starters (Mela Classic, Lotus Coins, Mela Wood) are owned from day one;
//   * coins buy Standard and Rare items, gems buy Epic ones, shards unlock the
//     shard items automatically when the last shard arrives, Mela Road and event
//     items are only ever handed over;
//   * a coin upgrade (max level 5) raises cosmetics and the XP boost — never the dice;
//   * an item you already own can't be bought again.

import '../core/l10n/tr.dart';
import 'catalog.dart';
import 'economy_rules.dart';
import 'json_read.dart';
import 'wallet.dart';

/// What a card shows for an item (drives its button on the Collection screen).
enum ItemState {
  /// The one in use (for pieces: "Select colour").
  using,

  /// Owned, tap to use.
  owned,

  /// Buy with coins.
  buyCoins,

  /// Unlock with gems.
  buyGems,

  /// Collect shards (the bar shows have / need).
  shards,

  /// Arrives at a Mela Road level (the button shows it).
  road,

  /// Earn-only (event, Mela Cup).
  event,

  /// Would be buyable but the player level is too low.
  locked,
}

/// Why a purchase or upgrade did not happen.
enum PurchaseBlock { none, unknownItem, owned, notOwned, notForSale, levelTooLow, cannotAfford, maxLevel }

/// The result of a purchase or upgrade: the new wallet and collection, or the reason.
final class Purchase {
  const Purchase.ok(Wallet this.wallet, Collection this.collection) : block = PurchaseBlock.none;
  const Purchase.blocked(this.block) : wallet = null, collection = null;

  final PurchaseBlock block;
  final Wallet? wallet;
  final Collection? collection;

  bool get ok => block == PurchaseBlock.none;
}

final class Collection {
  const Collection({
    this.owned = Catalog.starterIds,
    this.selected = const {ItemKind.dice: 'mela_classic', ItemKind.piece: 'lotus', ItemKind.board: 'mela_wood'},
    this.levels = const {},
    this.shards = const {},
    this.unseen = const {},
  });

  /// Item ids owned.
  final Set<String> owned;

  /// The id in use per kind.
  final Map<ItemKind, String> selected;

  /// Upgrade level per owned item (absent = 1).
  final Map<String, int> levels;

  /// Shards collected per item.
  final Map<String, int> shards;

  /// Owned items the player has not looked at yet (the "NEW" badge on the tabs).
  final Set<String> unseen;

  bool owns(String id) => owned.contains(id);

  int levelOf(String id) => (levels[id] ?? 1).clamp(1, EconomyRules.maxItemLevel);

  int shardsOf(String id) => shards[id] ?? 0;

  String selectedId(ItemKind kind) {
    final id = selected[kind];
    return id != null && owns(id) && Catalog.byId(id)?.kind == kind ? id : Catalog.starter(kind).id;
  }

  CatalogItem selectedItem(ItemKind kind) => Catalog.byId(selectedId(kind)) ?? Catalog.starter(kind);

  /// How many owned items of [kind] have not been looked at.
  int newCount(ItemKind kind) => unseen.where((id) => Catalog.byId(id)?.kind == kind).length;

  /// The state of [item] for a player at [playerLevel].
  ItemState stateOf(CatalogItem item, int playerLevel) {
    if (selectedId(item.kind) == item.id) return ItemState.using;
    if (owns(item.id)) return ItemState.owned;
    return switch (item.price.kind) {
      PriceKind.free => ItemState.owned,
      PriceKind.coins => playerLevel < item.unlockLevel ? ItemState.locked : ItemState.buyCoins,
      PriceKind.gems => playerLevel < item.unlockLevel ? ItemState.locked : ItemState.buyGems,
      PriceKind.shards => ItemState.shards,
      PriceKind.road => ItemState.road,
      PriceKind.event => ItemState.event,
    };
  }

  /// XP-boost steps of [item] at upgrade [level] (+1 step per two upgrades, max 3).
  static int boostSteps(CatalogItem item, int level) => (item.stats.xpBoost + (level - 1) ~/ 2).clamp(0, 3);

  /// Total XP boost of what is in use, in percent (max 45).
  int get xpBoostPercent {
    var steps = 0;
    for (final kind in ItemKind.values) {
      final item = selectedItem(kind);
      steps += boostSteps(item, levelOf(item.id));
    }
    return steps * EconomyRules.xpBoostStepPercent;
  }

  /// Own [id] (level 1). Already owned or unknown ids change nothing.
  Collection withItem(String id) {
    if (owns(id) || Catalog.byId(id) == null) return this;
    return _copy(owned: {...owned, id}, unseen: {...unseen, id}, shards: {...shards}..remove(id));
  }

  /// Use [id] (it must be owned).
  Collection select(String id) {
    final item = Catalog.byId(id);
    if (item == null || !owns(id)) return this;
    return _copy(selected: {...selected, item.kind: id});
  }

  /// The tab of [kind] was looked at: clears its NEW badges.
  Collection markSeen(ItemKind kind) =>
      _copy(unseen: {
        for (final id in unseen)
          if (Catalog.byId(id)?.kind != kind) id,
      });

  /// Adds [n] shards of [id]; reaching its price unlocks it ([unlocked] true).
  (Collection, bool unlocked) addShards(String id, int n) {
    final item = Catalog.byId(id);
    if (item == null || n <= 0 || owns(id)) return (this, false);
    final total = shardsOf(id) + n;
    if (item.shardsNeeded > 0 && total >= item.shardsNeeded) return (withItem(id), true);
    return (_copy(shards: {...shards, id: total}), false);
  }

  /// Buy [id] with coins or gems at [level].
  Purchase buy(String id, {required int level, required Wallet wallet}) {
    final item = Catalog.byId(id);
    if (item == null) return const Purchase.blocked(PurchaseBlock.unknownItem);
    if (owns(id)) return const Purchase.blocked(PurchaseBlock.owned);
    final coins = item.price.kind == PriceKind.coins ? item.price.amount : 0;
    final gems = item.price.kind == PriceKind.gems ? item.price.amount : 0;
    if (coins == 0 && gems == 0) return const Purchase.blocked(PurchaseBlock.notForSale);
    if (level < item.unlockLevel) return const Purchase.blocked(PurchaseBlock.levelTooLow);
    final paid = wallet.spend(coins: coins, gems: gems);
    if (paid == null) return const Purchase.blocked(PurchaseBlock.cannotAfford);
    return Purchase.ok(paid, withItem(id));
  }

  /// Coins for the next upgrade of [id], or null (not owned / max level).
  int? upgradeCostOf(String id) {
    final item = Catalog.byId(id);
    if (item == null || !owns(id) || levelOf(id) >= EconomyRules.maxItemLevel) return null;
    return item.upgradeCost(levelOf(id));
  }

  /// Raise [id] one level for coins.
  Purchase upgrade(String id, Wallet wallet) {
    if (Catalog.byId(id) == null) return const Purchase.blocked(PurchaseBlock.unknownItem);
    if (!owns(id)) return const Purchase.blocked(PurchaseBlock.notOwned);
    final cost = upgradeCostOf(id);
    if (cost == null) return const Purchase.blocked(PurchaseBlock.maxLevel);
    final paid = wallet.spend(coins: cost);
    if (paid == null) return const Purchase.blocked(PurchaseBlock.cannotAfford);
    return Purchase.ok(paid, _copy(levels: {...levels, id: levelOf(id) + 1}));
  }

  Collection _copy({
    Set<String>? owned,
    Map<ItemKind, String>? selected,
    Map<String, int>? levels,
    Map<String, int>? shards,
    Set<String>? unseen,
  }) => Collection(
    owned: owned ?? this.owned,
    selected: selected ?? this.selected,
    levels: levels ?? this.levels,
    shards: shards ?? this.shards,
    unseen: unseen ?? this.unseen,
  );

  Map<String, Object?> toJson() => {
    'owned': owned.toList()..sort(),
    'selected': {for (final e in selected.entries) e.key.name: e.value},
    'levels': levels,
    'shards': shards,
    'unseen': unseen.toList()..sort(),
  };

  /// Any stored value loads: starters are always owned, a selection must be an
  /// owned item of its kind, bad numbers are dropped.
  factory Collection.fromJson(Map<String, Object?> j) {
    final ownedIds = <String>{
      ...Catalog.starterIds,
      for (final v in j.listOf('owned'))
        if (v is String && v.isNotEmpty) v,
    };
    final selected = <ItemKind, String>{};
    j.mapOf('selected').forEach((k, v) {
      final kind = ItemKind.byName(k);
      if (kind != null && v is String && ownedIds.contains(v) && Catalog.byId(v)?.kind == kind) selected[kind] = v;
    });
    Map<String, int> counts(String key, int min, int max) => {
      for (final e in j.mapOf(key).entries)
        if (e.value case final int n when n >= min) e.key: n.clamp(min, max),
    };
    return Collection(
      owned: ownedIds,
      selected: {for (final k in ItemKind.values) k: selected[k] ?? Catalog.starter(k).id},
      levels: counts('levels', 1, EconomyRules.maxItemLevel),
      shards: counts('shards', 1, 1 << 30),
      unseen: {
        for (final v in j.listOf('unseen'))
          if (v is String && ownedIds.contains(v)) v,
      },
    );
  }
}

/// The item's name in the active language.
String itemTitle(CatalogItem item) => tr(item.name);
