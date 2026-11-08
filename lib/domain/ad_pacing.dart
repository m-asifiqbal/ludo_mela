// Ad pacing: WHEN an ad may run, as pure functions (board C · "Ad placement").
//
// Why pure: the rules protect players (many are children) from ad fatigue, so
// they must be easy to read, easy to test and impossible to bypass by a UI
// detail. Nothing here knows about the AdMob SDK, widgets or the clock — the
// caller passes `now` and the facts it saved.
//
// Break ads (interstitial) — only after a FINISHED match, behind a "Quick
// break" card, and only when ALL of these hold:
//   • the player has not bought Remove ads;
//   • it is not one of the first 3 matches;
//   • at most every 2nd match (never two matches in a row);
//   • at least 4 minutes since the last break ad;
//   • at least 2 minutes since any reward ad.
// Reward ads — always opt-in: coin ads 5 a day, gem ads 3 a day, 30 seconds
// between any two ads, and never when Parent controls switched them off. A
// reward ad counts against the day only when the reward was EARNED (a failed
// or skipped ad uses nothing up).
//
// A timestamp that lies in the future (the phone clock was moved back) is
// ignored rather than blocking ads for days, so the rules heal themselves.

import 'day_key.dart';
import 'json_read.dart';

/// The numbers from board C, in one place.
abstract final class AdRules {
  /// Break ads never run after one of the first N finished matches.
  static const freeMatches = 3;

  /// At most every Nth finished match may be followed by a break ad.
  static const matchesBetweenBreaks = 2;

  static const minBreakGap = Duration(minutes: 4);

  /// Quiet time after a reward ad before a break ad may run.
  static const quietAfterRewardAd = Duration(minutes: 2);

  static const coinAdsPerDay = 5;
  static const gemAdsPerDay = 3;

  /// Minimum time between any two reward ads.
  static const rewardAdGap = Duration(seconds: 30);

  /// How many ads of [kind] fit in one day (null = no daily cap of its own:
  /// the feature that offers it limits it, e.g. "Double daily gift" is once).
  static int? dailyCap(RewardAdKind kind) => switch (kind) {
    RewardAdKind.coins => coinAdsPerDay,
    RewardAdKind.gems => gemAdsPerDay,
    RewardAdKind.other => null,
  };
}

/// Which budget a reward ad counts against.
enum RewardAdKind {
  /// Free-rewards coin ads (ladder steps included): 5 a day.
  coins,

  /// Gem ads (ladder steps included): 3 a day.
  gems,

  /// Everything else — a silver pot, "double the daily gift", an extra wheel
  /// spin. Spaced by the 30 s rule; the offering feature caps it at once a day.
  other,
}

/// Why a break ad is not due ([none] = it is).
enum BreakAdBlock { none, adsRemoved, firstMatches, tooFrequent, tooSoon, rewardAdRecent }

/// The first rule that stops a break ad now, or [BreakAdBlock.none].
///
/// [finishedMatches] counts the match that has just ended; [matchesAtLastBreak]
/// is that same count when the last break ad ran (0 = none yet).
BreakAdBlock breakAdBlock({
  required bool adsRemoved,
  required int finishedMatches,
  required int matchesAtLastBreak,
  required DateTime now,
  DateTime? lastBreakAt,
  DateTime? lastRewardAt,
}) {
  if (adsRemoved) return BreakAdBlock.adsRemoved;
  if (finishedMatches <= AdRules.freeMatches) return BreakAdBlock.firstMatches;
  if (finishedMatches - matchesAtLastBreak < AdRules.matchesBetweenBreaks) return BreakAdBlock.tooFrequent;
  if (_within(lastBreakAt, now, AdRules.minBreakGap)) return BreakAdBlock.tooSoon;
  if (_within(lastRewardAt, now, AdRules.quietAfterRewardAd)) return BreakAdBlock.rewardAdRecent;
  return BreakAdBlock.none;
}

/// Whether a break ad may run now (see [breakAdBlock] for the reasons).
bool breakAdDue({
  required bool adsRemoved,
  required int finishedMatches,
  required int matchesAtLastBreak,
  required DateTime now,
  DateTime? lastBreakAt,
  DateTime? lastRewardAt,
}) =>
    breakAdBlock(
      adsRemoved: adsRemoved,
      finishedMatches: finishedMatches,
      matchesAtLastBreak: matchesAtLastBreak,
      now: now,
      lastBreakAt: lastBreakAt,
      lastRewardAt: lastRewardAt,
    ) ==
    BreakAdBlock.none;

/// True when [then] happened less than [gap] before [now]. A [then] in the
/// future (clock moved back) or absent never blocks.
bool _within(DateTime? then, DateTime now, Duration gap) {
  if (then == null || then.isAfter(now)) return false;
  return now.difference(then) < gap;
}

/// Why a reward ad may not run ([none] = it may).
enum RewardAdBlock { none, parentOff, dailyCap, tooSoon }

/// The answer of [rewardAdVerdict].
final class RewardAdVerdict {
  const RewardAdVerdict(this.block, [this.wait = Duration.zero]);

  final RewardAdBlock block;

  /// For [RewardAdBlock.tooSoon]: how long until the next ad is allowed.
  final Duration wait;

  bool get allowed => block == RewardAdBlock.none;

  @override
  String toString() => 'RewardAdVerdict($block${wait == Duration.zero ? '' : ', wait: $wait'})';
}

/// Whether a reward ad of [kind] may be offered now.
RewardAdVerdict rewardAdVerdict({
  required RewardAdKind kind,
  required RewardAdBudget budget,
  required DateTime now,
  DateTime? lastRewardAt,
  bool parentOff = false,
}) {
  if (parentOff) return const RewardAdVerdict(RewardAdBlock.parentOff);
  final cap = AdRules.dailyCap(kind);
  if (cap != null && budget.usedOn(kind, DayKey.of(now)) >= cap) {
    return const RewardAdVerdict(RewardAdBlock.dailyCap);
  }
  if (lastRewardAt != null && !lastRewardAt.isAfter(now)) {
    final since = now.difference(lastRewardAt);
    if (since < AdRules.rewardAdGap) return RewardAdVerdict(RewardAdBlock.tooSoon, AdRules.rewardAdGap - since);
  }
  return const RewardAdVerdict(RewardAdBlock.none);
}

/// How many coin / gem reward ads a profile has watched today.
///
/// Stored per profile (each family player has their own ladder and wallet);
/// the spacing between ads is device-wide and lives in `DeviceState`.
final class RewardAdBudget {
  const RewardAdBudget({this.day = '', this.coinAds = 0, this.gemAds = 0});

  /// The calendar day ([DayKey.of]) the counts belong to; they read as 0 on any
  /// other day, so nothing has to reset them at midnight.
  final String day;
  final int coinAds;
  final int gemAds;

  /// Ads of [kind] watched on [today] ([DayKey.of]).
  int usedOn(RewardAdKind kind, String today) {
    if (day != today) return 0;
    return switch (kind) {
      RewardAdKind.coins => coinAds,
      RewardAdKind.gems => gemAds,
      RewardAdKind.other => 0,
    };
  }

  /// This budget after one more ad of [kind] earned on [today].
  RewardAdBudget recorded(RewardAdKind kind, String today) {
    final fresh = day != today;
    final coins = fresh ? 0 : coinAds, gems = fresh ? 0 : gemAds;
    return RewardAdBudget(
      day: today,
      coinAds: kind == RewardAdKind.coins ? coins + 1 : coins,
      gemAds: kind == RewardAdKind.gems ? gems + 1 : gems,
    );
  }

  Map<String, Object?> toJson() => {'day': day, 'coinAds': coinAds, 'gemAds': gemAds};

  factory RewardAdBudget.fromJson(Map<String, Object?> j) =>
      RewardAdBudget(day: j.stringOr('day', ''), coinAds: j.intIn('coinAds', 0), gemAds: j.intIn('gemAds', 0));

  @override
  bool operator ==(Object other) =>
      other is RewardAdBudget && other.day == day && other.coinAds == coinAds && other.gemAds == gemAds;

  @override
  int get hashCode => Object.hash(day, coinAds, gemAds);
}
