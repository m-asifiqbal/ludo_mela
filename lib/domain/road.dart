// Mela Road: one reward for every level (board MelaRoad + C · "XP, levels & Mela Road").
//
//   • venues open at levels 3, 6, 9, 12, 16, 20, 25 (shown on the Road, nothing to claim);
//   • Rare / Epic / Legendary items arrive at fixed levels (the Collection's
//     "Road Lv N" buttons: Midnight Gold 18, Monsoon Garden 22, Peacock Fan 30 …);
//   • the rest follows a cycle: coins, gems every 5th-plus-2, a silver pot every 5th
//     level and a gold pot every 10th — for any level, so the road never ends.
//
// A level's reward becomes claimable the moment the level is reached and stays
// until claimed. Pure Dart.

import 'grant.dart';
import 'json_read.dart';
import 'pot_tier.dart';

final class RoadReward {
  const RoadReward(this.level, {this.coins = 0, this.gems = 0, this.pot, this.itemId, this.venueId});

  final int level;
  final int coins;
  final int gems;
  final PotTier? pot;

  /// A catalog item handed over for free.
  final String? itemId;

  /// The venue that opens at this level (informational).
  final String? venueId;

  /// Nothing to collect: a venue opening (or level 1).
  bool get isInformational => coins == 0 && gems == 0 && pot == null && itemId == null;

  Grant get grant => Grant(
    coins: coins,
    gems: gems,
    pots: pot == null ? const [] : [pot!],
    items: itemId == null ? const [] : [itemId!],
  );
}

abstract final class MelaRoad {
  /// The levels the design draws; later levels follow the same cycle.
  static const lastDesigned = 50;

  static const Map<int, RoadReward> _special = {
    3: RoadReward(3, venueId: 'lantern_bazaar'),
    4: RoadReward(4, pot: PotTier.clay),
    6: RoadReward(6, coins: 500, venueId: 'monsoon_garden'),
    8: RoadReward(8, itemId: 'moon'),
    9: RoadReward(9, venueId: 'desert_carnival'),
    10: RoadReward(10, pot: PotTier.epic),
    11: RoadReward(11, gems: 10),
    12: RoadReward(12, venueId: 'royal_palace'),
    14: RoadReward(14, itemId: 'ocean_glass'),
    15: RoadReward(15, itemId: 'night_bazaar'),
    16: RoadReward(16, venueId: 'ocean_pier'),
    18: RoadReward(18, itemId: 'midnight_gold'),
    20: RoadReward(20, venueId: 'snow_festival'),
    22: RoadReward(22, itemId: 'monsoon_garden'),
    24: RoadReward(24, itemId: 'diya'),
    25: RoadReward(25, venueId: 'neon_city'),
    28: RoadReward(28, itemId: 'gold_mohur'),
    30: RoadReward(30, itemId: 'peacock'),
    33: RoadReward(33, itemId: 'marble_palace'),
    36: RoadReward(36, itemId: 'crown'),
    40: RoadReward(40, itemId: 'peacock_royal'),
    45: RoadReward(45, itemId: 'royal_durbar'),
    50: RoadReward(50, coins: 5000, gems: 50, pot: PotTier.gold),
  };

  /// The reward of [level] (level 1 has none).
  static RoadReward rewardFor(int level) {
    if (level < 2) return RoadReward(level);
    final special = _special[level];
    if (special != null) return special;
    if (level % 10 == 0) return RoadReward(level, pot: PotTier.gold);
    if (level % 5 == 0) return RoadReward(level, pot: PotTier.silver);
    if (level % 5 == 2) return RoadReward(level, gems: 5 + 5 * (level ~/ 10));
    return RoadReward(level, coins: 200 + 50 * level);
  }

  /// The rewards of levels 2 … [level].
  static List<RoadReward> upTo(int level) => [for (var l = 2; l <= level; l++) rewardFor(l)];
}

/// Which Road rewards a profile has collected.
final class RoadState {
  const RoadState([this.claimed = const {}]);

  final Set<int> claimed;

  /// Informational levels count as collected.
  bool isClaimed(int level) => claimed.contains(level) || MelaRoad.rewardFor(level).isInformational;

  /// Levels up to [level] whose reward waits to be collected.
  List<int> claimable(int level) => [
    for (var l = 2; l <= level; l++)
      if (!isClaimed(l)) l,
  ];

  RoadState claim(int level) => RoadState({...claimed, level});

  Map<String, Object?> toJson() => {'claimed': claimed.toList()..sort()};

  factory RoadState.fromJson(Map<String, Object?> j) => RoadState({
    for (final v in j.listOf('claimed'))
      if (v is int && v >= 2) v,
  });
}
