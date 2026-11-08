// Putting a [Grant] into a profile, and the daily "catch-up" every profile gets
// when a new day is first seen.
//
// One function so every reward path behaves the same:
//   • coins and gems go to the wallet;
//   • an item you already own turns into coins (its rarity's duplicate value);
//   • shards add up, and the last one unlocks the item;
//   • pots go to the shelf, or wait in its queue when it is full (never lost);
//   • wheel spins are added to the bonus spins.
// The result carries a [GrantReceipt] so the screen can say what really happened.

import 'achievements.dart';
import 'catalog.dart';
import 'grant.dart';
import 'guarded_timer.dart';
import 'pot_tier.dart';
import 'pots.dart';
import 'profile.dart';

/// What [applyGrant] actually did.
final class GrantReceipt {
  const GrantReceipt({
    this.coins = 0,
    this.gems = 0,
    this.spins = 0,
    this.itemsGranted = const [],
    this.duplicateCoins = 0,
    this.unlockedByShards = const [],
    this.shelvedPots = const [],
    this.queuedPots = const [],
  });

  /// Coins credited, duplicates included.
  final int coins;
  final int gems;
  final int spins;

  /// New items now owned.
  final List<String> itemsGranted;

  /// Coins paid instead of items already owned (part of [coins]).
  final int duplicateCoins;
  final List<String> unlockedByShards;
  final List<PotTier> shelvedPots;
  final List<PotTier> queuedPots;
}

/// [p] with [g] paid out.
(ProfileData, GrantReceipt) applyGrant(ProfileData p, Grant g) {
  var collection = p.collection;
  var shelf = p.daily.pots;
  var wheel = p.daily.wheel;
  var duplicateCoins = 0;
  final granted = <String>[], unlocked = <String>[];
  final shelved = <PotTier>[], queued = <PotTier>[];

  for (final id in g.items) {
    final item = Catalog.byId(id);
    if (item == null) continue;
    if (collection.owns(id)) {
      duplicateCoins += item.rarity.duplicateCoins;
    } else {
      collection = collection.withItem(id);
      granted.add(id);
    }
  }
  g.shards.forEach((id, n) {
    final (next, done) = collection.addShards(id, n);
    collection = next;
    if (done) unlocked.add(id);
  });
  for (final tier in g.pots) {
    final (next, placement) = shelf.add(tier, queue: true);
    shelf = next;
    (placement.kind == PotPlacementKind.slot ? shelved : queued).add(tier);
  }
  if (g.spins > 0) wheel = wheel.withBonusSpins(g.spins);

  final coins = g.coins + duplicateCoins;
  final next = p.copyWith(
    wallet: p.wallet.add(coins: coins, gems: g.gems),
    collection: collection,
    daily: p.daily.copyWith(pots: shelf, wheel: wheel),
  );
  return (
    next,
    GrantReceipt(
      coins: coins,
      gems: g.gems,
      spins: g.spins,
      itemsGranted: granted,
      duplicateCoins: duplicateCoins,
      unlockedByShards: unlocked,
      shelvedPots: shelved,
      queuedPots: queued,
    ),
  );
}

/// [p] brought up to the day of [m]: today's missions exist, and anything left
/// unclaimed from yesterday has been paid out. Safe to call as often as you like.
ProfileData syncDay(ProfileData p, Moment m) {
  final (missions, paid) = p.daily.missions.rollover(m.day, p.id);
  if (identical(missions, p.daily.missions)) return p;
  final rolled = p.copyWith(daily: p.daily.copyWith(missions: missions));
  return paid.isEmpty ? rolled : applyGrant(rolled, paid).$1;
}

/// What a reward action hands back: its own result, what the grant really did, and
/// any achievements the change unlocked (their gems are already paid).
final class Outcome<T> {
  const Outcome(this.value, [this.receipt = const GrantReceipt(), this.achievements = const []]);

  final T value;
  final GrantReceipt receipt;
  final List<AchievementDef> achievements;
}
