// Mela Road (boards MelaRoad + C): one reward for every level — venues open at 3, 6, 9,
// 12, 16, 20, 25; Rare / Epic / Legendary items arrive at fixed levels; the rest follows
// a cycle that never ends. A level's reward waits until the player collects it.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/road.dart';
import 'package:ludo_mela/domain/venues.dart';

void main() {
  group('the table', () {
    test('every level from 2 to 50 has something: a reward to collect or a venue that opens', () {
      for (var l = 2; l <= 50; l++) {
        final r = MelaRoad.rewardFor(l);
        expect(r.level, l);
        expect(r.isInformational ? r.venueId != null : !r.grant.isEmpty, isTrue, reason: 'level $l');
      }
      expect(MelaRoad.upTo(50), hasLength(49));
      expect(MelaRoad.upTo(1), isEmpty);
      expect(MelaRoad.rewardFor(1).isInformational, isTrue);
      expect(MelaRoad.rewardFor(0).isInformational, isTrue);
    });

    test('venues open on the Road exactly where the Economy board says', () {
      for (final v in Venues.all.skip(1)) {
        expect(MelaRoad.rewardFor(v.minLevel).venueId, v.id, reason: v.name);
      }
      final informational = [for (var l = 2; l <= 50; l++) if (MelaRoad.rewardFor(l).isInformational) l];
      expect(informational, [3, 9, 12, 16, 20, 25], reason: 'only the openings with nothing else to collect');
    });

    test('fixed levels from the boards: +500 coins at 6, Epic pot at 10, +10 gems at 11, items at 8 / 18 / 22 / 30', () {
      expect(MelaRoad.rewardFor(6).coins, 500);
      expect(MelaRoad.rewardFor(10).pot, PotTier.epic);
      expect(MelaRoad.rewardFor(11).gems, 10);
      expect(MelaRoad.rewardFor(8).itemId, 'moon');
      expect(MelaRoad.rewardFor(18).itemId, 'midnight_gold');
      expect(MelaRoad.rewardFor(22).itemId, 'monsoon_garden');
      expect(MelaRoad.rewardFor(30).itemId, 'peacock');
      expect(MelaRoad.rewardFor(50).pot, PotTier.gold);
    });

    test('every item the Road hands over exists in the catalog; coins and gems are positive; all four prize kinds appear', () {
      var coins = 0, gems = 0, pots = 0, items = 0;
      for (final r in MelaRoad.upTo(50)) {
        if (r.itemId != null) {
          expect(Catalog.byId(r.itemId), isNotNull, reason: r.itemId);
          items++;
        }
        if (r.coins > 0) coins++;
        if (r.gems > 0) gems++;
        if (r.pot != null) pots++;
        expect(r.coins, greaterThanOrEqualTo(0));
        expect(r.gems, greaterThanOrEqualTo(0));
      }
      expect([coins > 5, gems > 3, pots > 3, items > 8], [true, true, true, true]);
    });

    test('the grant of a reward is exactly what it lists', () {
      final g = MelaRoad.rewardFor(50).grant;
      expect((g.coins, g.gems), (5000, 50));
      expect(g.pots, [PotTier.gold]);
      expect(MelaRoad.rewardFor(8).grant.items, ['moon']);
      expect(MelaRoad.rewardFor(3).grant.isEmpty, isTrue);
    });

    test('after the designed levels the cycle goes on — coins, a gem level, a silver pot every 5th, a gold pot every 10th', () {
      expect(MelaRoad.rewardFor(51).coins, 200 + 50 * 51);
      expect(MelaRoad.rewardFor(52).gems, 5 + 5 * 5);
      expect(MelaRoad.rewardFor(55).pot, PotTier.silver);
      expect(MelaRoad.rewardFor(60).pot, PotTier.gold);
      expect(MelaRoad.rewardFor(200).pot, PotTier.gold);
      for (var l = 51; l <= 300; l++) {
        expect(MelaRoad.rewardFor(l).isInformational, isFalse, reason: 'level $l');
      }
    });
  });

  group('collecting', () {
    test('a reward waits for the player once the level is reached; informational levels never wait', () {
      const s = RoadState();
      expect(s.claimable(1), isEmpty);
      expect(s.claimable(4), [2, 4], reason: 'level 3 only opens a venue');
      expect(s.isClaimed(3), isTrue);
      expect(s.isClaimed(2), isFalse);
    });

    test('claiming removes it from the waiting list; every other level stays', () {
      var s = const RoadState();
      s = s.claim(2);
      expect(s.claimable(8), [4, 5, 6, 7, 8]);
      s = s.claim(4).claim(5);
      expect(s.claimable(8), [6, 7, 8]);
      expect(s.isClaimed(4), isTrue);
    });

    test('JSON round trips; levels below 2 and junk are dropped', () {
      final s = const RoadState().claim(7).claim(2);
      expect(RoadState.fromJson(s.toJson()).claimed, {2, 7});
      expect(RoadState.fromJson({'claimed': [1, 0, -5, 'x', 6, null]}).claimed, {6});
      expect(RoadState.fromJson(const {}).claimed, isEmpty);
    });
  });
}
