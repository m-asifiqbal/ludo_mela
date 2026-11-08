// SaveController's economy, part 1, driven through a ProviderContainer exactly like the
// screens do it: entry fees, finished matches, the safety net, the daily gift, free
// rewards and the lucky wheel. A fixed clock, a scripted Random and a controllable
// monotonic clock make every outcome exact.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/ad_pacing.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/pots.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/profile_state.dart';
import 'package:ludo_mela/domain/wheel.dart';
import 'package:ludo_mela/state/economy_providers.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../domain/fixtures.dart';
import 'economy_harness.dart';

void main() {
  const hour = Duration(hours: 1);
  final h = EconomyHarness();
  setUp(h.reset);
  SaveController ctl() => h.ctl();
  ProfileData me() => h.me();
  T tick<T>(ProviderBase<T> p) => h.tick(p);
  void start([ProfileData? profile]) => h.start(profile);

  group('entry fees', () {
    test('payEntry takes the entry; practice never calls it', () {
      expect(ctl().payEntry('village_haat'), isTrue);
      expect(me().wallet.coins, 900);
    });

    test('refused below the level gate, for an unknown venue, with too few coins, or when Parent controls closed the tables — and nothing is charged', () {
      expect(ctl().payEntry('lantern_bazaar'), isFalse, reason: 'level 3 gate');
      expect(ctl().payEntry('nope'), isFalse);
      expect(me().wallet.coins, 1000);
      start(atLevel(3).copyWith(wallet: freshProfile().wallet.copyWith(coins: 499)));
      expect(ctl().payEntry('lantern_bazaar'), isFalse, reason: 'entry is 500');
      expect(me().wallet.coins, 499);
      start(atLevel(3));
      ctl().updateSettings((s) => s.copyWith(parentCoinTablesOff: true));
      expect(ctl().payEntry('village_haat'), isFalse);
      expect(me().wallet.coins, 1000);
    });

    test('exactly enough coins is enough; the next try fails', () {
      start(atLevel(3));
      expect(ctl().payEntry('lantern_bazaar'), isTrue);
      expect(ctl().payEntry('lantern_bazaar'), isTrue);
      expect(me().wallet.coins, 0);
      expect(ctl().payEntry('lantern_bazaar'), isFalse);
    });

    test('refundEntry gives the entry back for a match that never started', () {
      ctl().payEntry('village_haat');
      expect(ctl().refundEntry('village_haat'), isTrue);
      expect(me().wallet.coins, 1000);
      expect(ctl().refundEntry('nope'), isFalse);
      expect(me().wallet.coins, 1000);
    });

    test('only an entry that was paid and not yet played comes back, and only once', () {
      expect(ctl().refundEntry('village_haat'), isFalse, reason: 'nothing was paid');
      expect(me().wallet.coins, 1000);
      ctl().payEntry('village_haat');
      expect(ctl().refundEntry('lantern_bazaar'), isFalse, reason: 'another venue than the one paid');
      expect(ctl().refundEntry('village_haat'), isTrue);
      expect(ctl().refundEntry('village_haat'), isFalse, reason: 'a second call mints nothing');
      expect(me().wallet.coins, 1000);
      ctl().payEntry('village_haat');
      ctl().recordMatch(match(venueId: 'village_haat', id: 'm-played'));
      final after = me().wallet.coins;
      expect(ctl().refundEntry('village_haat'), isFalse, reason: 'the match was played: the entry is spent');
      expect(me().wallet.coins, after);
    });
  });

  group('recordMatch', () {
    test('a venue win pays the prize, XP, the pot and the log in ONE write, and ticks the break-ad counter', () {
      ctl().payEntry('village_haat');
      final writes = h.store.writes;
      final s = ctl().recordMatch(match(venueId: 'village_haat', captures: 1, home: 2));
      expect(h.store.writes, writes + 1, reason: 'one commit, so a reward can never be half paid');
      expect((s.prizeCoins, s.xp, s.won, s.potEarned), (300, 65, true, PotTier.clay));
      expect(me().wallet.coins, 900 + 300);
      expect(me().xp, 65);
      expect(me().log.length, 1);
      expect(me().daily.pots.filled, 1);
      expect(me().stats.played, 1);
      expect(h.container.read(deviceStateProvider).finishedMatches, 1);
      expect(h.store.data!.toJson(), h.container.read(saveProvider).toJson());
    });

    test('leaving counts as a loss and the entry is not returned', () {
      ctl().payEntry('village_haat');
      final s = ctl().recordMatch(match(venueId: 'village_haat', abandoned: true));
      expect((s.abandoned, s.won, s.coins), (true, false, 0));
      expect(me().wallet.coins, 900);
      expect(me().stats.abandoned, 1);
      expect(me().daily.pots.filled, 0);
    });

    test('the same match id is paid once: a second call returns the first summary and changes nothing', () {
      final first = ctl().recordMatch(match(venueId: 'village_haat', id: 'm-1'));
      final coins = me().wallet.coins;
      final writes = h.store.writes;
      final second = ctl().recordMatch(match(venueId: 'village_haat', id: 'm-1'));
      expect(second, same(first));
      expect((me().wallet.coins, me().stats.played, me().log.length), (coins, 1, 1));
      expect(h.store.writes, writes);
      ctl().recordMatch(match(venueId: 'village_haat', id: 'm-2'));
      expect(me().stats.played, 2, reason: 'another match is another match');
      ctl().recordMatch(match(venueId: 'village_haat'));
      ctl().recordMatch(match(venueId: 'village_haat'));
      expect(me().stats.played, 4, reason: 'records without an id are never merged');
    });

    test('practice pays XP only', () {
      final s = ctl().recordMatch(match(practice: true, captures: 2, home: 1));
      expect((s.practice, s.coins, s.xp), (true, 0, 32));
      expect(me().wallet.coins, 1000);
    });

    test('in pass & play every family profile at the table gets its own result', () {
      final tara = ctl().addProfile(name: 'Tara')!;
      final record = match(
        kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot],
        profileIds: ['p1', tara, null, null],
        place: 1,
        captures: 1,
      );
      ctl().recordMatch(record);
      final taraProfile = h.container.read(saveProvider).profile(tara)!;
      expect(taraProfile.stats.played, 1);
      expect(taraProfile.stats.won, 0, reason: 'Tara finished second');
      expect(taraProfile.log.length, 1);
      expect(me().stats.won, 1);
      expect(h.container.read(deviceStateProvider).finishedMatches, 1, reason: 'one match on this phone, not two');
    });

    test('a level-up makes the Mela Road reward collectable, once', () {
      start(freshProfile().copyWith(xp: 140));
      final s = ctl().recordMatch(match(venueId: 'village_haat'));
      expect(s.levelUps, [2]);
      expect(h.container.read(roadProvider).claimable, [2]);
      expect(ctl().claimRoadReward(3), isNull, reason: 'level 3 is not reached');
      final gems = me().wallet.gems;
      final o = ctl().claimRoadReward(2)!;
      expect(o.value.level, 2);
      expect(me().wallet.gems, gems + 5);
      expect(ctl().claimRoadReward(2), isNull, reason: 'already collected');
      expect(ctl().claimRoadReward(1), isNull);
      expect(h.container.read(roadProvider).claimable, isEmpty);
    });

    test('claimAllRoadRewards collects every waiting level in order', () {
      start(atLevel(8));
      final got = ctl().claimAllRoadRewards();
      expect([for (final o in got) o.value.level], [2, 4, 5, 6, 7, 8]);
      expect(me().collection.owns('moon'), isTrue, reason: 'level 8 hands over Moon Gems');
      expect(me().daily.pots.filled, 2, reason: 'a clay pot at 4 and a silver pot at 5');
      expect(ctl().claimAllRoadRewards(), isEmpty);
    });
  });

  group('the safety net', () {
    test('under 100 coins with no gift waiting: a top-up to 300, then four hours before the next', () {
      ctl().claimGift(); // the gift is now 24 h away
      ctl().spend(coins: me().wallet.coins - 50);
      expect(me().wallet.coins, 50);
      expect(ctl().safetyNetAvailable, isTrue);
      expect(ctl().claimSafetyNet(), 250);
      expect(me().wallet.coins, 300);
      expect(me().progress.safetyNetUses, 1);
      ctl().spend(coins: 250);
      expect(ctl().safetyNetAvailable, isFalse, reason: 'taken less than 4 hours ago');
      expect(ctl().claimSafetyNet(), 0);
      h.now = h.now.add(hour * 4);
      expect(ctl().safetyNetAvailable, isTrue);
    });

    test('not while a gift can be claimed, and not with 100 coins or more', () {
      ctl().spend(coins: 950);
      expect(ctl().safetyNetAvailable, isFalse, reason: 'the daily gift is waiting');
      ctl().claimGift();
      ctl().earn(coins: 50);
      ctl().spend(coins: me().wallet.coins - 100);
      expect(ctl().safetyNetAvailable, isFalse);
    });
  });

  group('the daily gift', () {
    test('Day 1 now, Day 2 after 24 hours, "double it" pays twice, and nothing before it is time', () {
      final one = ctl().claimGift()!;
      expect(one.value.day, 1);
      expect(me().wallet.coins, 1200);
      expect(ctl().claimGift(), isNull);
      expect(h.container.read(giftStatusProvider).isReady, isFalse);
      h.now = h.now.add(hour * 24);
      final two = ctl().claimGift()!;
      expect((two.value.day, me().wallet.coins, me().wallet.gems), (2, 1500, 22));
      h.now = h.now.add(hour * 24);
      final three = ctl().claimGift(doubled: true)!;
      expect((three.value.day, three.value.doubled), (3, true));
      expect(me().wallet.coins, 1500 + 800);
      expect(me().progress.giftsClaimed, 3);
    });

    test('Day 5 adds a wheel spin, Day 7 a Mela pot for the shelf', () {
      for (var i = 1; i <= 7; i++) {
        ctl().claimGift();
        h.now = h.now.add(hour * 24);
      }
      expect(me().daily.wheel.bonusSpins, 1);
      expect(me().daily.pots.slots.whereType<PotSlot>().single.tier, PotTier.mela);
    });

    test('moving the phone clock forward does not open the gift early', () {
      h.uptime = const Duration(seconds: 1000);
      ctl().claimGift();
      h.now = h.now.add(hour * 30);
      h.uptime = const Duration(seconds: 1000 + 600);
      expect(ctl().claimGift(), isNull);
      expect(h.container.read(giftStatusProvider).remaining, greaterThan(hour * 23));
    });

    test('syncDaily saves the time the timers have seen pass (so a clock moved back later cannot undo it)', () {
      h.uptime = Duration.zero;
      ctl().claimGift();
      h.now = h.now.add(hour * 10);
      h.uptime = hour * 10;
      ctl().syncDaily();
      expect(me().daily.gift.timer!.credited, hour * 10);
    });
  });

  group('free rewards', () {
    test('+150 coins every four hours, no ad', () {
      expect(ctl().collectFreeCoins()!.value, 150);
      expect(me().wallet.coins, 1150);
      expect(ctl().collectFreeCoins(), isNull);
      h.now = h.now.add(hour * 3);
      expect(ctl().collectFreeCoins(), isNull);
      h.now = h.now.add(hour);
      expect(ctl().collectFreeCoins(), isNotNull);
      expect(me().wallet.coins, 1300);
    });

    test('the ladder pays 250 coins · 2 gems · 600 coins · a silver pot, in order, and starts again tomorrow', () {
      expect(ctl().collectLadderStep(1), isNull, reason: 'step 2 before step 1');
      expect(ctl().collectLadderStep(0)!.value.coins, 250);
      expect(ctl().collectLadderStep(0), isNull, reason: 'the same step twice');
      expect(ctl().collectLadderStep(1)!.value.gems, 2);
      expect(ctl().collectLadderStep(2)!.value.coins, 600);
      expect(ctl().collectLadderStep(3)!.value.pots, [PotTier.silver]);
      expect((me().wallet.coins, me().wallet.gems), (1850, 22));
      expect(me().daily.pots.slots.first!.tier, PotTier.silver);
      expect(ctl().collectLadderStep(3), isNull, reason: 'the ladder is done today');
      expect(h.container.read(freeRewardsProvider).ladderDone, 4);
      h.now = DateTime(2026, 11, 8, 0, 5);
      expect(tick(freeRewardsProvider).ladderDone, 0);
      expect(ctl().collectLadderStep(0), isNotNull);
    });

    test('the extra coin and gem ads pay +250 coins / +3 gems; nothing else is an "extra" ad', () {
      expect(ctl().collectExtraAd(RewardAdKind.coins)!.value.coins, 250);
      expect(ctl().collectExtraAd(RewardAdKind.gems)!.value.gems, 3);
      expect(ctl().collectExtraAd(RewardAdKind.other), isNull);
      expect((me().wallet.coins, me().wallet.gems), (1250, 23));
    });

    test('the daily ad budget shows what is left (5 coin ads, 3 gem ads) and refills at midnight', () {
      ctl().noteRewardAd(earned: RewardAdKind.coins);
      ctl().noteRewardAd(earned: RewardAdKind.gems);
      final v = h.container.refresh(freeRewardsProvider);
      expect((v.coinAdsLeft, v.gemAdsLeft), (4, 2));
      expect(h.container.read(rewardAdKindsLeftProvider), containsAll([RewardAdKind.coins, RewardAdKind.gems, RewardAdKind.other]));
      h.now = DateTime(2026, 11, 8, 9);
      final next = tick(freeRewardsProvider);
      expect((next.coinAdsLeft, next.gemAdsLeft), (5, 3));
    });
  });

  group('the lucky wheel', () {
    test('one free spin a day: the first pays the segment the roll lands on, the second waits', () {
      h.rng.roll = 0.0; // 100 coins
      final o = ctl().spinWheel(SpinMethod.free)!;
      expect((o.value.segment, me().wallet.coins), (0, 1100));
      expect(ctl().spinWheel(SpinMethod.free), isNull);
      expect(me().daily.wheel.totalSpins, 1);
      h.now = h.now.add(hour * 24);
      expect(ctl().spinWheel(SpinMethod.free), isNotNull);
    });

    test('one ad spin a day, back at midnight', () {
      expect(ctl().spinWheel(SpinMethod.ad), isNotNull);
      expect(ctl().spinWheel(SpinMethod.ad), isNull);
      h.now = DateTime(2026, 11, 8, 0, 30);
      expect(ctl().spinWheel(SpinMethod.ad), isNotNull);
    });

    test('a spin for 10 gems costs 10 gems and still pays the prize; without the gems nothing happens', () {
      h.rng.roll = 0.0;
      expect(ctl().spinWheel(SpinMethod.gems), isNotNull);
      expect((me().wallet.gems, me().wallet.coins), (10, 1100));
      expect(ctl().spinWheel(SpinMethod.gems), isNotNull);
      expect(me().wallet.gems, 0);
      final spins = me().daily.wheel.totalSpins;
      expect(ctl().spinWheel(SpinMethod.gems), isNull);
      expect(me().daily.wheel.totalSpins, spins, reason: 'a refused spin changes nothing');
    });

    test('bonus spins from the daily gift are used one by one', () {
      start(freshProfile().copyWith(daily: DailyState(wheel: const WheelState().withBonusSpins(1))));
      expect(ctl().spinWheel(SpinMethod.bonus), isNotNull);
      expect(ctl().spinWheel(SpinMethod.bonus), isNull);
    });

    test('the Rare dice segment adds a dice to the Collection', () {
      h.rng.roll = 99.0 / 100; // the last segment: the Rare dice
      final o = ctl().spinWheel(SpinMethod.free)!;
      expect(o.value.diceId, isNotNull);
      expect(me().collection.owns(o.value.diceId!), isTrue);
      expect(o.receipt.itemsGranted, [o.value.diceId]);
    });
  });

}
