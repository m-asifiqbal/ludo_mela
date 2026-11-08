// Daily missions (boards Missions + C): five tasks a day fed by finished matches, points
// 25 / 50 / 75 / 100 unlocking 200 coins · 3 gems · a clay pot · a silver pot, one free
// swap, a new set at local midnight, never an ad.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_engine/ludo_engine.dart';
import 'package:ludo_mela/domain/grant.dart';
import 'package:ludo_mela/domain/mission_pool.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/pot_tier.dart';

import 'fixtures.dart';

/// A day whose five missions are exactly [ids] (so a test controls what counts).
MissionsState setOf(List<String> ids, {String day = '2026-11-07'}) =>
    MissionsState(day: day, missions: [for (final id in ids) Mission(id)]);

void main() {
  group('the pool and the daily set', () {
    test('the day recipe adds up to 100 points: 25 + 20 + 15 + 20 + 20', () {
      expect(MissionPool.recipe.fold(0, (a, t) => a + t.points), 100);
      expect(MissionPool.recipe, hasLength(5));
      expect([for (final t in MissionTier.values) t.points], [15, 20, 25]);
    });

    test('ids are unique, every mission is claimable for coins, and each size has enough to choose from', () {
      final ids = [for (final d in MissionPool.defs) d.id];
      expect(ids.toSet(), hasLength(ids.length));
      for (final d in MissionPool.defs) {
        expect(d.target, greaterThan(0), reason: d.id);
        expect(d.coins, inInclusiveRange(100, 150), reason: d.id);
        expect(d.points, d.tier.points);
      }
      for (final tier in MissionTier.values) {
        expect(MissionPool.defs.where((d) => d.tier == tier).length, greaterThanOrEqualTo(4), reason: '$tier');
      }
      expect(MissionPool.byId('six3')!.title, 'Roll three 6s');
      expect(MissionPool.byId('nope'), isNull);
    });

    test('a day gets five different missions of the recipe sizes, the same for the same player and day', () {
      final a = MissionsState.generate('p1', '2026-11-07');
      expect(a.missions, hasLength(5));
      expect([for (final m in a.missions) m.def.tier], MissionPool.recipe);
      expect({for (final m in a.missions) m.def.key}, hasLength(5), reason: 'no two of one kind');
      expect(a.missions.every((m) => m.progress == 0 && !m.claimed), isTrue);
      final again = MissionsState.generate('p1', '2026-11-07');
      expect([for (final m in again.missions) m.defId], [for (final m in a.missions) m.defId]);
      final other = {
        for (var d = 1; d <= 20; d++)
          [for (final m in MissionsState.generate('p1', '2026-11-${d.toString().padLeft(2, '0')}').missions) m.defId].join(),
      };
      expect(other.length, greaterThan(10), reason: 'the days differ');
      final family = {for (final id in ['a', 'b', 'c', 'd', 'e', 'f']) [for (final m in MissionsState.generate(id, '2026-11-07').missions) m.defId].join()};
      expect(family.length, greaterThan(1), reason: 'family members get their own sets');
    });
  });

  group('progress is fed by finished matches', () {
    test('wins, captures, pieces home and plain "played" count what happened', () {
      var s = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']);
      s = s.applyMatch(match(place: 1, captures: 2, home: 1));
      expect([for (final m in s.missions) m.progress], [1, 2, 1, 1, 1]);
      s = s.applyMatch(match(place: 2, captures: 4, home: 3));
      expect([for (final m in s.missions) m.progress], [1, 5, 3, 2, 1], reason: 'capped at the target; a loss is no win');
    });

    test('sixes come from the dice counts, mode missions from the mode, pass & play from the table', () {
      var s = setOf(['six3', 'mayhem', 'pass_play', 'quick', 'cards3']);
      s = s.applyMatch(match(mode: GameMode.mayhem, dice: const [3, 2, 1, 4, 2, 2], cards: 2));
      expect(s.missions[0].progress, 2);
      expect(s.missions[1].progress, 1);
      expect(s.missions[2].progress, 0, reason: 'one human at the table');
      expect(s.missions[3].progress, 0, reason: 'not a Quick match');
      expect(s.missions[4].progress, 2);
      s = s.applyMatch(
        match(mode: GameMode.quick, kinds: const [PlayerKind.human, PlayerKind.human, PlayerKind.bot, PlayerKind.bot], dice: const [0, 0, 0, 0, 0, 1], cards: 5),
      );
      expect(s.missions[0].progress, 3);
      expect(s.missions[2].progress, 1, reason: 'two humans on this phone');
      expect(s.missions[3].progress, 1);
      expect(s.missions[4].progress, 3);
    });

    test('Mela Tour wins and clean wins need the right kind of win', () {
      var s = setOf(['win_tour', 'win_clean', 'win2', 'play1', 'home1']);
      s = s.applyMatch(match(place: 1, venueId: 'village_haat', captured: 1));
      expect(s.missions[0].progress, 1);
      expect(s.missions[1].progress, 0, reason: 'a piece was captured');
      s = s.applyMatch(match(place: 1, practice: true));
      expect(s.missions[1].progress, 1);
      expect(s.missions[0].progress, 1, reason: 'practice is not a Mela Tour match');
    });

    test('leaving early counts for nothing but the pieces that really got home or were captured', () {
      var s = setOf(['play1', 'win2', 'capture2', 'home1', 'quick']);
      s = s.applyMatch(match(abandoned: true, place: 4, captures: 1, home: 1));
      expect(s.missions[0].progress, 0, reason: 'played does not count when you leave');
      expect(s.missions[1].progress, 0);
      expect(s.missions[2].progress, 1);
      expect(s.missions[3].progress, 1);
    });

    test('a finished mission is left alone; the puzzle only moves the puzzle mission', () {
      var s = setOf(['puzzle', 'play1', 'win2', 'capture5', 'home3']);
      s = s.applyMatch(match()).applyMatch(match());
      expect(s.missions[1].progress, 1, reason: 'finished: it stays at its target');
      expect(s.missions[2].progress, 2);
      final solved = s.applyPuzzleSolved();
      expect(solved.missions[0].done, isTrue);
      expect([for (final m in solved.missions.skip(1)) m.progress], [for (final m in s.missions.skip(1)) m.progress]);
    });

    test('changesTo lists exactly the missions that moved, with before / after', () {
      final before = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']);
      final after = before.applyMatch(match(place: 1, captures: 1));
      final changes = before.changesTo(after);
      expect(changes.map((c) => c.index), [0, 1, 3, 4]);
      expect(changes.firstWhere((c) => c.defId == 'play1').completedNow, isTrue);
      expect(changes.firstWhere((c) => c.defId == 'win2').completedNow, isFalse);
      expect(changes.first.before, 0);
      expect(changes.first.after, 1);
      expect(changes.first.target, 2);
    });
  });

  group('claiming and the milestones', () {
    MissionsState finished(List<String> ids) {
      var s = setOf(ids);
      s = MissionsState(
        day: s.day,
        missions: [for (final m in s.missions) Mission(m.defId, progress: m.target)],
      );
      return s;
    }

    test('claiming pays the mission\'s coins and adds its points; unfinished and claimed ones refuse', () {
      var s = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']);
      expect(s.claim(0), isNull, reason: 'not finished');
      s = finished(['win2', 'capture5', 'home3', 'play3', 'play1']);
      final (next, grant) = s.claim(4)!;
      expect(grant.coins, 100);
      expect(next.points, 15);
      expect(next.missions[4].claimed, isTrue);
      expect(next.claim(4), isNull, reason: 'already claimed');
      expect(s.claim(-1), isNull);
      expect(s.claim(5), isNull);
    });

    test('25 / 50 / 75 / 100 points unlock 200 coins · 3 gems · a clay pot · a silver pot, once each', () {
      expect([for (final m in MissionsState.milestones) m.at], [25, 50, 75, 100]);
      expect(MissionsState.milestones[0].grant.coins, 200);
      expect(MissionsState.milestones[1].grant.gems, 3);
      expect(MissionsState.milestones[2].grant.pots, [PotTier.clay]);
      expect(MissionsState.milestones[3].grant.pots, [PotTier.silver]);

      var s = finished(['win2', 'capture5', 'home3', 'play3', 'play1']); // 25 + 20 + 20 + 20 + 15
      expect(s.claimMilestone(25), isNull, reason: 'no points yet');
      var points = 0;
      for (var i = 0; i < 5; i++) {
        s = s.claim(i)!.$1;
        points += s.missions[i].points;
        expect(s.points, points);
      }
      expect(s.points, 100);
      expect(s.readyMilestones.map((m) => m.at), [25, 50, 75, 100]);
      for (final at in [25, 50, 75, 100]) {
        final r = s.claimMilestone(at)!;
        s = r.$1;
        expect(r.$2.isEmpty, isFalse);
        expect(s.claimMilestone(at), isNull, reason: '$at taken once');
      }
      expect(s.readyMilestones, isEmpty);
      expect(s.hasClaimable, isFalse);
    });

    test('hasClaimable and claimableCount drive the lobby badge', () {
      var s = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']);
      expect(s.hasClaimable, isFalse);
      s = s.applyMatch(match());
      expect(s.claimableCount, 1);
      expect(s.hasClaimable, isTrue);
    });
  });

  group('the free swap', () {
    test('replaces an unfinished mission with another of the same size, once a day', () {
      final s = MissionsState.generate('p1', '2026-11-07');
      final swapped = s.swap(1, 99)!;
      expect(swapped.swapUsed, isTrue);
      expect(swapped.missions[1].defId, isNot(s.missions[1].defId));
      expect(swapped.missions[1].def.tier, s.missions[1].def.tier);
      expect({for (final m in swapped.missions) m.def.key}, hasLength(5));
      expect(swapped.missions[0].defId, s.missions[0].defId);
      expect(swapped.swap(2, 5), isNull, reason: 'one a day');
    });

    test('a finished or claimed mission cannot be swapped, nor an index that is not there', () {
      var s = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']).applyMatch(match());
      expect(s.swap(4, 1), isNull, reason: 'play1 is finished');
      expect(s.swap(9, 1), isNull);
      expect(s.swap(-1, 1), isNull);
    });
  });

  group('midnight', () {
    test('the same day keeps the set; a new day pays what was finished and starts a new set', () {
      var s = setOf(['win2', 'capture5', 'home3', 'play3', 'play1']).applyMatch(match(place: 1, captures: 5, home: 3));
      final (kept, nothing) = s.rollover('2026-11-07', 'p1');
      expect(kept, same(s));
      expect(nothing.isEmpty, isTrue);
      s = s.claim(4)!.$1; // play1 claimed: 15 points, no milestone yet
      final (next, paid) = s.rollover('2026-11-08', 'p1');
      // Unclaimed but finished: capture5 (150) + home3 (150) + play3 not finished (1/3). Points 15 + 20 + 20 = 55 → 25 and 50 reached.
      expect(next.day, '2026-11-08');
      expect(next.swapUsed, isFalse);
      expect(next.points, 0);
      expect(next.claimedMilestones, isEmpty);
      expect(paid.coins, 150 + 150 + 200, reason: 'two finished missions and the 25-point milestone');
      expect(paid.gems, 3, reason: 'the 50-point milestone');
    });

    test('a fresh profile gets its first set without any payout', () {
      final (s, paid) = const MissionsState().rollover('2026-11-07', 'p1');
      expect(s.missions, hasLength(5));
      expect(paid.isEmpty, isTrue);
      expect(Grant.none.isEmpty, isTrue);
    });
  });

  group('JSON', () {
    test('round trips progress, claims, milestones and the swap', () {
      var s = MissionsState.generate('p1', '2026-11-07').applyMatch(match(place: 1, captures: 3, home: 2));
      s = MissionsState(day: s.day, missions: s.missions, claimedMilestones: {25}, swapUsed: true);
      final back = MissionsState.fromJson(s.toJson());
      expect(back.day, s.day);
      expect([for (final m in back.missions) (m.defId, m.progress, m.claimed)], [for (final m in s.missions) (m.defId, m.progress, m.claimed)]);
      expect(back.claimedMilestones, {25});
      expect(back.swapUsed, isTrue);
    });

    test('an unknown mission id (a newer build) is dropped; progress is clamped to the target', () {
      final s = MissionsState.fromJson({
        'day': '2026-11-07',
        'missions': [
          {'id': 'from_the_future', 'p': 1},
          {'id': 'win2', 'p': 99, 'c': true},
          'junk',
        ],
        'ms': [25, 'x'],
      });
      expect(s.missions, hasLength(1));
      expect(s.missions.first.progress, 2);
      expect(s.missions.first.claimed, isTrue);
      expect(s.claimedMilestones, {25});
    });
  });
}
