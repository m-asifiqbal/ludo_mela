// The lucky wheel (boards Wheel + C): eight segments with fixed odds, one free spin a
// day, one extra spin for an ad, bonus spins from the daily gift, more for 10 gems.
// The draw takes a Random, so these tests pin it.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/wheel.dart';

import 'fixtures.dart';

void main() {
  const hour = Duration(hours: 1);

  group('the segments', () {
    test('the odds are the board\'s and add up to 100 %', () {
      final s = Wheel.segments;
      expect(s, hasLength(8));
      expect([for (final x in s) x.percent], [30, 15, 22, 9, 12, 2, 6, 4]);
      expect(s.fold(0, (a, x) => a + x.percent), 100);
      expect([for (final x in s) (x.kind, x.amount)], [
        (WheelPrizeKind.coins, 100),
        (WheelPrizeKind.gems, 2),
        (WheelPrizeKind.coins, 250),
        (WheelPrizeKind.gems, 5),
        (WheelPrizeKind.coins, 500),
        (WheelPrizeKind.gems, 10),
        (WheelPrizeKind.coins, 1000),
        (WheelPrizeKind.dice, 0),
      ]);
    });

    test('a roll in [0, 100) lands on the segment whose share holds it — edges included', () {
      expect(Wheel.segmentFor(0), 0);
      expect(Wheel.segmentFor(29.999), 0);
      expect(Wheel.segmentFor(30), 1);
      expect(Wheel.segmentFor(44.999), 1);
      expect(Wheel.segmentFor(45), 2);
      expect(Wheel.segmentFor(95.999), 6);
      expect(Wheel.segmentFor(96), 7);
      expect(Wheel.segmentFor(99.999), 7);
    });

    test('over many spins every segment comes up about as often as its odds say', () {
      final rng = Random(2026);
      const n = 40000;
      final hits = List<int>.filled(8, 0);
      for (var i = 0; i < n; i++) {
        hits[Wheel.draw(rng)]++;
      }
      for (var i = 0; i < 8; i++) {
        final share = hits[i] * 100 / n;
        expect(share, closeTo(Wheel.segments[i].percent, 1.0), reason: 'segment $i');
      }
    });
  });

  group('what a segment pays', () {
    test('coins and gems', () {
      final c = Wheel.resolve(2, const Collection(), Random(1));
      expect(c.grant.coins, 250);
      expect(c.segment, 2);
      expect(Wheel.resolve(5, const Collection(), Random(1)).grant.gems, 10);
    });

    test('the Rare dice segment gives a Rare dice you do not own yet', () {
      final r = Wheel.resolve(7, const Collection(), Random(3));
      expect(r.diceId, isNotNull);
      expect(Catalog.byId(r.diceId)!.rarity, Rarity.rare);
      expect(Catalog.byId(r.diceId)!.kind, ItemKind.dice);
      expect(r.grant.items, [r.diceId]);
      expect(r.duplicate, isFalse);
    });

    test('with one Rare dice owned it can only be the other; with both owned it pays 2,000 coins', () {
      final rares = [for (final d in Catalog.dice) if (d.rarity == Rarity.rare) d.id];
      expect(rares, hasLength(2));
      final one = const Collection().withItem(rares.first);
      for (var seed = 0; seed < 10; seed++) {
        expect(Wheel.resolve(7, one, Random(seed)).diceId, rares.last);
      }
      final all = one.withItem(rares.last);
      final r = Wheel.resolve(7, all, Random(1));
      expect(r.duplicate, isTrue);
      expect(r.diceId, isNull);
      expect(r.grant.coins, 2000);
      expect(r.grant.items, isEmpty);
    });
  });

  group('spins', () {
    test('a fresh wheel: the free spin is ready, the ad spin is there, no bonus spins', () {
      final st = const WheelState().status(at(t0));
      expect(st.freeReady, isTrue);
      expect(st.adSpinAvailable, isTrue);
      expect(st.bonusSpins, 0);
      expect(st.hasFreeSpin, isTrue);
      expect(st.freeRemaining, Duration.zero);
    });

    test('one free spin every 24 hours, counted from the spin', () {
      final used = const WheelState().use(SpinMethod.free, at(t0))!;
      expect(used.totalSpins, 1);
      expect(used.status(at(t0.add(hour * 23))).freeReady, isFalse);
      expect(used.status(at(t0.add(hour * 23))).freeRemaining, hour);
      expect(used.use(SpinMethod.free, at(t0.add(hour * 23))), isNull);
      expect(used.status(at(t0.add(hour * 24))).freeReady, isTrue);
      expect(used.use(SpinMethod.free, at(t0.add(hour * 24)))!.totalSpins, 2);
    });

    test('moving the clock forward does not bring the free spin back', () {
      final used = const WheelState().use(SpinMethod.free, at(t0, up: 100))!;
      expect(used.status(at(t0.add(hour * 30), up: 100 + 3600)).freeReady, isFalse);
    });

    test('one ad spin a day; it is back at local midnight', () {
      final used = const WheelState().use(SpinMethod.ad, at(DateTime(2026, 11, 7, 23, 50)))!;
      expect(used.adSpins, 1);
      expect(used.status(at(DateTime(2026, 11, 7, 23, 59))).adSpinAvailable, isFalse);
      expect(used.use(SpinMethod.ad, at(DateTime(2026, 11, 7, 23, 59))), isNull);
      expect(used.status(at(DateTime(2026, 11, 8, 0, 1))).adSpinAvailable, isTrue);
      expect(used.use(SpinMethod.ad, at(DateTime(2026, 11, 8, 0, 1)))!.adSpins, 1, reason: 'a new day, a new count');
    });

    test('bonus spins (daily gift Day 5) are used one by one and need no wait', () {
      var s = const WheelState().withBonusSpins(2);
      expect(s.allows(SpinMethod.bonus, at(t0)), isTrue);
      s = s.use(SpinMethod.bonus, at(t0))!;
      expect(s.bonusSpins, 1);
      s = s.use(SpinMethod.bonus, at(t0))!;
      expect(s.bonusSpins, 0);
      expect(s.use(SpinMethod.bonus, at(t0)), isNull);
      expect(s.totalSpins, 2);
      expect(s.freeTimer, isNull, reason: 'a bonus spin does not use up the daily free one');
    });

    test('a spin bought with gems is always allowed here (the controller charges the 10 gems)', () {
      final s = const WheelState().use(SpinMethod.free, at(t0))!;
      final bought = s.use(SpinMethod.gems, at(t0))!;
      expect(bought.totalSpins, 2);
      expect(bought.freeTimer, s.freeTimer);
    });

    test('JSON round trip; garbage loads as a fresh wheel', () {
      final s = const WheelState().withBonusSpins(1).use(SpinMethod.free, at(t0, up: 3))!.use(SpinMethod.ad, at(t0))!;
      final back = WheelState.fromJson(s.toJson());
      expect((back.adDay, back.adSpins, back.bonusSpins, back.totalSpins), (s.adDay, 1, 1, 2));
      expect(back.freeTimer, s.freeTimer);
      final fresh = WheelState.fromJson(const {'bonus': 'x', 'free': 7});
      expect(fresh.bonusSpins, 0);
      expect(fresh.status(at(t0)).freeReady, isTrue);
    });
  });
}
