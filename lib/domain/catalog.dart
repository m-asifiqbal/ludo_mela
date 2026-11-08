// The catalog: every dice, piece and board the Collection can hold
// (design boards Collection + C · "Rarity, prices & gates").
//
// An item's [CatalogItem.id] IS its art skin id (core/art: DiceSkins, PieceSkins,
// BoardSkins), so the match screen draws `DiceSkins.byId(item.skin)` and so on.
// Rarity decides the level gate and the price band:
//   Standard  free or 800–1,500 coins          level 1+
//   Rare      3,000–8,000 coins, or shards     level 3+
//   Epic      120–180 gems                     level 10+
//   Legendary shards or the Mela Road only     level 20+
//   Mela      earn-only (events, Mela Cup)
// Stats are bars on the card: two cosmetic ones (0–5) and the XP boost (0–3
// steps of +5 %). Every dice stays a fair 1–6 whatever its stats — upgrades only
// touch cosmetics and the XP boost.
//
// Names are English literals translated where shown (`tr(item.name)`), and are
// listed in static_keys.dart. Pure Dart.

enum ItemKind {
  dice('Dice', ['Roll fx', 'Bounce', 'XP boost']),
  piece('Pieces', ['Hop fx', 'Trail', 'XP boost']),
  board('Boards', ['Ambience', 'Detail', 'XP boost']);

  const ItemKind(this.label, this.statLabels);

  /// Tab label (English).
  final String label;

  /// Labels of the three stat bars (English).
  final List<String> statLabels;

  static ItemKind? byName(Object? name) {
    for (final k in values) {
      if (k.name == name) return k;
    }
    return null;
  }
}

enum Rarity {
  standard('Standard', 1, 800, 500),
  rare('Rare', 3, 1000, 2000),
  epic('Epic', 10, 1600, 4000),
  legendary('Legendary', 20, 2500, 8000),
  mela('Mela', 1, 2000, 3000);

  const Rarity(this.label, this.minLevel, this.upgradeBase, this.duplicateCoins);

  /// English label ("Legendary").
  final String label;

  /// The level from which items of this rarity can be bought.
  final int minLevel;

  /// Coins for the first upgrade; later ones cost more ([CatalogItem.upgradeCost]).
  final int upgradeBase;

  /// What a duplicate of an item of this rarity turns into.
  final int duplicateCoins;
}

/// How an item is acquired.
enum PriceKind { free, coins, gems, shards, road, event }

final class ItemPrice {
  const ItemPrice._(this.kind, this.amount, [this.event]);

  const ItemPrice.free() : this._(PriceKind.free, 0);
  const ItemPrice.coins(int n) : this._(PriceKind.coins, n);
  const ItemPrice.gems(int n) : this._(PriceKind.gems, n);

  /// Collect [n] shards (pots, duplicates).
  const ItemPrice.shards(int n) : this._(PriceKind.shards, n);

  /// Handed over by the Mela Road at [level].
  const ItemPrice.road(int level) : this._(PriceKind.road, level);

  /// Earn-only through [eventId] (a festival, the Mela Cup).
  const ItemPrice.event(String eventId) : this._(PriceKind.event, 0, eventId);

  final PriceKind kind;

  /// Coins, gems or shards needed; the Road level for [PriceKind.road].
  final int amount;
  final String? event;
}

/// The three stat bars of a card.
final class ItemStats {
  const ItemStats(this.a, this.b, this.xpBoost);

  /// First and second cosmetic bar, 0–5.
  final int a, b;

  /// XP-boost steps (+5 % each), 0–3.
  final int xpBoost;
}

final class CatalogItem {
  const CatalogItem(this.id, this.kind, this.name, this.rarity, this.price, this.stats, {this.skinId});

  final String id;
  final ItemKind kind;

  /// English name.
  final String name;
  final Rarity rarity;
  final ItemPrice price;
  final ItemStats stats;

  /// The art skin to draw when it differs from [id].
  final String? skinId;

  String get skin => skinId ?? id;

  /// The player level from which the item can be had.
  int get unlockLevel => switch (price.kind) {
    PriceKind.road => price.amount,
    PriceKind.free || PriceKind.event => 1,
    _ => rarity.minLevel,
  };

  bool get isFree => price.kind == PriceKind.free;
  bool get isEarnOnly => price.kind == PriceKind.event;

  /// Shards that unlock it (0 when it is not a shard item).
  int get shardsNeeded => price.kind == PriceKind.shards ? price.amount : 0;

  /// Coins to raise it from [level] to the next one: base × (level + 1) / 2.
  int upgradeCost(int level) => rarity.upgradeBase * (level + 1) ~/ 2;
}

abstract final class Catalog {
  static const dice = <CatalogItem>[
    CatalogItem('mela_classic', ItemKind.dice, 'Mela Classic', Rarity.standard, ItemPrice.free(), ItemStats(2, 2, 0)),
    CatalogItem('ruby_jelly', ItemKind.dice, 'Ruby Jelly', Rarity.rare, ItemPrice.coins(3000), ItemStats(3, 3, 1)),
    CatalogItem('ocean_glass', ItemKind.dice, 'Ocean Glass', Rarity.rare, ItemPrice.shards(33), ItemStats(3, 4, 1)),
    CatalogItem('gold_mohur', ItemKind.dice, 'Gold Mohur', Rarity.epic, ItemPrice.gems(140), ItemStats(4, 4, 2)),
    CatalogItem('midnight_gold', ItemKind.dice, 'Midnight Gold', Rarity.epic, ItemPrice.road(18), ItemStats(4, 5, 2)),
    CatalogItem('peacock_royal', ItemKind.dice, 'Peacock Royal', Rarity.legendary, ItemPrice.shards(60), ItemStats(5, 5, 3)),
    CatalogItem('mela_lantern', ItemKind.dice, 'Mela Lantern', Rarity.mela, ItemPrice.event('mela_festival'), ItemStats(4, 5, 2)),
  ];

  static const pieces = <CatalogItem>[
    CatalogItem('lotus', ItemKind.piece, 'Lotus Coins', Rarity.standard, ItemPrice.free(), ItemStats(2, 1, 0)),
    CatalogItem('star', ItemKind.piece, 'Star Coins', Rarity.standard, ItemPrice.coins(800), ItemStats(2, 2, 0)),
    CatalogItem('moon', ItemKind.piece, 'Moon Gems', Rarity.rare, ItemPrice.coins(3000), ItemStats(3, 3, 1)),
    CatalogItem('crown', ItemKind.piece, 'Royal Crown', Rarity.epic, ItemPrice.shards(40), ItemStats(4, 4, 2)),
    CatalogItem('diya', ItemKind.piece, 'Diya Lights', Rarity.epic, ItemPrice.gems(160), ItemStats(4, 5, 2)),
    CatalogItem('peacock', ItemKind.piece, 'Peacock Fan', Rarity.legendary, ItemPrice.road(30), ItemStats(5, 5, 3)),
    CatalogItem('elephant', ItemKind.piece, 'Elephant Coins', Rarity.mela, ItemPrice.event('mela_festival'), ItemStats(4, 4, 2)),
    // The Mela Cup reward (3 cups). It has no art of its own yet: drawn with the crown coins.
    CatalogItem('champion', ItemKind.piece, 'Champion Set', Rarity.mela, ItemPrice.event('mela_cup'), ItemStats(5, 5, 3), skinId: 'crown'),
  ];

  static const boards = <CatalogItem>[
    CatalogItem('mela_wood', ItemKind.board, 'Mela Wood', Rarity.standard, ItemPrice.free(), ItemStats(2, 1, 0)),
    CatalogItem('night_bazaar', ItemKind.board, 'Night Bazaar', Rarity.rare, ItemPrice.coins(4000), ItemStats(3, 3, 1)),
    CatalogItem('marble_palace', ItemKind.board, 'Marble Palace', Rarity.rare, ItemPrice.shards(30), ItemStats(3, 2, 1)),
    CatalogItem('royal_palace', ItemKind.board, 'Royal Palace', Rarity.epic, ItemPrice.gems(150), ItemStats(4, 4, 2)),
    CatalogItem('monsoon_garden', ItemKind.board, 'Monsoon Garden', Rarity.epic, ItemPrice.road(22), ItemStats(4, 4, 2)),
    CatalogItem('royal_durbar', ItemKind.board, 'Royal Durbar', Rarity.legendary, ItemPrice.shards(60), ItemStats(5, 5, 3)),
  ];

  static const List<CatalogItem> all = [...dice, ...pieces, ...boards];

  static final Map<String, CatalogItem> _byId = {for (final i in all) i.id: i};

  /// The item with [id], or null (an id from a newer build).
  static CatalogItem? byId(String? id) => _byId[id];

  static List<CatalogItem> ofKind(ItemKind kind) => switch (kind) {
    ItemKind.dice => dice,
    ItemKind.piece => pieces,
    ItemKind.board => boards,
  };

  /// The free item every profile starts with and falls back to.
  static CatalogItem starter(ItemKind kind) => ofKind(kind).first;

  /// Ids every profile owns from the start.
  static const Set<String> starterIds = {'mela_classic', 'lotus', 'mela_wood'};
}
