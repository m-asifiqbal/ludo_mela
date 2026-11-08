// A finished match turned into rewards (board C · XP, prizes, pots; board Pause for
// leaving): the pure core of SaveController.recordMatch. Each test is one sentence of
// the rules — "a win at Village Haat pays 200 coins" — checked on a whole profile.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/cup.dart';
import 'package:ludo_mela/domain/economy_rules.dart';
import 'package:ludo_mela/domain/match_rewards.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/pots.dart';
import 'package:ludo_mela/domain/profile.dart';
import 'package:ludo_mela/domain/profile_state.dart';
import 'package:ludo_mela/domain/road.dart';

import 'fixtures.dart';

void main() {
  final m = at(t0);

  group('XP: 20 for playing + 30 for a win + 5 per capture + 5 per piece home', () {
    test('a venue win with 2 captures and a piece home is 65 XP', () {
      final r = match(venueId: 'village_haat', captures: 2, home: 1);
      expect(MatchRewards.baseXp(r), 65);
      expect(MatchRewards.xpFor(r, 0), 65);
    });

    test('practice, pass & play and Wi-Fi give half; a Mela Cup round gives the full amount', () {
      final practice = match(practice: true, captures: 2, home: 1);
      expect(MatchRewards.baseXp(practice), 32);
      final passPlay = match(kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot], captures: 2, home: 1);
      expect(MatchRewards.baseXp(passPlay), 32);
      final wifi = match(kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot], captures: 2, home: 1);
      expect(MatchRewards.baseXp(wifi), 32);
      expect(MatchRewards.baseXp(match(cup: true, players: 2, captures: 2, home: 1)), 65);
      expect(MatchRewards.baseXp(match(place: 3, practice: true)), 10, reason: 'a loss in practice: half of 20');
    });

    test('a loss pays only for playing, captures and pieces home; leaving early gets no "played" XP and no win', () {
      expect(MatchRewards.baseXp(match(venueId: 'village_haat', place: 3, captures: 1, home: 2)), 35);
      expect(MatchRewards.baseXp(match(venueId: 'village_haat', place: 3, abandoned: true, captures: 1, home: 2)), 15);
      expect(MatchRewards.baseXp(match(venueId: 'village_haat', place: 1, abandoned: true)), 0, reason: 'leaving is a loss');
    });

    test('the Collection\'s XP boost is added on top (5 % steps)', () {
      final r = match(venueId: 'village_haat', captures: 2, home: 1);
      expect(MatchRewards.xpFor(r, 5), 68);
      expect(MatchRewards.xpFor(r, 45), 65 + 29);
    });
  });

  group('coins: the venue pays its prize by place; the entry was paid at the start', () {
    test('1st place at a 4-player table: three times the entry; 2nd: the entry back; 3rd and 4th: nothing', () {
      final coins = <int>[];
      for (final place in [1, 2, 3, 4]) {
        final out = MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', place: place), m);
        expect(out.summary.prizeCoins, out.profile.wallet.coins - 1000, reason: 'place $place');
        coins.add(out.summary.prizeCoins);
      }
      expect(coins, [300, 100, 0, 0]);
    });

    test('a 2-player table pays the winner twice the entry; a 3-player table 2× then the entry back', () {
      expect(MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', players: 2), m).summary.prizeCoins, 200);
      expect(MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', players: 3, place: 2), m).summary.prizeCoins, 100);
    });

    test('Mayhem chest coins are paid at venue tables only, and capped', () {
      final venue = MatchRewards.apply(freshProfile(), match(mode: GameMode.mayhem, venueId: 'village_haat', place: 3, chest: 120), m);
      expect(venue.summary.chestCoins, 120);
      expect(venue.summary.coins, 120);
      expect(venue.profile.wallet.coins, 1120);
      expect(MatchRewards.apply(freshProfile(), match(mode: GameMode.mayhem, practice: true, chest: 120), m).summary.chestCoins, 0);
      expect(MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', place: 3, chest: 999999), m).summary.chestCoins, EconomyRules.chestCoinCap);
    });

    test('practice, pass & play, Wi-Fi and Mela Cup rounds never pay coins', () {
      for (final r in [
        match(practice: true),
        match(venueId: 'village_haat', practice: true),
        match(venueId: 'village_haat', kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot]),
        match(venueId: 'village_haat', kinds: const [PlayerKind.human, PlayerKind.remote, PlayerKind.bot, PlayerKind.bot]),
        match(cup: true, players: 2),
      ]) {
        final out = MatchRewards.apply(freshProfile(), r, m);
        expect(out.summary.coins, 0);
        expect(out.profile.wallet.coins, 1000);
      }
    });

    test('leaving counts as a loss: no prize and no chest coins, the entry is gone', () {
      final out = MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', place: 1, abandoned: true, chest: 50), m);
      expect(out.summary.coins, 0);
      expect(out.summary.won, isFalse);
      expect(out.summary.abandoned, isTrue);
      expect(out.profile.wallet.coins, 1000);
      expect(out.profile.stats.abandoned, 1);
      expect(out.profile.stats.won, 0);
    });

    test('the summary remembers the balance before, for the count-up', () {
      final out = MatchRewards.apply(freshProfile().copyWith(wallet: freshProfile().wallet.add(coins: 500)), match(venueId: 'village_haat'), m);
      expect(out.summary.coinsBefore, 1500);
      expect(out.profile.wallet.coins, 1800);
    });
  });

  group('pots: a venue win fills an empty shelf slot with that venue\'s pot', () {
    test('the tier follows the venue', () {
      for (final (venue, tier) in [('village_haat', PotTier.clay), ('monsoon_garden', PotTier.silver), ('royal_palace', PotTier.gold)]) {
        final out = MatchRewards.apply(atLevel(30), match(venueId: venue), m);
        expect(out.summary.potEarned, tier, reason: venue);
        expect(out.profile.daily.pots.slots[0]!.tier, tier);
      }
    });

    test('a loss, practice and Mela Cup rounds earn no pot', () {
      for (final r in [match(venueId: 'village_haat', place: 2), match(practice: true), match(cup: true, players: 2)]) {
        final out = MatchRewards.apply(freshProfile(), r, m);
        expect(out.summary.potEarned, isNull);
        expect(out.summary.potShelfFull, isFalse);
        expect(out.profile.daily.pots.filled, 0);
      }
    });

    test('with all three slots full the win earns no pot — and the summary says the shelf was full', () {
      var shelf = const PotShelf();
      for (var i = 0; i < 3; i++) {
        shelf = shelf.add(PotTier.clay).$1;
      }
      final p = freshProfile().copyWith(daily: const DailyState().copyWith(pots: shelf));
      final out = MatchRewards.apply(p, match(venueId: 'village_haat'), m);
      expect(out.summary.potEarned, isNull);
      expect(out.summary.potShelfFull, isTrue);
      expect(out.profile.daily.pots.filled, 3);
      expect(out.profile.daily.pots.waiting, isEmpty, reason: 'a win\'s pot is not queued');
    });
  });

  group('levels and the Mela Road', () {
    test('crossing 150 XP is level 2: the summary lists the level and its Road reward (5 gems)', () {
      final out = MatchRewards.apply(freshProfile().copyWith(xp: 140), match(venueId: 'village_haat'), m);
      final s = out.summary;
      expect(s.xp, 50);
      expect((s.xpBefore, s.xpAfter), (140, 190));
      expect((s.levelBefore, s.levelAfter), (1, 2));
      expect(s.leveledUp, isTrue);
      expect(s.levelUps, [2]);
      expect(s.roadUnlocked.single.level, 2);
      expect(s.roadUnlocked.single.gems, 5);
      expect(out.profile.level, 2);
      expect(out.profile.progress.road.claimable(out.profile.level), [2], reason: 'the reward waits to be collected');
    });

    test('a big match can climb several levels at once', () {
      final out = MatchRewards.apply(freshProfile().copyWith(xp: 140), match(venueId: 'village_haat', captures: 40), m);
      expect(out.summary.levelUps, [2, 3]);
      expect([for (final r in out.summary.roadUnlocked) r.level], [2, 3]);
      expect(MelaRoad.rewardFor(3).venueId, 'lantern_bazaar', reason: 'level 3 opens the next table');
    });

    test('no level-up leaves the lists empty', () {
      final s = MatchRewards.apply(freshProfile(), match(venueId: 'village_haat'), m).summary;
      expect(s.leveledUp, isFalse);
      expect(s.levelUps, isEmpty);
      expect(s.roadUnlocked, isEmpty);
    });
  });

  group('XP boost from the Collection', () {
    test('Ruby Jelly in use adds 5 %', () {
      final p = freshProfile().copyWith(collection: const Collection().withItem('ruby_jelly').select('ruby_jelly'));
      final s = MatchRewards.apply(p, match(venueId: 'village_haat', captures: 2, home: 1), m).summary;
      expect(s.xpBoostPercent, 5);
      expect(s.xp, 68);
    });
  });

  group('everything else a match changes', () {
    test('stats, play log and the venue record', () {
      final out = MatchRewards.apply(
        freshProfile(),
        match(venueId: 'village_haat', captures: 2, home: 1, dice: const [3, 2, 1, 1, 2, 3], turns: 31, duration: const Duration(minutes: 12)),
        at(t0),
      );
      final p = out.profile;
      expect((p.stats.played, p.stats.won, p.stats.captures, p.stats.piecesHome, p.stats.sixes), (1, 1, 2, 1, 3));
      expect(p.stats.diceCounts, [3, 2, 1, 1, 2, 3]);
      expect(p.log.length, 1);
      final rec = p.log.records.single;
      expect((rec.at, rec.coins, rec.xp, rec.seconds, rec.place, rec.won), (t0, 300, 65, 720, 1, true));
      expect(p.progress.venuePlays, {'village_haat': 1});
      expect(p.progress.venueWins, {'village_haat': 1});
      expect(p.progress.bestVenueId, 'village_haat');
      final lost = MatchRewards.apply(p, match(venueId: 'village_haat', place: 2), m).profile;
      expect(lost.progress.venuePlays['village_haat'], 2);
      expect(lost.progress.venueWins['village_haat'], 1);
    });

    test('today\'s missions are made on the spot and move with the match', () {
      final out = MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', captures: 5, home: 3, dice: const [0, 0, 0, 0, 0, 3]), m);
      expect(out.profile.daily.missions.missions, hasLength(5));
      expect(out.profile.daily.missions.day, '2026-11-07');
      expect(out.summary.missionChanges, isNotEmpty, reason: 'a win with captures and pieces home moves most missions');
    });

    test('the first capture and the first win unlock their achievements and pay the gems', () {
      final out = MatchRewards.apply(freshProfile(), match(venueId: 'village_haat', captures: 1), m);
      expect([for (final a in out.summary.achievements) a.id], ['first_capture', 'first_win']);
      expect(out.summary.gems, 10);
      expect(out.profile.wallet.gems, 30);
      expect(out.profile.progress.unlocked.keys, containsAll(['first_capture', 'first_win']));
      final again = MatchRewards.apply(out.profile, match(venueId: 'village_haat', captures: 1), m);
      expect(again.summary.achievements, isEmpty, reason: 'each pays once');
      expect(again.profile.wallet.gems, 30);
    });
  });

  group('the Mela Cup', () {
    ProfileData inCup() => freshProfile().copyWith(
      progress: const Progress().copyWith(cup: const CupState().start(today: '2026-11-07', seed: 3)!.$1),
    );

    test('winning a cup round moves the bracket on; the summary carries the step', () {
      final out = MatchRewards.apply(inCup(), match(cup: true, players: 2), m);
      expect(out.summary.cup, isNotNull);
      expect(out.summary.cup!.wonMatch, isTrue);
      expect(out.profile.progress.cup.run!.round, 1);
      expect(out.profile.progress.cup.hasActiveRun, isTrue);
      expect(out.summary.coins, 0);
    });

    test('losing ends the run', () {
      final out = MatchRewards.apply(inCup(), match(cup: true, players: 2, place: 2), m);
      expect(out.summary.cup!.isEliminated, isTrue);
      expect(out.profile.progress.cup.hasActiveRun, isFalse);
    });

    test('winning the final pays 25 gems (and the Cup champion badge counts a cup)', () {
      var p = inCup();
      late MatchOutcome out;
      for (var i = 0; i < 3; i++) {
        out = MatchRewards.apply(p, match(cup: true, players: 2), m);
        p = out.profile;
      }
      expect(out.summary.cup!.isChampion, isTrue);
      expect(p.progress.cup.cupsWon, 1);
      expect(p.wallet.gems, greaterThanOrEqualTo(20 + 25));
      expect(out.summary.gems, greaterThanOrEqualTo(25));
    });

    test('a cup match with no run going changes no bracket', () {
      final out = MatchRewards.apply(freshProfile(), match(cup: true, players: 2), m);
      expect(out.summary.cup, isNull);
      expect(out.profile.progress.cup.run, isNull);
    });
  });
}
