// SaveController · collection, Mela Road, Mela Cup.
//
//   buyItem / selectItem / upgradeItem   the Collection screen and try-on pop-up
//   claimRoadReward / claimAllRoadRewards   the Mela Road (a reward per level)
//   startCupRun / advanceCup / abandonCupRun   the Mela Cup
// Money methods return the reason when they refuse ([PurchaseBlock.none] = done), so
// the screen can say "Not enough gems" or "Reach level 10". The Mela Cup step of a
// finished cup MATCH is taken by `recordMatch` (record.cup = true); [advanceCup] is
// for results that have no match to record (a forfeit) — never call both for one
// match.

import '../domain/collection.dart';
import '../domain/catalog.dart';
import '../domain/cup.dart';
import '../domain/economy_rules.dart';
import '../domain/grant_apply.dart';
import '../domain/road.dart';
import 'save_core.dart';

mixin CollectionActions on SaveCore {
  // ── Collection ─────────────────────────────────────────────────────────

  /// Buys [id] with coins or gems at the profile's level.
  PurchaseBlock buyItem(String id) {
    var block = PurchaseBlock.unknownItem;
    transact<bool>((p, m) {
      final r = p.collection.buy(id, level: p.level, wallet: p.wallet);
      block = r.block;
      if (!r.ok) return null;
      return (p.copyWith(wallet: r.wallet, collection: r.collection), true, const GrantReceipt());
    });
    return block;
  }

  /// Uses [id] (it must be owned). Returns whether it changed.
  bool selectItem(String id) {
    final p = state.activeProfile;
    if (!p.collection.owns(id) || p.collection.selectedId(Catalog.byId(id)!.kind) == id) return false;
    updateActiveProfile((p) => p.copyWith(collection: p.collection.select(id)));
    return true;
  }

  /// Raises [id] one level for coins (cosmetics and XP boost only).
  PurchaseBlock upgradeItem(String id) {
    var block = PurchaseBlock.unknownItem;
    transact<bool>((p, m) {
      final r = p.collection.upgrade(id, p.wallet);
      block = r.block;
      if (!r.ok) return null;
      return (p.copyWith(wallet: r.wallet, collection: r.collection), true, const GrantReceipt());
    });
    return block;
  }

  /// The Collection tab of [kind] was opened: clears its "NEW" badges.
  void markCollectionSeen(ItemKind kind) {
    if (state.activeProfile.collection.newCount(kind) == 0) return;
    updateActiveProfile((p) => p.copyWith(collection: p.collection.markSeen(kind)));
  }

  // ── Mela Road ──────────────────────────────────────────────────────────

  /// Collects the reward of [level] (reached, not collected yet).
  Outcome<RoadReward>? claimRoadReward(int level) => transact<RoadReward>((p, m) {
    if (level < 2 || level > p.level || p.progress.road.isClaimed(level)) return null;
    final reward = MelaRoad.rewardFor(level);
    final base = p.copyWith(progress: p.progress.copyWith(road: p.progress.road.claim(level)));
    final (paid, receipt) = applyGrant(base, reward.grant);
    return (paid, reward, receipt);
  });

  /// Collects every waiting Road reward, in level order.
  List<Outcome<RoadReward>> claimAllRoadRewards() {
    final out = <Outcome<RoadReward>>[];
    for (final level in state.activeProfile.progress.road.claimable(state.activeProfile.level)) {
      final o = claimRoadReward(level);
      if (o != null) out.add(o);
    }
    return out;
  }

  // ── Mela Cup ───────────────────────────────────────────────────────────

  /// Starts a cup run: the first of the day is free, another costs 300 coins (not
  /// when Parent controls closed the coin tables). Null while a run is still going
  /// or when it can't be paid.
  CupRun? startCupRun() =>
      transact<CupRun>((p, m) {
        final cup = p.progress.cup;
        if (cup.hasActiveRun) return null;
        var wallet = p.wallet;
        if (!cup.freeRunAvailable(m.day)) {
          if (state.settings.parentCoinTablesOff) return null;
          final paid = wallet.spend(coins: EconomyRules.cupExtraRunCoins);
          if (paid == null) return null;
          wallet = paid;
        }
        final started = cup.start(today: m.day, seed: rng.nextInt(1 << 30));
        if (started == null) return null;
        return (p.copyWith(wallet: wallet, progress: p.progress.copyWith(cup: started.$1)), started.$2, const GrantReceipt());
      })?.value;

  /// The player's cup round ended without a recorded match: [won] moves on (or
  /// crowns the champion), a loss ends the run.
  Outcome<CupAdvance>? advanceCup({required bool won}) => transact<CupAdvance>((p, m) {
    final step = p.progress.cup.advance(playerWon: won);
    if (step == null) return null;
    final base = p.copyWith(progress: p.progress.copyWith(cup: step.state));
    final (paid, receipt) = applyGrant(base, step.grant);
    return (paid, step, receipt);
  });

  /// Gives the current run up (no penalty; the free run of the day stays used).
  void abandonCupRun() {
    if (!state.activeProfile.progress.cup.hasActiveRun) return;
    updateActiveProfile((p) => p.copyWith(progress: p.progress.copyWith(cup: p.progress.cup.abandon())));
  }
}
