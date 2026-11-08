// Ad pacing is the promise to the players (many are children): these tests pin
// every number of board C · "Ad placement" and the clock-moved-back healing.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';

void main() {
  final now = DateTime(2026, 11, 7, 19, 30, 0);
  final today = '2026-11-07';

  BreakAdBlock block({
    bool adsRemoved = false,
    int finished = 10,
    int atLastBreak = 0,
    DateTime? lastBreak,
    DateTime? lastReward,
  }) => breakAdBlock(
    adsRemoved: adsRemoved,
    finishedMatches: finished,
    matchesAtLastBreak: atLastBreak,
    now: now,
    lastBreakAt: lastBreak,
    lastRewardAt: lastReward,
  );

  group('numbers of board C', () {
    test('are the documented ones', () {
      expect(AdRules.freeMatches, 3);
      expect(AdRules.matchesBetweenBreaks, 2);
      expect(AdRules.minBreakGap, const Duration(minutes: 4));
      expect(AdRules.quietAfterRewardAd, const Duration(minutes: 2));
      expect(AdRules.coinAdsPerDay, 5);
      expect(AdRules.gemAdsPerDay, 3);
      expect(AdRules.rewardAdGap, const Duration(seconds: 30));
      expect(AdRules.dailyCap(RewardAdKind.coins), 5);
      expect(AdRules.dailyCap(RewardAdKind.gems), 3);
      expect(AdRules.dailyCap(RewardAdKind.other), isNull);
    });
  });

  group('break ads', () {
    test('are due when nothing blocks them', () {
      expect(block(), BreakAdBlock.none);
      expect(
        breakAdDue(adsRemoved: false, finishedMatches: 10, matchesAtLastBreak: 0, now: now),
        isTrue,
      );
    });

    test('never run with Remove ads, whatever else is true', () {
      expect(block(adsRemoved: true), BreakAdBlock.adsRemoved);
      expect(block(adsRemoved: true, finished: 1), BreakAdBlock.adsRemoved);
      expect(breakAdDue(adsRemoved: true, finishedMatches: 99, matchesAtLastBreak: 0, now: now), isFalse);
    });

    test('never in the first 3 matches', () {
      for (final finished in [0, 1, 2, 3]) {
        expect(block(finished: finished), BreakAdBlock.firstMatches, reason: 'after match $finished');
      }
      expect(block(finished: 4), BreakAdBlock.none, reason: 'the 4th match may be followed by one');
    });

    test('at most every 2nd match: never two matches in a row', () {
      expect(block(finished: 8, atLastBreak: 7), BreakAdBlock.tooFrequent);
      expect(block(finished: 8, atLastBreak: 6), BreakAdBlock.none);
      expect(block(finished: 8, atLastBreak: 8), BreakAdBlock.tooFrequent, reason: 'the same match twice');
    });

    test('are at least 4 minutes apart', () {
      expect(block(lastBreak: now.subtract(const Duration(minutes: 3, seconds: 59))), BreakAdBlock.tooSoon);
      expect(block(lastBreak: now.subtract(const Duration(minutes: 4))), BreakAdBlock.none);
      expect(block(lastBreak: now.subtract(const Duration(hours: 5))), BreakAdBlock.none);
    });

    test('never run within 2 minutes of a reward ad', () {
      expect(block(lastReward: now.subtract(const Duration(minutes: 1, seconds: 59))), BreakAdBlock.rewardAdRecent);
      expect(block(lastReward: now.subtract(const Duration(minutes: 2))), BreakAdBlock.none);
    });

    test('report the FIRST rule that stops them', () {
      expect(block(finished: 2, lastBreak: now, lastReward: now), BreakAdBlock.firstMatches);
      expect(block(finished: 9, atLastBreak: 8, lastBreak: now, lastReward: now), BreakAdBlock.tooFrequent);
      expect(block(lastBreak: now, lastReward: now), BreakAdBlock.tooSoon);
    });

    test('ignore a timestamp in the future (the phone clock was moved back)', () {
      expect(block(lastBreak: now.add(const Duration(days: 30))), BreakAdBlock.none);
      expect(block(lastReward: now.add(const Duration(hours: 1))), BreakAdBlock.none);
    });
  });

  group('reward ads', () {
    RewardAdVerdict verdict(
      RewardAdKind kind, {
      RewardAdBudget budget = const RewardAdBudget(),
      DateTime? last,
      bool parentOff = false,
    }) => rewardAdVerdict(kind: kind, budget: budget, now: now, lastRewardAt: last, parentOff: parentOff);

    test('are allowed on a fresh day', () {
      for (final k in RewardAdKind.values) {
        expect(verdict(k).allowed, isTrue, reason: '$k');
      }
    });

    test('are switched off by Parent controls', () {
      expect(verdict(RewardAdKind.coins, parentOff: true).block, RewardAdBlock.parentOff);
      expect(verdict(RewardAdKind.other, parentOff: true).allowed, isFalse);
    });

    test('coin ads stop after 5 a day, gem ads after 3, other ads have no cap of their own', () {
      final coins4 = RewardAdBudget(day: today, coinAds: 4);
      final coins5 = RewardAdBudget(day: today, coinAds: 5);
      expect(verdict(RewardAdKind.coins, budget: coins4).allowed, isTrue);
      expect(verdict(RewardAdKind.coins, budget: coins5).block, RewardAdBlock.dailyCap);
      expect(verdict(RewardAdKind.gems, budget: coins5).allowed, isTrue, reason: 'the budgets are separate');
      final gems3 = RewardAdBudget(day: today, gemAds: 3);
      expect(verdict(RewardAdKind.gems, budget: gems3).block, RewardAdBlock.dailyCap);
      expect(verdict(RewardAdKind.other, budget: RewardAdBudget(day: today, coinAds: 5, gemAds: 3)).allowed, isTrue);
    });

    test('the budget starts again on a new day', () {
      final yesterday = RewardAdBudget(day: '2026-11-06', coinAds: 5, gemAds: 3);
      expect(verdict(RewardAdKind.coins, budget: yesterday).allowed, isTrue);
      expect(yesterday.usedOn(RewardAdKind.coins, today), 0);
      expect(yesterday.usedOn(RewardAdKind.coins, '2026-11-06'), 5);
    });

    test('are 30 seconds apart, with the wait reported', () {
      final v = verdict(RewardAdKind.coins, last: now.subtract(const Duration(seconds: 29)));
      expect(v.block, RewardAdBlock.tooSoon);
      expect(v.wait, const Duration(seconds: 1));
      expect(verdict(RewardAdKind.coins, last: now.subtract(const Duration(seconds: 30))).allowed, isTrue);
    });

    test('ignore a last-ad time in the future', () {
      expect(verdict(RewardAdKind.coins, last: now.add(const Duration(minutes: 10))).allowed, isTrue);
    });

    test('the daily cap is checked before the spacing', () {
      final full = RewardAdBudget(day: today, coinAds: 5);
      expect(verdict(RewardAdKind.coins, budget: full, last: now).block, RewardAdBlock.dailyCap);
    });
  });

  group('RewardAdBudget', () {
    test('counts an earned ad of its own kind and rolls the day over', () {
      var b = const RewardAdBudget();
      b = b.recorded(RewardAdKind.coins, today).recorded(RewardAdKind.coins, today).recorded(RewardAdKind.gems, today);
      expect((b.coinAds, b.gemAds, b.day), (2, 1, today));
      final next = b.recorded(RewardAdKind.coins, '2026-11-08');
      expect((next.coinAds, next.gemAds, next.day), (1, 0, '2026-11-08'));
    });

    test('an "other" ad uses up neither budget', () {
      final b = const RewardAdBudget().recorded(RewardAdKind.other, today);
      expect((b.coinAds, b.gemAds), (0, 0));
    });

    test('round-trips through JSON, tolerates garbage, compares by value', () {
      final b = RewardAdBudget(day: today, coinAds: 3, gemAds: 2);
      expect(RewardAdBudget.fromJson(b.toJson()), b);
      expect(RewardAdBudget.fromJson(const {'day': 5, 'coinAds': 'x', 'gemAds': -4}), const RewardAdBudget());
      expect(b.hashCode, RewardAdBudget(day: today, coinAds: 3, gemAds: 2).hashCode);
    });
  });

  test('RewardAdVerdict prints its block and wait', () {
    expect(const RewardAdVerdict(RewardAdBlock.tooSoon, Duration(seconds: 5)).toString(), contains('tooSoon'));
    expect(const RewardAdVerdict(RewardAdBlock.none).toString(), 'RewardAdVerdict(RewardAdBlock.none)');
  });
}
