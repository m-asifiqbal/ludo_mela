// The daily gift (board DailyReward + C · "Daily gift"): seven days, a gift every
// 24 hours.
//
//   Day 1 200 coins · Day 2 300 + 2 gems · Day 3 400 · Day 4 500 + 3 gems ·
//   Day 5 600 + a wheel spin · Day 6 800 + 5 gems · Day 7 a Mela pot
// then it starts again at Day 1 (the streak keeps counting).
//
// Timing: the next gift unlocks 24 h after the last claim — not at midnight. Miss
// more than 48 h and the streak restarts at Day 1. The countdown is a
// [GuardedTimer] (wall clock + monotonic uptime; a clock moved back pauses it).
// "Watch an ad to double it" is a flag on the claim: the caller shows the ad first
// and passes `doubled: true` only when it was earned. Pure Dart.

import 'economy_rules.dart';
import 'grant.dart';
import 'guarded_timer.dart';
import 'json_read.dart';
import 'pot_tier.dart';

final class GiftReward {
  const GiftReward({this.coins = 0, this.gems = 0, this.spins = 0, this.pot});

  final int coins;
  final int gems;
  final int spins;
  final PotTier? pot;

  Grant get grant => Grant(coins: coins, gems: gems, spins: spins, pots: pot == null ? const [] : [pot!]);
}

abstract final class DailyGift {
  static const days = <GiftReward>[
    GiftReward(coins: 200),
    GiftReward(coins: 300, gems: 2),
    GiftReward(coins: 400),
    GiftReward(coins: 500, gems: 3),
    GiftReward(coins: 600, spins: 1),
    GiftReward(coins: 800, gems: 5),
    GiftReward(pot: PotTier.mela),
  ];

  /// The reward of cycle day [day] (1–7; larger numbers wrap).
  static GiftReward forDay(int day) => days[(day - 1) % EconomyRules.giftCycleDays];
}

enum GiftPhase {
  /// A gift can be claimed now.
  ready,

  /// Already claimed; the countdown runs.
  waiting,
}

/// What the gift screen and the lobby button show.
final class GiftStatus {
  const GiftStatus({
    required this.phase,
    required this.nextDay,
    required this.cycleDone,
    required this.streak,
    required this.remaining,
    this.readyAt,
    this.streakBroken = false,
  });

  final GiftPhase phase;

  /// The cycle day (1–7) the next claim pays.
  final int nextDay;

  /// Days of the current cycle already collected (0–7): cards up to it are ticked.
  final int cycleDone;

  /// Consecutive days claimed ("4-DAY STREAK"); 0 when it was just broken.
  final int streak;

  /// Time until it unlocks (zero when ready).
  final Duration remaining;
  final DateTime? readyAt;

  /// More than 48 h passed: the streak restarts at Day 1.
  final bool streakBroken;

  bool get isReady => phase == GiftPhase.ready;
}

/// What a claim handed over.
final class GiftClaim {
  const GiftClaim({required this.day, required this.streak, required this.grant, required this.doubled});

  final int day;
  final int streak;
  final Grant grant;
  final bool doubled;
}

final class GiftState {
  const GiftState({this.streak = 0, this.timer});

  /// Consecutive days claimed.
  final int streak;

  /// Counting since the last claim; null = never claimed.
  final GuardedTimer? timer;

  GiftState advance(Moment m) => timer == null ? this : GiftState(streak: streak, timer: timer!.advance(m));

  GiftStatus status(Moment m) {
    final t = timer?.advance(m);
    final broken = t != null && t.credited > EconomyRules.giftStreakBreaksAfter;
    final live = broken ? 0 : streak;
    final cycleDone = live == 0 ? 0 : (live - 1) % EconomyRules.giftCycleDays + 1;
    final ready = t == null || t.isDone(EconomyRules.giftEvery);
    // A full cycle shows all seven ticked while waiting; the next claim is Day 1 again.
    final nextDay = live % EconomyRules.giftCycleDays + 1;
    return GiftStatus(
      phase: ready ? GiftPhase.ready : GiftPhase.waiting,
      nextDay: nextDay,
      cycleDone: ready && cycleDone == EconomyRules.giftCycleDays ? 0 : cycleDone,
      streak: live,
      remaining: t?.remaining(EconomyRules.giftEvery) ?? Duration.zero,
      readyAt: t?.readyAt(EconomyRules.giftEvery),
      streakBroken: broken,
    );
  }

  /// Claim the gift at [m] (null when it is not ready). With [doubled] (an ad was
  /// watched) everything is paid twice.
  (GiftState, GiftClaim)? claim(Moment m, {bool doubled = false}) {
    final s = status(m);
    if (!s.isReady) return null;
    final reward = DailyGift.forDay(s.nextDay).grant;
    final newStreak = s.streak + 1;
    return (
      GiftState(streak: newStreak, timer: GuardedTimer.start(m)),
      GiftClaim(day: s.nextDay, streak: newStreak, grant: doubled ? reward.times(2) : reward, doubled: doubled),
    );
  }

  Map<String, Object?> toJson() => {'streak': streak, if (timer != null) 'timer': timer!.toJson()};

  factory GiftState.fromJson(Map<String, Object?> j) =>
      GiftState(streak: j.intIn('streak', 0), timer: GuardedTimer.fromJson(j['timer']));
}
