// Mela Tour venues (board C · Economy, board Venues): eight tables against the
// computer, each with its own board, a level gate, an entry fee and prizes.
//
//   2 players   1st wins 2 × entry
//   3 players   1st 2 × entry, 2nd gets the entry back
//   4 players   1st 3 × entry, 2nd gets the entry back
// Every table is a fair bet (the average prize equals the entry); the house never
// takes a cut and nothing is ever sold. Practice (no venue) is free and gives XP
// only. A match is entered with `SaveController.payEntry`, which refuses below
// the level gate, when the wallet can't pay, or when Parent controls switched the
// coin tables off.
//
// Names are English literals translated where shown, listed in static_keys.dart.

import 'pot_tier.dart';

final class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.boardName,
    required this.boardSkinId,
    required this.minLevel,
    required this.entry,
    required this.potTier,
  });

  final String id;

  /// English name ("Village Haat").
  final String name;

  /// English name of its board ("Classic Wood").
  final String boardName;

  /// The `BoardSkins` id the match is drawn on.
  final String boardSkinId;

  /// Player level that opens it.
  final int minLevel;

  /// Coins to sit down.
  final int entry;

  /// The pot a win fills the shelf with.
  final PotTier potTier;

  int get prize2 => entry * 2;
  int get prize4First => entry * 3;
  int get prize4Second => entry;

  /// Coins paid out for finishing [place] (1-based) at a table of [players].
  int prizeFor(int players, int place) {
    if (place < 1) return 0;
    return switch (players) {
      2 => place == 1 ? prize2 : 0,
      3 => place == 1 ? entry * 2 : (place == 2 ? entry : 0),
      4 => place == 1 ? prize4First : (place == 2 ? prize4Second : 0),
      _ => 0,
    };
  }

  bool isOpenAt(int level) => level >= minLevel;
}

abstract final class Venues {
  static const all = <Venue>[
    Venue(id: 'village_haat', name: 'Village Haat', boardName: 'Classic Wood', boardSkinId: 'mela_wood', minLevel: 1, entry: 100, potTier: PotTier.clay),
    Venue(id: 'lantern_bazaar', name: 'Lantern Bazaar', boardName: 'Lantern Night', boardSkinId: 'lantern_night', minLevel: 3, entry: 500, potTier: PotTier.silver),
    Venue(id: 'monsoon_garden', name: 'Monsoon Garden', boardName: 'Monsoon', boardSkinId: 'monsoon_garden', minLevel: 6, entry: 1000, potTier: PotTier.silver),
    Venue(id: 'desert_carnival', name: 'Desert Carnival', boardName: 'Sandstone', boardSkinId: 'sandstone', minLevel: 9, entry: 2500, potTier: PotTier.silver),
    Venue(id: 'royal_palace', name: 'Royal Palace', boardName: 'Royal', boardSkinId: 'royal_palace', minLevel: 12, entry: 5000, potTier: PotTier.gold),
    Venue(id: 'ocean_pier', name: 'Ocean Pier', boardName: 'Ocean Reef', boardSkinId: 'ocean_reef', minLevel: 16, entry: 8000, potTier: PotTier.gold),
    Venue(id: 'snow_festival', name: 'Snow Festival', boardName: 'Frost', boardSkinId: 'frost', minLevel: 20, entry: 10000, potTier: PotTier.gold),
    Venue(id: 'neon_city', name: 'Neon City', boardName: 'Neon', boardSkinId: 'neon', minLevel: 25, entry: 20000, potTier: PotTier.gold),
  ];

  static Venue? byId(String? id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Venues open at [level], in order.
  static List<Venue> openAt(int level) => [
    for (final v in all)
      if (v.isOpenAt(level)) v,
  ];

  /// The highest venue open at [level] (there is always one).
  static Venue highestOpen(int level) => openAt(level).last;

  /// The venue that opens exactly at [level], if any (Mela Road shows it).
  static Venue? openingAt(int level) {
    for (final v in all) {
      if (v.minLevel == level) return v;
    }
    return null;
  }
}
