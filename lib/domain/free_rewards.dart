// Free rewards (board Earn + C · "Reward ads & wheel") and the safety net.
//
//   • Free coins: +150 every 4 h, no ad (a [GuardedTimer], so moving the clock
//     does not speed it up). The first collect is ready at once.
//   • The ladder: four steps, opened one by one by watching an ad each —
//     250 coins · 2 gems · 600 coins · a silver pot — resetting at local midnight.
//   • Extra coin / gem ads: +250 coins / +3 gems, on top of the ladder. Coin ads
//     cap at 5 a day and gem ads at 3 (ladder steps included): the caps and the
//     30 s spacing are enforced by `AdService` / ad_pacing.dart, which also counts
//     the ad when it is earned — nothing here counts it a second time.
//   • Safety net: under 100 coins with no daily gift waiting, a free top-up to 300
//     coins every 4 h, so nobody is ever locked out of the tables.
// Pure Dart.

import 'ad_pacing.dart';
import 'economy_rules.dart';
import 'grant.dart';
import 'guarded_timer.dart';
import 'json_read.dart';
import 'pot_tier.dart';
import 'wallet.dart';

/// One rung of the ladder.
final class LadderStep {
  const LadderStep(this.kind, {this.coins = 0, this.gems = 0, this.pot});

  /// Which daily ad budget watching it uses.
  final RewardAdKind kind;
  final int coins;
  final int gems;
  final PotTier? pot;

  Grant get grant => Grant(coins: coins, gems: gems, pots: pot == null ? const [] : [pot!]);
}

abstract final class FreeRewards {
  static const ladder = <LadderStep>[
    LadderStep(RewardAdKind.coins, coins: 250),
    LadderStep(RewardAdKind.gems, gems: 2),
    LadderStep(RewardAdKind.coins, coins: 600),
    LadderStep(RewardAdKind.other, pot: PotTier.silver),
  ];

  /// Extra coin-ad rewards left today (the ladder's coin steps use up the same budget).
  static int coinAdsLeft(RewardAdBudget budget, String day) =>
      (AdRules.coinAdsPerDay - budget.usedOn(RewardAdKind.coins, day)).clamp(0, AdRules.coinAdsPerDay);

  static int gemAdsLeft(RewardAdBudget budget, String day) =>
      (AdRules.gemAdsPerDay - budget.usedOn(RewardAdKind.gems, day)).clamp(0, AdRules.gemAdsPerDay);
}

/// The free coins timer and today's ladder progress of one profile.
final class FreeRewardsState {
  const FreeRewardsState({this.coinTimer, this.ladderDay = '', this.ladderStep = 0});

  /// Counting since the last free-coins collect; null = ready.
  final GuardedTimer? coinTimer;

  /// The day [ladderStep] belongs to (it reads as 0 on any other day).
  final String ladderDay;

  /// Ladder steps collected on [ladderDay].
  final int ladderStep;

  bool coinsReady(Moment m) => coinTimer == null || coinTimer!.advance(m).isDone(EconomyRules.freeCoinsEvery);

  Duration coinsRemaining(Moment m) => coinTimer?.advance(m).remaining(EconomyRules.freeCoinsEvery) ?? Duration.zero;

  /// When the next free coins unlock (null when ready now).
  DateTime? coinsReadyAt(Moment m) => coinsReady(m) ? null : coinTimer!.advance(m).readyAt(EconomyRules.freeCoinsEvery);

  /// Collect the free coins (null when not ready yet).
  FreeRewardsState? collectCoins(Moment m) =>
      coinsReady(m) ? FreeRewardsState(coinTimer: GuardedTimer.start(m), ladderDay: ladderDay, ladderStep: ladderStep) : null;

  /// Ladder steps collected today.
  int stepsDone(String today) => ladderDay == today ? ladderStep : 0;

  /// The step the player may watch an ad for now, or null when the ladder is done today.
  LadderStep? nextStep(String today) {
    final i = stepsDone(today);
    return i < FreeRewards.ladder.length ? FreeRewards.ladder[i] : null;
  }

  /// Step [index] collected today. Only the next step can be taken (null otherwise).
  FreeRewardsState? completeStep(int index, String today) {
    if (index != stepsDone(today) || index >= FreeRewards.ladder.length) return null;
    return FreeRewardsState(coinTimer: coinTimer, ladderDay: today, ladderStep: index + 1);
  }

  Map<String, Object?> toJson() => {
    if (coinTimer != null) 'coins': coinTimer!.toJson(),
    'ladderDay': ladderDay,
    'ladderStep': ladderStep,
  };

  factory FreeRewardsState.fromJson(Map<String, Object?> j) => FreeRewardsState(
    coinTimer: GuardedTimer.fromJson(j['coins']),
    ladderDay: j.stringOr('ladderDay', ''),
    ladderStep: j.intIn('ladderStep', 0, max: FreeRewards.ladder.length),
  );
}

/// The "you are low on coins" top-up.
abstract final class SafetyNet {
  static bool isLow(Wallet w) => w.coins < EconomyRules.safetyNetBelow;

  /// Whether the top-up can be collected: low wallet, no gift waiting, and the
  /// last top-up (if any) was 4 h ago.
  static bool available({required Wallet wallet, required bool giftReady, GuardedTimer? timer, required Moment m}) {
    if (!isLow(wallet) || giftReady) return false;
    return timer == null || timer.advance(m).isDone(EconomyRules.safetyNetEvery);
  }

  /// Coins the top-up adds to [wallet].
  static int topUp(Wallet wallet) => (EconomyRules.safetyNetTopUpTo - wallet.coins).clamp(0, EconomyRules.safetyNetTopUpTo);
}
