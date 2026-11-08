// SaveController · rewards: daily gift, free coins, the ad ladder, the lucky
// wheel, missions, Mela pots, the daily puzzle.
//
// How an ad reward works: the screen asks `AdService.showRewarded(kind: …)` first
// (it checks Parent controls, the day caps and the 30 s spacing, and counts the ad
// only when it is EARNED); when that returns true the screen calls the matching
// method here to PAY — `collectLadderStep`, `collectExtraAd`, `claimGift(doubled:
// true)`, `spinWheel(SpinMethod.ad)`. Nothing here counts the ad a second time.
// Every method is one all-or-nothing step (`transact`): null / false means nothing
// changed. Methods that pay return an [Outcome] — the reward, what the grant really
// did (duplicates, queued pots, unlocked items) and any achievements it unlocked.

import '../domain/ad_pacing.dart';
import '../domain/daily_gift.dart';
import '../domain/economy_rules.dart';
import '../domain/free_rewards.dart';
import '../domain/grant.dart';
import '../domain/grant_apply.dart';
import '../domain/pots.dart';
import '../domain/wheel.dart';
import 'save_core.dart';

mixin RewardActions on SaveCore {
  /// Brings the active profile up to today (missions rolled over, yesterday's
  /// unclaimed rewards paid) and saves the time its timers have seen pass. Call it
  /// when the app opens or resumes.
  void syncDaily() {
    final m = moment;
    final synced = syncDay(state.activeProfile, m);
    final d = synced.daily;
    updateActiveProfile((_) => synced.copyWith(daily: d.copyWith(gift: d.gift.advance(m), pots: d.pots.advance(m))));
  }

  // ── Daily gift ─────────────────────────────────────────────────────────

  /// Claims the daily gift (null when it is not ready). Pass `doubled: true` only
  /// after the "double it" ad was earned. The ready time for the reminder is
  /// `giftStatusProvider.readyAt` afterwards.
  Outcome<GiftClaim>? claimGift({bool doubled = false}) => transact<GiftClaim>((p, m) {
    final r = p.daily.gift.claim(m, doubled: doubled);
    if (r == null) return null;
    final base = p.copyWith(
      daily: p.daily.copyWith(gift: r.$1),
      progress: p.progress.copyWith(giftsClaimed: p.progress.giftsClaimed + 1),
    );
    final (paid, receipt) = applyGrant(base, r.$2.grant);
    return (paid, r.$2, receipt);
  });

  // ── Free rewards ───────────────────────────────────────────────────────

  /// Collects +150 coins (null when the 4 h wait is not over).
  Outcome<int>? collectFreeCoins() => transact<int>((p, m) {
    final next = p.daily.free.collectCoins(m);
    if (next == null) return null;
    final (paid, receipt) = applyGrant(
      p.copyWith(daily: p.daily.copyWith(free: next)),
      const Grant(coins: EconomyRules.freeCoins),
    );
    return (paid, EconomyRules.freeCoins, receipt);
  });

  /// Pays ladder step [index] (0–3) after its ad was earned. Only the next step
  /// can be taken; the ladder starts over at local midnight.
  Outcome<Grant>? collectLadderStep(int index) => transact<Grant>((p, m) {
    final next = p.daily.free.completeStep(index, m.day);
    if (next == null) return null;
    final grant = FreeRewards.ladder[index].grant;
    final (paid, receipt) = applyGrant(p.copyWith(daily: p.daily.copyWith(free: next)), grant);
    return (paid, grant, receipt);
  });

  /// Pays an "extra" reward ad: +250 coins ([RewardAdKind.coins]) or +3 gems
  /// ([RewardAdKind.gems]); null for any other kind.
  Outcome<Grant>? collectExtraAd(RewardAdKind kind) {
    final grant = switch (kind) {
      RewardAdKind.coins => const Grant(coins: EconomyRules.extraCoinAd),
      RewardAdKind.gems => const Grant(gems: EconomyRules.extraGemAd),
      RewardAdKind.other => null,
    };
    if (grant == null) return null;
    return transact<Grant>((p, m) {
      final (paid, receipt) = applyGrant(p, grant);
      return (paid, grant, receipt);
    });
  }

  // ── Lucky wheel ────────────────────────────────────────────────────────

  /// Spins the wheel with [method] (null when that spin is not available, or the
  /// 10 gems of a gem spin are missing). For [SpinMethod.ad] earn the ad first.
  Outcome<SpinResult>? spinWheel(SpinMethod method) => transact<SpinResult>((p, m) {
    final used = p.daily.wheel.use(method, m);
    if (used == null) return null;
    var wallet = p.wallet;
    if (method == SpinMethod.gems) {
      final paid = wallet.spend(gems: EconomyRules.wheelGemSpinCost);
      if (paid == null) return null;
      wallet = paid;
    }
    final result = Wheel.resolve(Wheel.draw(rng), p.collection, rng);
    final (paid, receipt) = applyGrant(p.copyWith(wallet: wallet, daily: p.daily.copyWith(wheel: used)), result.grant);
    return (paid, result, receipt);
  });

  // ── Missions ───────────────────────────────────────────────────────────

  /// Claims a finished mission: its coins, and its points count toward the milestones.
  Outcome<Grant>? claimMission(int index) => transact<Grant>((p, m) {
    final r = p.daily.missions.claim(index);
    if (r == null) return null;
    final (paid, receipt) = applyGrant(p.copyWith(daily: p.daily.copyWith(missions: r.$1)), r.$2);
    return (paid, r.$2, receipt);
  });

  /// Collects the milestone at [at] points (25 / 50 / 75 / 100).
  Outcome<Grant>? claimMilestone(int at) => transact<Grant>((p, m) {
    final r = p.daily.missions.claimMilestone(at);
    if (r == null) return null;
    final (paid, receipt) = applyGrant(p.copyWith(daily: p.daily.copyWith(missions: r.$1)), r.$2);
    return (paid, r.$2, receipt);
  });

  /// The one free swap of the day: replaces the unfinished mission [index].
  bool swapMission(int index) =>
      transact<bool>((p, m) {
        final next = p.daily.missions.swap(index, rng.nextInt(1 << 30));
        if (next == null) return null;
        return (p.copyWith(daily: p.daily.copyWith(missions: next)), true, const GrantReceipt());
      }) !=
      null;

  // ── Mela pots ──────────────────────────────────────────────────────────

  /// Starts slot [slot]'s countdown (only one runs at a time).
  bool startPot(int slot) =>
      _validSlot(slot) &&
      transact<bool>((p, m) {
            final next = p.daily.pots.advance(m).start(slot, m);
            if (next == null) return null;
            return (p.copyWith(daily: p.daily.copyWith(pots: next)), true, const GrantReceipt());
          }) !=
          null;

  /// Opens slot [slot] right now for 1 gem per 20 minutes left (false when empty,
  /// already ready, or the gems are missing).
  bool skipPot(int slot) =>
      _validSlot(slot) &&
      transact<bool>((p, m) {
            final shelf = p.daily.pots;
            final cost = shelf.skipCost(slot, m);
            final next = shelf.skip(slot, m);
            final paid = p.wallet.spend(gems: cost);
            if (next == null || paid == null) return null;
            return (p.copyWith(wallet: paid, daily: p.daily.copyWith(pots: next)), true, const GrantReceipt());
          }) !=
          null;

  /// Opens the ready pot in slot [slot] and pays what is inside.
  Outcome<PotOpening>? openPot(int slot) {
    if (!_validSlot(slot)) return null;
    return transact<PotOpening>((p, m) {
      final taken = p.daily.pots.take(slot, m);
      if (taken == null) return null;
      final grant = PotTable.open(taken.$2, collection: p.collection, level: p.level, rng: rng);
      final base = p.copyWith(
        daily: p.daily.copyWith(pots: taken.$1),
        progress: p.progress.copyWith(potsOpened: p.progress.potsOpened + 1),
      );
      final (paid, receipt) = applyGrant(base, grant);
      return (paid, PotOpening(taken.$2, grant), receipt);
    });
  }

  bool _validSlot(int slot) => slot >= 0 && slot < PotShelf.slotCount;

  // ── Daily puzzle ───────────────────────────────────────────────────────

  /// The daily puzzle was solved: +100 coins the first time each day, the streak
  /// grows and the "Solve today's puzzle" mission advances. Null when it was already
  /// solved today.
  Outcome<Grant>? puzzleSolved() => transact<Grant>((p, m) {
    final (puzzle, first) = p.progress.puzzle.solve(m.day);
    if (!first) return null;
    const grant = Grant(coins: EconomyRules.puzzleCoins);
    final base = p.copyWith(
      progress: p.progress.copyWith(puzzle: puzzle),
      daily: p.daily.copyWith(missions: p.daily.missions.applyPuzzleSolved()),
    );
    final (paid, receipt) = applyGrant(base, grant);
    return (paid, grant, receipt);
  });
}
