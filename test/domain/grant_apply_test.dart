// Every reward — gift, ladder, wheel, missions, pots, Road, cup, achievements — is a
// Grant put into a profile by ONE function. These tests pin what it does with the
// awkward cases: duplicates, shards, a full shelf, bonus spins, and the daily catch-up.

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/grant.dart';
import 'package:ludo_mela/domain/grant_apply.dart';
import 'package:ludo_mela/domain/missions.dart';
import 'package:ludo_mela/domain/pot_tier.dart';

import 'fixtures.dart';

void main() {
  final p0 = freshProfile();

  group('Grant', () {
    test('adding merges amounts, pots, items and shards; times() multiplies amounts but not items', () {
      const a = Grant(coins: 100, gems: 1, spins: 1, pots: [PotTier.clay], items: ['moon'], shards: {'crown': 2});
      const b = Grant(coins: 50, pots: [PotTier.gold], shards: {'crown': 3, 'ocean_glass': 1});
      final sum = a + b;
      expect((sum.coins, sum.gems, sum.spins), (150, 1, 1));
      expect(sum.pots, [PotTier.clay, PotTier.gold]);
      expect(sum.items, ['moon']);
      expect(sum.shards, {'crown': 5, 'ocean_glass': 1});
      final twice = a.times(2);
      expect((twice.coins, twice.gems, twice.spins), (200, 2, 2));
      expect(twice.pots, [PotTier.clay, PotTier.clay]);
      expect(twice.items, ['moon']);
      expect(twice.shards, {'crown': 4});
      expect(Grant.none.isEmpty, isTrue);
      expect(a.isEmpty, isFalse);
    });
  });

  group('applyGrant', () {
    test('coins and gems go to the wallet', () {
      final (p, r) = applyGrant(p0, const Grant(coins: 250, gems: 3));
      expect(p.wallet.coins, 1250);
      expect(p.wallet.gems, 23);
      expect((r.coins, r.gems), (250, 3));
    });

    test('a new item is owned and marked NEW', () {
      final (p, r) = applyGrant(p0, const Grant(items: ['moon']));
      expect(p.collection.owns('moon'), isTrue);
      expect(p.collection.unseen, {'moon'});
      expect(r.itemsGranted, ['moon']);
      expect(r.duplicateCoins, 0);
    });

    test('an item you already own turns into coins by its rarity', () {
      for (final (id, coins) in [('lotus', 500), ('moon', 2000), ('crown', 4000), ('peacock', 8000), ('elephant', 3000)]) {
        final owned = applyGrant(p0, Grant(items: [id])).$1;
        final (p, r) = applyGrant(owned, Grant(items: [id]));
        expect(r.duplicateCoins, coins, reason: id);
        expect(r.itemsGranted, isEmpty);
        expect(p.wallet.coins, owned.wallet.coins + coins, reason: id);
        expect(r.coins, coins);
      }
    });

    test('an unknown item id (from a newer build) is skipped', () {
      final (p, r) = applyGrant(p0, const Grant(items: ['from_the_future']));
      expect(p.collection.owned, Catalog.starterIds);
      expect(r.itemsGranted, isEmpty);
    });

    test('shards add up; the last one unlocks the item and says so', () {
      var (p, r) = applyGrant(p0, const Grant(shards: {'marble_palace': 20}));
      expect(p.collection.shardsOf('marble_palace'), 20);
      expect(r.unlockedByShards, isEmpty);
      (p, r) = applyGrant(p, const Grant(shards: {'marble_palace': 10}));
      expect(p.collection.owns('marble_palace'), isTrue);
      expect(r.unlockedByShards, ['marble_palace']);
    });

    test('pots take the free slots first; when the shelf is full they wait in the queue — never lost', () {
      final (p, r) = applyGrant(p0, const Grant(pots: [PotTier.clay, PotTier.silver, PotTier.gold, PotTier.clay]));
      expect(p.daily.pots.filled, 3);
      expect(r.shelvedPots, [PotTier.clay, PotTier.silver, PotTier.gold]);
      expect(r.queuedPots, [PotTier.clay]);
      expect(p.daily.pots.waiting, [PotTier.clay]);
    });

    test('wheel spins become bonus spins', () {
      final (p, r) = applyGrant(p0, const Grant(spins: 2));
      expect(p.daily.wheel.bonusSpins, 2);
      expect(r.spins, 2);
    });

    test('an empty grant changes nothing', () {
      final (p, r) = applyGrant(p0, Grant.none);
      expect(p.wallet, p0.wallet);
      expect(p.collection.owned, p0.collection.owned);
      expect(r.coins, 0);
    });
  });

  group('syncDay (the daily catch-up)', () {
    test('a profile with no missions gets today\'s set', () {
      final p = syncDay(p0, at(t0));
      expect(p.daily.missions.day, '2026-11-07');
      expect(p.daily.missions.missions, hasLength(5));
      expect(p.wallet, p0.wallet, reason: 'nothing to pay');
    });

    test('the same day returns the very same profile', () {
      final p = syncDay(p0, at(t0));
      expect(syncDay(p, at(t0.add(const Duration(hours: 3)))), same(p));
    });

    test('a new day pays yesterday\'s finished-but-unclaimed missions and milestones, then starts a new set', () {
      var p = syncDay(p0, at(t0));
      final done = MissionsState(
        day: '2026-11-07',
        missions: [for (final m in p.daily.missions.missions) Mission(m.defId, progress: m.target)],
      );
      p = p.copyWith(daily: p.daily.copyWith(missions: done));
      final next = syncDay(p, at(DateTime(2026, 11, 8, 0, 5)));
      expect(next.daily.missions.day, '2026-11-08');
      expect(next.daily.missions.points, 0);
      final coinsFromMissions = [for (final m in done.missions) m.coins].fold(0, (a, b) => a + b);
      expect(next.wallet.coins, 1000 + coinsFromMissions + 200, reason: 'every mission plus the 25-point milestone');
      expect(next.wallet.gems, 20 + 3, reason: 'the 50-point milestone');
      expect(next.daily.pots.filled, 2, reason: 'the clay pot at 75 and the silver pot at 100');
    });
  });
}
