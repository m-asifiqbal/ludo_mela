// Free rewards (board Earn + C): +150 coins every 4 hours without an ad, the four-step
// ad ladder that starts over at local midnight, the extra coin / gem ad budgets, and the
// safety net that keeps nobody locked out of the tables.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';
import 'package:ludo_mela/domain/free_rewards.dart';
import 'package:ludo_mela/domain/guarded_timer.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/wallet.dart';

import 'fixtures.dart';

void main() {
  const hour = Duration(hours: 1);

  group('free coins (+150 every 4 hours, no ad)', () {
    test('the first collect is ready at once; then four hours must pass', () {
      const s = FreeRewardsState();
      expect(s.coinsReady(at(t0)), isTrue);
      expect(s.coinsRemaining(at(t0)), Duration.zero);
      expect(s.coinsReadyAt(at(t0)), isNull);
      final taken = s.collectCoins(at(t0))!;
      expect(taken.coinsReady(at(t0.add(hour * 3))), isFalse);
      expect(taken.coinsRemaining(at(t0.add(hour * 3))), hour);
      expect(taken.coinsReadyAt(at(t0.add(hour * 3))), t0.add(hour * 4));
      expect(taken.collectCoins(at(t0.add(hour * 3))), isNull);
      expect(taken.collectCoins(at(t0.add(hour * 4)))!.coinsReady(at(t0.add(hour * 4))), isFalse, reason: 'a new wait starts');
    });

    test('moving the clock forward does not skip the wait', () {
      final taken = const FreeRewardsState().collectCoins(at(t0, up: 500))!;
      expect(taken.coinsReady(at(t0.add(hour * 20), up: 500 + 60)), isFalse);
    });

    test('collecting keeps the ladder where it was', () {
      final s = const FreeRewardsState(ladderDay: '2026-11-07', ladderStep: 2).collectCoins(at(t0))!;
      expect((s.ladderDay, s.ladderStep), ('2026-11-07', 2));
    });
  });

  group('the ladder (250 coins · 2 gems · 600 coins · a silver pot)', () {
    test('the four steps and the budget each one uses', () {
      final steps = FreeRewards.ladder;
      expect(steps, hasLength(4));
      expect([for (final s in steps) s.coins], [250, 0, 600, 0]);
      expect([for (final s in steps) s.gems], [0, 2, 0, 0]);
      expect(steps[3].pot, PotTier.silver);
      expect([for (final s in steps) s.kind], [RewardAdKind.coins, RewardAdKind.gems, RewardAdKind.coins, RewardAdKind.other]);
      expect(steps[1].grant.gems, 2);
      expect(steps[3].grant.pots, [PotTier.silver]);
    });

    test('only the next step can be taken, in order', () {
      const today = '2026-11-07';
      var s = const FreeRewardsState();
      expect(s.nextStep(today)!.coins, 250);
      expect(s.completeStep(1, today), isNull, reason: 'step 2 before step 1');
      expect(s.completeStep(4, today), isNull);
      for (var i = 0; i < 4; i++) {
        expect(s.stepsDone(today), i);
        s = s.completeStep(i, today)!;
      }
      expect(s.stepsDone(today), 4);
      expect(s.nextStep(today), isNull, reason: 'the ladder is done for today');
      expect(s.completeStep(3, today), isNull);
    });

    test('it starts again at local midnight — never after 24 hours', () {
      var s = const FreeRewardsState();
      s = s.completeStep(0, '2026-11-07')!.completeStep(1, '2026-11-07')!;
      expect(s.stepsDone('2026-11-07'), 2);
      expect(s.stepsDone('2026-11-08'), 0);
      expect(s.nextStep('2026-11-08')!.coins, 250);
      s = s.completeStep(0, '2026-11-08')!;
      expect(s.stepsDone('2026-11-08'), 1);
    });

    test('JSON round trip; a ladder step beyond the ladder is clamped', () {
      final s = const FreeRewardsState().collectCoins(at(t0, up: 9))!.completeStep(0, '2026-11-07')!;
      final back = FreeRewardsState.fromJson(s.toJson());
      expect(back.coinTimer, s.coinTimer);
      expect((back.ladderDay, back.ladderStep), ('2026-11-07', 1));
      expect(FreeRewardsState.fromJson(const {'ladderStep': 99}).ladderStep, 4);
      expect(FreeRewardsState.fromJson(const {}).coinsReady(at(t0)), isTrue);
    });
  });

  group('extra ads: 5 coin ads and 3 gem ads a day, the ladder\'s steps included', () {
    test('what is left today follows the budget; a new day starts full', () {
      var budget = const RewardAdBudget();
      expect(FreeRewards.coinAdsLeft(budget, '2026-11-07'), 5);
      expect(FreeRewards.gemAdsLeft(budget, '2026-11-07'), 3);
      for (var i = 0; i < 4; i++) {
        budget = budget.recorded(RewardAdKind.coins, '2026-11-07');
      }
      budget = budget.recorded(RewardAdKind.gems, '2026-11-07');
      expect(FreeRewards.coinAdsLeft(budget, '2026-11-07'), 1);
      expect(FreeRewards.gemAdsLeft(budget, '2026-11-07'), 2);
      budget = budget.recorded(RewardAdKind.coins, '2026-11-07');
      expect(FreeRewards.coinAdsLeft(budget, '2026-11-07'), 0);
      expect(FreeRewards.coinAdsLeft(budget, '2026-11-08'), 5);
    });
  });

  group('safety net (under 100 coins and no gift waiting → top up to 300, every 4 hours)', () {
    bool available({int coins = 50, bool giftReady = false, GuardedTimer? timer, DateTime? now}) =>
        SafetyNet.available(wallet: Wallet(coins: coins, gems: 0), giftReady: giftReady, timer: timer, m: at(now ?? t0));

    test('a low wallet with no gift waiting can top up; the top-up fills to 300', () {
      expect(available(), isTrue);
      expect(available(coins: 99), isTrue);
      expect(available(coins: 0), isTrue);
      expect(SafetyNet.topUp(const Wallet(coins: 40, gems: 0)), 260);
      expect(SafetyNet.topUp(const Wallet(coins: 0, gems: 0)), 300);
      expect(SafetyNet.topUp(const Wallet(coins: 500, gems: 0)), 0);
    });

    test('100 coins or more, or a gift that can be claimed, means no top-up', () {
      expect(SafetyNet.isLow(const Wallet(coins: 100, gems: 0)), isFalse);
      expect(available(coins: 100), isFalse);
      expect(available(giftReady: true), isFalse);
    });

    test('once taken, the next top-up is four hours later', () {
      final timer = GuardedTimer.start(at(t0));
      expect(available(timer: timer, now: t0.add(hour * 3)), isFalse);
      expect(available(timer: timer, now: t0.add(hour * 4)), isTrue);
    });
  });
}
