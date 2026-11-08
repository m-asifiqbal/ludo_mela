// SaveController's economy, part 2: missions and the puzzle, Mela pots, the Collection,
// the Mela Cup, the lobby's badges and views, and the separation of family profiles.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/insights.dart';
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
  ProfileData withMissions(List<String> ids) => h.withMissions(ids);

  group('missions', () {
    const ids = ['win2', 'capture5', 'home3', 'play3', 'play1'];

    test('a match moves them, claiming pays coins, the milestones pay at 25 / 50 points, one free swap a day', () {
      start(withMissions(ids));
      ctl().recordMatch(match(practice: true, place: 1, captures: 5, home: 3)); // capture5, home3, play1 done; win2 1/2, play3 1/3
      final m = h.container.read(saveProvider).activeProfile.daily.missions;
      expect([for (final x in m.missions) x.done], [false, true, true, false, true]);
      final coins = me().wallet.coins;
      expect(ctl().claimMission(0), isNull, reason: 'not finished');
      expect(ctl().claimMission(1)!.value.coins, 150);
      expect(ctl().claimMission(1), isNull, reason: 'twice');
      expect(ctl().claimMission(2), isNotNull);
      expect(ctl().claimMission(4), isNotNull);
      expect(me().wallet.coins, coins + 150 + 150 + 100);
      expect(me().daily.missions.points, 55);
      expect(ctl().claimMilestone(75), isNull);
      expect(ctl().claimMilestone(25)!.value.coins, 200);
      final gems = me().wallet.gems;
      expect(ctl().claimMilestone(50), isNotNull);
      expect(me().wallet.gems, gems + 3);
      expect(ctl().claimMilestone(25), isNull, reason: 'once each');
      expect(ctl().swapMission(0), isTrue);
      expect(me().daily.missions.swapUsed, isTrue);
      expect(ctl().swapMission(3), isFalse, reason: 'one a day');
    });

    test('at midnight nothing is lost: what was finished is paid and a new set begins', () {
      start(withMissions(ids));
      ctl().recordMatch(match(practice: true, place: 1, captures: 5, home: 3));
      final coins = me().wallet.coins;
      h.now = DateTime(2026, 11, 8, 0, 1);
      ctl().syncDaily();
      expect(me().daily.missions.day, '2026-11-08');
      expect(me().daily.missions.points, 0);
      expect(me().wallet.coins, coins + 150 + 150 + 100 + 200, reason: 'three finished missions and the 25-point milestone');
      expect(me().wallet.gems, greaterThanOrEqualTo(23), reason: 'the 50-point milestone');
    });

    test('the puzzle moves the puzzle mission and pays 100 coins once a day; the streak grows day by day', () {
      start(withMissions(['puzzle', 'win2', 'capture5', 'play3', 'home3']));
      expect(ctl().puzzleSolved()!.value.coins, 100);
      expect(me().wallet.coins, 1100);
      expect(me().daily.missions.missions.first.done, isTrue);
      expect(ctl().puzzleSolved(), isNull, reason: 'no second reward today');
      expect(h.container.refresh(puzzleStreakProvider), 1);
      expect(h.container.read(puzzleSolvedTodayProvider), isTrue);
      h.now = h.now.add(const Duration(days: 1));
      expect(ctl().puzzleSolved(), isNotNull);
      expect(tick(puzzleStreakProvider), 2);
      h.now = h.now.add(const Duration(days: 3));
      expect(tick(puzzleStreakProvider), 0, reason: 'a missed day ends it');
    });

    test('the missions the screen shows are today\'s even before anything is saved', () {
      expect(h.container.refresh(missionsProvider).missions, hasLength(5));
      expect(h.container.read(missionsProvider).day, '2026-11-07');
    });
  });

  group('Mela pots', () {
    ProfileData onePot(PotTier tier) => freshProfile().copyWith(
      daily: DailyState(pots: const PotShelf().add(tier).$1),
    );

    test('a win shelves a pot; one timer runs at a time; a ready pot opens and pays what is inside', () {
      ctl().recordMatch(match(venueId: 'village_haat'));
      expect(ctl().startPot(0), isTrue);
      expect(ctl().startPot(0), isFalse, reason: 'already running');
      expect(ctl().startPot(1), isFalse, reason: 'empty slot');
      expect(ctl().startPot(7), isFalse, reason: 'no such slot');
      expect(ctl().openPot(0), isNull, reason: 'still running');
      h.now = h.now.add(hour * 3);
      h.rng.pick = 99; // skip the optional lines: coins only
      final coins = me().wallet.coins;
      final o = ctl().openPot(0)!;
      expect(o.value.tier, PotTier.clay);
      expect(me().wallet.coins, coins + o.value.grant.coins);
      expect(o.value.grant.coins, inInclusiveRange(80, 200));
      expect(me().daily.pots.filled, 0);
      expect(me().progress.potsOpened, 1);
    });

    test('1 gem skips 20 minutes: a running 3-hour pot costs 9 gems at the start, and then opens', () {
      start(onePot(PotTier.clay));
      ctl().startPot(0);
      expect(ctl().skipPot(0), isTrue);
      expect(me().wallet.gems, 11);
      expect(ctl().openPot(0), isNotNull);
    });

    test('without enough gems a skip does nothing; a ready or empty slot cannot be skipped', () {
      start(onePot(PotTier.gold).copyWith(wallet: freshProfile().wallet.copyWith(gems: 35)));
      expect(ctl().skipPot(0), isFalse, reason: '36 gems needed');
      expect(me().wallet.gems, 35);
      expect(ctl().skipPot(1), isFalse, reason: 'empty slot');
      expect(h.container.refresh(potViewsProvider)[0]!.skipGems, 36);
    });

    test('the clock moved forward does not open a pot early', () {
      start(onePot(PotTier.clay));
      h.uptime = const Duration(seconds: 500);
      ctl().startPot(0);
      h.now = h.now.add(hour * 30);
      h.uptime = const Duration(seconds: 500 + 300);
      expect(ctl().openPot(0), isNull);
      expect(h.container.refresh(potViewsProvider)[0]!.phase, PotPhase.running);
    });

    test('pots from rewards wait in a queue when the shelf is full and move up as slots free', () {
      // Three clay pots fill the shelf; the ladder's silver pot is the fourth.
      start(
        freshProfile().copyWith(
          daily: DailyState(pots: const PotShelf().add(PotTier.clay).$1.add(PotTier.clay).$1.add(PotTier.clay).$1),
        ),
      );
      for (var i = 0; i < 4; i++) {
        ctl().collectLadderStep(i);
      }
      expect(me().daily.pots.waiting, [PotTier.silver]);
      expect(h.container.read(potQueueProvider), 1);
      ctl().startPot(0);
      h.now = h.now.add(hour * 3);
      ctl().openPot(0);
      expect(me().daily.pots.slots[0]!.tier, PotTier.silver);
      expect(me().daily.pots.waiting, isEmpty);
    });
  });

  group('the Collection', () {
    test('buy, use and upgrade, with the reason when something is refused', () {
      expect(ctl().buyItem('star'), PurchaseBlock.none);
      expect(me().wallet.coins, 200);
      expect(me().collection.owns('star'), isTrue);
      expect(ctl().buyItem('star'), PurchaseBlock.owned);
      expect(ctl().buyItem('ruby_jelly'), PurchaseBlock.levelTooLow);
      expect(ctl().buyItem('nope'), PurchaseBlock.unknownItem);
      expect(ctl().selectItem('star'), isTrue);
      expect(ctl().selectItem('star'), isFalse, reason: 'already in use');
      expect(ctl().selectItem('moon'), isFalse, reason: 'not owned');
      expect(h.container.read(selectedItemProvider(ItemKind.piece)).id, 'star');
      expect(ctl().upgradeItem('lotus'), PurchaseBlock.cannotAfford, reason: '800 coins, 200 in the wallet');
      ctl().earn(coins: 5000);
      expect(ctl().upgradeItem('lotus'), PurchaseBlock.none);
      expect(me().collection.levelOf('lotus'), 2);
      expect(me().wallet.coins, 200 + 5000 - 800);
      expect(ctl().upgradeItem('moon'), PurchaseBlock.notOwned);
    });

    test('a refused purchase writes nothing', () {
      final writes = h.store.writes;
      ctl().buyItem('ruby_jelly');
      ctl().upgradeItem('moon');
      expect(h.store.writes, writes);
    });

    test('opening a tab clears its NEW badges; the XP boost follows what is in use', () {
      start(freshProfile().copyWith(collection: const Collection().withItem('ruby_jelly')));
      expect(h.container.read(lobbyBadgesProvider).newItems, 1);
      ctl().markCollectionSeen(ItemKind.dice);
      expect(me().collection.newCount(ItemKind.dice), 0);
      expect(h.container.read(xpBoostPercentProvider), 0);
      ctl().selectItem('ruby_jelly');
      expect(h.container.read(xpBoostPercentProvider), 5);
    });

    test('an achievement reached by a purchase pays out in the same step', () {
      final owned = {...Catalog.starterIds, 'star', 'moon', 'ruby_jelly', 'night_bazaar', 'ocean_glass', 'diya', 'crown'};
      start(freshProfile().copyWith(collection: Collection(owned: owned), wallet: freshProfile().wallet.copyWith(coins: 5000)));
      expect(me().progress.unlocked, isEmpty, reason: 'nothing is checked until something is paid');
      expect(ctl().upgradeItem('star'), PurchaseBlock.none);
      expect(me().progress.unlocked.keys, contains('collector'), reason: 'ten items owned');
      expect(me().wallet.gems, 20 + 15);
    });
  });

  group('the Mela Cup', () {
    test('the first run of the day is free; another needs the previous one finished and costs 300 coins', () {
      final run = ctl().startCupRun()!;
      expect(run.slots, hasLength(8));
      expect(me().wallet.coins, 1000);
      expect(ctl().startCupRun(), isNull, reason: 'a run is going');
      ctl().abandonCupRun();
      expect(h.container.read(cupProvider).hasActiveRun, isFalse);
      expect(h.container.refresh(cupFreeRunProvider), isFalse);
      expect(ctl().startCupRun(), isNotNull);
      expect(me().wallet.coins, 700);
      h.now = h.now.add(const Duration(days: 1));
      ctl().abandonCupRun();
      expect(tick(cupFreeRunProvider), isTrue);
      expect(ctl().startCupRun(), isNotNull);
      expect(me().wallet.coins, 700, reason: 'free again the next day');
    });

    test('the extra run needs the coins, and Parent controls can close it', () {
      ctl().startCupRun();
      ctl().abandonCupRun();
      ctl().spend(coins: 750);
      expect(ctl().startCupRun(), isNull);
      expect(me().wallet.coins, 250);
      ctl().earn(coins: 1000);
      ctl().updateSettings((s) => s.copyWith(parentCoinTablesOff: true));
      expect(ctl().startCupRun(), isNull);
    });

    test('winning three rounds without a recorded match crowns the champion: 25 gems; a loss ends the run', () {
      ctl().startCupRun();
      for (var i = 0; i < 2; i++) {
        expect(ctl().advanceCup(won: true)!.value.isChampion, isFalse);
      }
      final last = ctl().advanceCup(won: true)!;
      expect(last.value.isChampion, isTrue);
      expect(me().wallet.gems, 45);
      expect(me().progress.cup.cupsWon, 1);
      expect(ctl().advanceCup(won: true), isNull, reason: 'no run is going');
      ctl().startCupRun();
      expect(ctl().advanceCup(won: false)!.value.isEliminated, isTrue);
    });

    test('a recorded cup match takes the bracket step itself — advanceCup is not needed', () {
      ctl().startCupRun();
      final s = ctl().recordMatch(match(cup: true, players: 2));
      expect(s.cup!.wonMatch, isTrue);
      expect(me().progress.cup.run!.round, 1);
    });
  });

  group('the lobby\'s badges and views', () {
    test('a new player has a gift, free coins and a free spin waiting — and nothing else', () {
      final b = h.container.refresh(lobbyBadgesProvider);
      expect((b.gift, b.freeCoins, b.freeSpin), (true, true, true));
      expect((b.missions, b.pots, b.road, b.newItems), (0, 0, 0, 0));
      expect(b.any, isTrue);
      ctl().claimGift();
      ctl().collectFreeCoins();
      ctl().spinWheel(SpinMethod.free);
      final done = h.container.refresh(lobbyBadgesProvider);
      expect(done.any, isFalse);
    });

    test('the venue list: locked by level, and "your best" after a win', () {
      var v = h.container.read(venuesProvider);
      expect(v.map((x) => x.locked), [false, true, true, true, true, true, true, true]);
      expect(v.any((x) => x.isBest), isFalse);
      ctl().recordMatch(match(venueId: 'village_haat'));
      v = h.container.read(venuesProvider);
      expect(v.first.isBest, isTrue);
      expect((v.first.plays, v.first.wins), (1, 1));
    });

    test('stats, log, achievements and Insights follow the matches', () {
      ctl().recordMatch(match(venueId: 'village_haat', captures: 1));
      ctl().recordMatch(match(place: 3, practice: true));
      expect(h.container.read(statsProvider).played, 2);
      expect(h.container.read(playLogProvider).length, 2);
      expect(h.container.read(levelProvider), 1);
      final report = h.container.refresh(insightsProvider(InsightRange.all));
      expect((report.games, report.wins), (2, 1));
      final badges = h.container.read(achievementsProvider);
      expect(badges.where((a) => a.unlocked).map((a) => a.def.id), containsAll(['first_win', 'first_capture']));
    });

    test('the safety-net flag follows the wallet', () {
      expect(h.container.refresh(safetyNetProvider), isFalse);
      ctl().claimGift();
      ctl().spend(coins: me().wallet.coins - 10);
      expect(h.container.refresh(safetyNetProvider), isTrue);
    });
  });

  test('profiles keep their economies apart: switching player switches wallet, pots and missions', () {
    ctl().recordMatch(match(venueId: 'village_haat'));
    final other = ctl().addProfile(name: 'Tara', switchTo: true)!;
    expect(other, isNot('p1'));
    expect(me().wallet.coins, 1000);
    expect(me().daily.pots.filled, 0);
    expect(me().stats.played, 0);
    ctl().claimGift();
    ctl().switchProfile('p1');
    expect(h.container.read(saveProvider).activeProfile.progress.giftsClaimed, 0);
    expect(h.container.read(saveProvider).profile(other)!.progress.giftsClaimed, 1);
  });
}
