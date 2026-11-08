// Riverpod providers for the economy: one per thing a screen shows.
//
// Two kinds:
//   • slices of the active profile (`collectionProvider`, `statsProvider` …) that
//     rebuild only when that slice changes;
//   • time-driven views (`giftStatusProvider`, `potViewsProvider` …) that also
//     rebuild once a second while something watches them (`momentProvider`), so a
//     countdown ticks without the screen owning a timer; when nothing watches they
//     are disposed and the timer stops.
// Views are computed from the saved state + the clock — nothing is saved by
// reading. Methods that change things are on `SaveController` (`saveProvider.notifier`).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/achievements.dart';
import '../domain/ad_pacing.dart';
import '../domain/catalog.dart';
import '../domain/collection.dart';
import '../domain/cup.dart';
import '../domain/daily_gift.dart';
import '../domain/free_rewards.dart';
import '../domain/guarded_timer.dart';
import '../domain/insights.dart';
import '../domain/missions.dart';
import '../domain/play_log.dart';
import '../domain/player_stats.dart';
import '../domain/pots.dart';
import '../domain/profile_state.dart';
import '../domain/puzzle_streak.dart';
import '../domain/road.dart';
import '../domain/venues.dart';
import '../domain/wheel.dart';
import 'save_controller.dart';

// ── Time ─────────────────────────────────────────────────────────────────

/// Emits once a second while watched.
final secondTickProvider = StreamProvider.autoDispose<int>((ref) => Stream.periodic(const Duration(seconds: 1), (i) => i));

/// The clocks, refreshed every second while watched.
final momentProvider = Provider.autoDispose<Moment>((ref) {
  ref.watch(secondTickProvider);
  return Moment(ref.read(clockProvider)(), ref.read(uptimeProvider)());
});

/// Today's calendar day (`yyyy-MM-dd`); changes at local midnight.
final todayProvider = Provider.autoDispose<String>((ref) => ref.watch(momentProvider.select((m) => m.day)));

// ── Slices of the active profile ─────────────────────────────────────────

final collectionProvider = Provider<Collection>((ref) => ref.watch(activeProfileProvider.select((p) => p.collection)));
final progressProvider = Provider<Progress>((ref) => ref.watch(activeProfileProvider.select((p) => p.progress)));
final dailyProvider = Provider<DailyState>((ref) => ref.watch(activeProfileProvider.select((p) => p.daily)));
final statsProvider = Provider<PlayerStats>((ref) => ref.watch(activeProfileProvider.select((p) => p.stats)));
final playLogProvider = Provider<PlayLog>((ref) => ref.watch(activeProfileProvider.select((p) => p.log)));

/// The player level (from XP).
final levelProvider = Provider<int>((ref) => ref.watch(activeProfileProvider.select((p) => p.level)));

/// The dice / piece / board in use.
final selectedItemProvider = Provider.family<CatalogItem, ItemKind>(
  (ref, kind) => ref.watch(collectionProvider).selectedItem(kind),
);

/// XP boost of what is in use, in percent.
final xpBoostPercentProvider = Provider<int>((ref) => ref.watch(collectionProvider).xpBoostPercent);

// ── Venues ───────────────────────────────────────────────────────────────

/// A venue as the Mela Tour screen lists it.
final class VenueView {
  const VenueView({required this.venue, required this.locked, required this.isBest, required this.plays, required this.wins});

  final Venue venue;

  /// The player level is below its gate.
  final bool locked;

  /// The highest venue the profile has won at ("YOUR BEST").
  final bool isBest;
  final int plays;
  final int wins;
}

final venuesProvider = Provider<List<VenueView>>((ref) {
  final level = ref.watch(levelProvider);
  final progress = ref.watch(progressProvider);
  final best = progress.bestVenueId;
  return [
    for (final v in Venues.all)
      VenueView(
        venue: v,
        locked: !v.isOpenAt(level),
        isBest: v.id == best,
        plays: progress.venuePlays[v.id] ?? 0,
        wins: progress.venueWins[v.id] ?? 0,
      ),
  ];
});

// ── Rewards (time-driven) ────────────────────────────────────────────────

final giftStatusProvider = Provider.autoDispose<GiftStatus>(
  (ref) => ref.watch(dailyProvider.select((d) => d.gift)).status(ref.watch(momentProvider)),
);

/// Free coins, ladder and extra ads in one view.
final class FreeRewardsView {
  const FreeRewardsView({
    required this.coinsReady,
    required this.coinsRemaining,
    required this.ladderDone,
    required this.nextStep,
    required this.coinAdsLeft,
    required this.gemAdsLeft,
    this.coinsReadyAt,
  });

  final bool coinsReady;
  final Duration coinsRemaining;
  final DateTime? coinsReadyAt;

  /// Ladder steps collected today (0–4).
  final int ladderDone;

  /// The step to watch an ad for now, or null when the ladder is done.
  final LadderStep? nextStep;

  /// Coin / gem ads left today (the ladder's steps use the same budget).
  final int coinAdsLeft;
  final int gemAdsLeft;
}

final freeRewardsProvider = Provider.autoDispose<FreeRewardsView>((ref) {
  final free = ref.watch(dailyProvider.select((d) => d.free));
  final budget = ref.watch(activeProfileProvider.select((p) => p.adBudget));
  final m = ref.watch(momentProvider);
  return FreeRewardsView(
    coinsReady: free.coinsReady(m),
    coinsRemaining: free.coinsRemaining(m),
    coinsReadyAt: free.coinsReadyAt(m),
    ladderDone: free.stepsDone(m.day),
    nextStep: free.nextStep(m.day),
    coinAdsLeft: FreeRewards.coinAdsLeft(budget, m.day),
    gemAdsLeft: FreeRewards.gemAdsLeft(budget, m.day),
  );
});

final wheelStatusProvider = Provider.autoDispose<WheelStatus>(
  (ref) => ref.watch(dailyProvider.select((d) => d.wheel)).status(ref.watch(momentProvider)),
);

/// Today's missions (a fresh set is shown from midnight; it is saved with the next action).
final missionsProvider = Provider.autoDispose<MissionsState>((ref) {
  final id = ref.watch(activeProfileProvider.select((p) => p.id));
  final stored = ref.watch(dailyProvider.select((d) => d.missions));
  return stored.rollover(ref.watch(todayProvider), id).$1;
});

/// The three pot slots (null = empty).
final potViewsProvider = Provider.autoDispose<List<PotView?>>((ref) {
  final shelf = ref.watch(dailyProvider.select((d) => d.pots));
  final m = ref.watch(momentProvider);
  return [for (var i = 0; i < PotShelf.slotCount; i++) shelf.view(i, m)];
});

/// Pots waiting for a free slot.
final potQueueProvider = Provider<int>((ref) => ref.watch(dailyProvider.select((d) => d.pots.waiting.length)));

/// Whether the "you're low on coins" top-up can be collected now.
final safetyNetProvider = Provider.autoDispose<bool>((ref) {
  final p = ref.watch(activeProfileProvider);
  final m = ref.watch(momentProvider);
  return SafetyNet.available(
    wallet: p.wallet,
    giftReady: p.daily.gift.status(m).isReady,
    timer: p.daily.safetyNet,
    m: m,
  );
});

// ── Progress ─────────────────────────────────────────────────────────────

final cupProvider = Provider<CupState>((ref) => ref.watch(progressProvider.select((p) => p.cup)));

/// The free cup run of the day is still unused.
final cupFreeRunProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(cupProvider).freeRunAvailable(ref.watch(todayProvider)),
);

final puzzleProvider = Provider<PuzzleState>((ref) => ref.watch(progressProvider.select((p) => p.puzzle)));

/// The streak as shown today (0 once a whole day was missed).
final puzzleStreakProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(puzzleProvider).streakOn(ref.watch(todayProvider)),
);

/// Today's puzzle is already solved.
final puzzleSolvedTodayProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(puzzleProvider).solvedOn(ref.watch(todayProvider)),
);

/// The Mela Road: the level and the levels whose reward waits.
final class RoadView {
  const RoadView({required this.level, required this.claimable, required this.state});

  final int level;
  final List<int> claimable;
  final RoadState state;
}

final roadProvider = Provider<RoadView>((ref) {
  final level = ref.watch(levelProvider);
  final road = ref.watch(progressProvider.select((p) => p.road));
  return RoadView(level: level, claimable: road.claimable(level), state: road);
});

final achievementsProvider = Provider<List<AchievementView>>(
  (ref) => Achievements.views(ref.watch(activeProfileProvider)),
);

/// Insights for [range], computed from the play log.
final insightsProvider = Provider.autoDispose.family<InsightsReport, InsightRange>(
  (ref, range) => Insights.compute(ref.watch(playLogProvider), range, ref.read(clockProvider)()),
);

// ── Lobby badges ─────────────────────────────────────────────────────────

/// What is waiting to be collected (the red dots on the lobby).
final class LobbyBadges {
  const LobbyBadges({
    required this.gift,
    required this.freeCoins,
    required this.freeSpin,
    required this.missions,
    required this.pots,
    required this.road,
    required this.newItems,
  });

  final bool gift;
  final bool freeCoins;
  final bool freeSpin;

  /// Missions to claim plus milestones to collect.
  final int missions;

  /// Pots ready to open.
  final int pots;

  /// Road rewards waiting.
  final int road;

  /// "NEW" items in the Collection.
  final int newItems;

  bool get any => gift || freeCoins || freeSpin || missions > 0 || pots > 0 || road > 0;
}

final lobbyBadgesProvider = Provider.autoDispose<LobbyBadges>((ref) {
  final m = ref.watch(momentProvider);
  final daily = ref.watch(dailyProvider);
  final missions = ref.watch(missionsProvider);
  final road = ref.watch(roadProvider);
  final collection = ref.watch(collectionProvider);
  return LobbyBadges(
    gift: daily.gift.status(m).isReady,
    freeCoins: daily.free.coinsReady(m),
    freeSpin: daily.wheel.status(m).hasFreeSpin,
    missions: missions.claimableCount + missions.readyMilestones.length,
    pots: [for (var i = 0; i < PotShelf.slotCount; i++) daily.pots.phaseOf(i, m)].where((p) => p == PotPhase.ready).length,
    road: road.claimable.length,
    newItems: [for (final k in ItemKind.values) collection.newCount(k)].fold(0, (a, b) => a + b),
  );
});

/// Which reward-ad budget has room left today (the AdService checks the rest).
final rewardAdKindsLeftProvider = Provider.autoDispose<Set<RewardAdKind>>((ref) {
  final v = ref.watch(freeRewardsProvider);
  return {
    if (v.coinAdsLeft > 0) RewardAdKind.coins,
    if (v.gemAdsLeft > 0) RewardAdKind.gems,
    RewardAdKind.other,
  };
});
