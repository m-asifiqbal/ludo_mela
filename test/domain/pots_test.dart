// Mela pots (board C + Main + Terms "Pot odds"): three shelf slots, one countdown at a
// time (clay 3 h, silver 8 h, gold 12 h), 1 gem skips 20 minutes, contents and odds are
// always shown, and a pot is earned — never bought.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/domain/pots.dart';

import 'fixtures.dart';

void main() {
  const hour = Duration(hours: 1);

  group('tiers and contents', () {
    test('clay 3 h, silver 8 h, gold 12 h; the Epic and Mela pots run 12 h', () {
      expect([for (final t in [PotTier.clay, PotTier.silver, PotTier.gold]) t.duration.inHours], [3, 8, 12]);
      expect(PotTier.epic.duration.inHours, 12);
      expect(PotTier.mela.duration.inHours, 12);
      expect(PotTier.byName('silver'), PotTier.silver);
      expect(PotTier.byName('nope'), isNull);
      expect(PotTier.clay.label, 'Clay pot');
    });

    test('every pot shows what is inside with its odds: coins always, gems and shards sometimes', () {
      for (final tier in PotTier.values) {
        final lines = PotTable.linesFor(tier);
        expect(lines.first.kind, PotLineKind.coins, reason: '$tier');
        expect(lines.first.percent, 100);
        for (final l in lines) {
          expect(l.percent, inInclusiveRange(1, 100));
          expect(l.min, lessThanOrEqualTo(l.max));
        }
      }
      expect(PotTable.linesFor(PotTier.clay).map((l) => l.kind), [PotLineKind.coins, PotLineKind.gems, PotLineKind.shards]);
      expect(PotTable.linesFor(PotTier.gold).last.kind, PotLineKind.item);
      expect(PotTable.linesFor(PotTier.mela).last.percent, 100, reason: 'the festive pot always holds a Rare item');
    });

    test('a better pot pays better: coin ranges grow clay → silver → gold', () {
      int top(PotTier t) => PotTable.linesFor(t).first.max;
      expect(top(PotTier.clay), lessThan(top(PotTier.silver)));
      expect(top(PotTier.silver), lessThan(top(PotTier.gold)));
    });
  });

  group('opening (a seeded Random pins every draw)', () {
    test('a clay pot: 80–200 coins, gems 1–2 about one time in five, a shard of an unowned Rare item about one in four', () {
      final rng = Random(11);
      const n = 4000;
      var withGems = 0, withShards = 0;
      for (var i = 0; i < n; i++) {
        final g = PotTable.open(PotTier.clay, collection: const Collection(), level: 5, rng: rng);
        expect(g.coins, inInclusiveRange(80, 200));
        if (g.gems > 0) {
          withGems++;
          expect(g.gems, inInclusiveRange(1, 2));
        }
        if (g.shards.isNotEmpty) {
          withShards++;
          expect(g.shards.keys.single, isIn(['ocean_glass', 'marble_palace']));
          expect(g.shards.values.single, inInclusiveRange(1, 2));
        }
        expect(g.items, isEmpty);
        expect(g.pots, isEmpty);
      }
      expect(withGems * 100 / n, closeTo(20, 3));
      expect(withShards * 100 / n, closeTo(25, 3));
    });

    test('shards only go to items the player does not own and the level allows; with none left they pay coins', () {
      final rng = Random(5);
      for (var i = 0; i < 300; i++) {
        final g = PotTable.open(PotTier.silver, collection: const Collection(), level: 1, rng: rng);
        expect(g.shards, isEmpty, reason: 'no Epic shard item is open at level 1');
      }
      final owned = Collection(owned: {...Catalog.starterIds, 'ocean_glass', 'marble_palace'});
      for (var i = 0; i < 300; i++) {
        final g = PotTable.open(PotTier.clay, collection: owned, level: 20, rng: rng);
        expect(g.shards, isEmpty);
      }
    });

    test('a gold pot sometimes holds a Rare item the player does not own; when they own every Rare it pays 2,000 coins instead', () {
      final rng = Random(23);
      const n = 3000;
      var items = 0;
      for (var i = 0; i < n; i++) {
        final g = PotTable.open(PotTier.gold, collection: const Collection(), level: 25, rng: rng);
        expect(g.coins, greaterThanOrEqualTo(600));
        for (final id in g.items) {
          items++;
          expect(Catalog.byId(id)!.rarity, Rarity.rare);
          expect(Catalog.byId(id)!.price.kind, isNot(PriceKind.event));
        }
      }
      expect(items * 100 / n, closeTo(20, 3));
      final all = Collection(owned: {for (final r in Catalog.all.where((i) => i.rarity == Rarity.rare)) r.id, ...Catalog.starterIds});
      var paid = 0;
      for (var i = 0; i < n; i++) {
        final g = PotTable.open(PotTier.gold, collection: all, level: 25, rng: rng);
        expect(g.items, isEmpty);
        if (g.coins >= 2600) paid++;
      }
      expect(paid * 100 / n, closeTo(20, 3), reason: 'the 20 % line pays Rare duplicates as coins');
    });

    test('an Epic pot never drops a board; the festive Mela pot always holds one unowned Rare item', () {
      final rng = Random(2);
      for (var i = 0; i < 2000; i++) {
        final g = PotTable.open(PotTier.epic, collection: const Collection(), level: 30, rng: rng);
        for (final id in g.items) {
          expect(Catalog.byId(id)!.kind, isNot(ItemKind.board));
          expect(Catalog.byId(id)!.rarity, Rarity.epic);
        }
      }
      for (var i = 0; i < 200; i++) {
        final g = PotTable.open(PotTier.mela, collection: const Collection(), level: 1, rng: rng);
        expect(g.items, hasLength(1));
        expect(Catalog.byId(g.items.single)!.rarity, Rarity.rare);
        expect(g.coins, 1500, reason: 'board "Daily gift" Day 7: 1,500 coins');
        expect(g.gems, 15, reason: '... + 15 gems, every time (gems "days 2/4/6/7")');
      }
    });

    test('the same seed opens the same pot', () {
      Object roll(int seed) => PotTable.open(PotTier.gold, collection: const Collection(), level: 25, rng: Random(seed)).toString();
      expect(roll(4), roll(4));
      expect({for (var s = 0; s < 20; s++) roll(s)}.length, greaterThan(10));
    });
  });

  group('the shelf', () {
    test('a win fills the first empty slot; with three pots a new one is dropped, a guaranteed one waits in the queue', () {
      var shelf = const PotShelf();
      expect(shelf.filled, 0);
      for (var i = 0; i < 3; i++) {
        final (next, placement) = shelf.add(PotTier.clay);
        expect(placement.kind, PotPlacementKind.slot);
        expect(placement.slot, i);
        shelf = next;
      }
      expect(shelf.isFull, isTrue);
      expect(shelf.firstEmpty, isNull);
      final (unchanged, dropped) = shelf.add(PotTier.gold);
      expect(dropped.kind, PotPlacementKind.dropped);
      expect(unchanged, same(shelf));
      final (queuedShelf, queued) = shelf.add(PotTier.gold, queue: true);
      expect(queued.kind, PotPlacementKind.queued);
      expect(queuedShelf.waiting, [PotTier.gold]);
    });

    test('opening a pot refills its slot from the queue, oldest first', () {
      var shelf = const PotShelf();
      for (final t in [PotTier.clay, PotTier.clay, PotTier.clay]) {
        shelf = shelf.add(t).$1;
      }
      shelf = shelf.add(PotTier.silver, queue: true).$1.add(PotTier.gold, queue: true).$1;
      final m = at(t0);
      final started = shelf.start(1, m)!;
      final ready = at(t0.add(hour * 3));
      final (after, tier) = started.take(1, ready)!;
      expect(tier, PotTier.clay);
      expect(after.slots[1]!.tier, PotTier.silver);
      expect(after.slots[1]!.timer, isNull, reason: 'the queued pot waits to be started');
      expect(after.waiting, [PotTier.gold]);
    });

    test('only a ready pot can be opened', () {
      final shelf = const PotShelf().add(PotTier.clay).$1;
      expect(shelf.take(0, at(t0)), isNull, reason: 'not started');
      final started = shelf.start(0, at(t0))!;
      expect(started.take(0, at(t0.add(hour * 2))), isNull, reason: 'running');
      expect(started.take(0, at(t0.add(hour * 3)))!.$2, PotTier.clay);
      expect(shelf.take(2, at(t0)), isNull, reason: 'an empty slot');
    });
  });

  group('timers', () {
    PotShelf three() {
      var s = const PotShelf();
      for (final t in [PotTier.clay, PotTier.silver, PotTier.gold]) {
        s = s.add(t).$1;
      }
      return s;
    }

    test('a new pot waits to be started; one timer runs at a time', () {
      final shelf = three();
      expect(shelf.phaseOf(0, at(t0)), PotPhase.idle);
      expect(shelf.canStart(0, at(t0)), isTrue);
      final running = shelf.start(0, at(t0))!;
      expect(running.phaseOf(0, at(t0.add(hour))), PotPhase.running);
      expect(running.runningIndex(at(t0.add(hour))), 0);
      expect(running.canStart(1, at(t0.add(hour))), isFalse);
      expect(running.start(1, at(t0.add(hour))), isNull);
      expect(running.start(0, at(t0.add(hour))), isNull, reason: 'already running');
    });

    test('when the clay pot is ready the next one can start, even before the first is opened', () {
      final running = three().start(0, at(t0))!;
      final later = at(t0.add(hour * 3));
      expect(running.phaseOf(0, later), PotPhase.ready);
      expect(running.canStart(1, later), isTrue);
      final second = running.start(1, later)!;
      expect(second.phaseOf(0, later), PotPhase.ready);
      expect(second.phaseOf(1, later), PotPhase.running);
    });

    test('the clock moved forward does not open a pot early', () {
      final running = three().start(2, at(t0, up: 100))!;
      final cheat = at(t0.add(hour * 30), up: 100 + 600);
      expect(running.phaseOf(2, cheat), PotPhase.running);
      expect(running.view(2, cheat)!.remaining, hour * 12 - const Duration(minutes: 10));
    });

    test('advance saves the time the running pot has seen pass', () {
      final running = three().start(1, at(t0, up: 0))!;
      final saved = running.advance(at(t0.add(hour * 2), up: 7200));
      expect(saved.slots[1]!.timer!.credited, hour * 2);
      expect(const PotShelf().advance(at(t0)).filled, 0);
    });

    test('1 gem skips 20 minutes: the cost is the time left in 20-minute steps, rounded up', () {
      final shelf = three();
      expect(shelf.skipCost(0, at(t0)), 9, reason: '3 h idle clay');
      expect(shelf.skipCost(1, at(t0)), 24, reason: '8 h silver');
      expect(shelf.skipCost(2, at(t0)), 36, reason: '12 h gold');
      final running = shelf.start(0, at(t0, up: 0))!;
      expect(running.skipCost(0, at(t0.add(hour), up: 3600)), 6);
      expect(running.skipCost(0, at(t0.add(const Duration(hours: 2, minutes: 59, seconds: 30)), up: 10770)), 1);
      expect(running.skipCost(0, at(t0.add(hour * 3), up: 10800)), 0, reason: 'a ready pot opens for free');
      expect(const PotShelf().skipCost(0, at(t0)), 0, reason: 'an empty slot');
    });

    test('skipping makes the pot ready now (the caller takes the gems); a ready or empty slot cannot be skipped', () {
      final shelf = three();
      final skipped = shelf.skip(1, at(t0))!;
      expect(skipped.phaseOf(1, at(t0)), PotPhase.ready);
      expect(skipped.skip(1, at(t0)), isNull);
      expect(const PotShelf().skip(0, at(t0)), isNull);
      expect(skipped.take(1, at(t0))!.$2, PotTier.silver);
    });

    test('the view shows tier, phase, time left, progress and the gem cost', () {
      final running = three().start(0, at(t0, up: 0))!;
      final v = running.view(0, at(t0.add(hour), up: 3600))!;
      expect(v.tier, PotTier.clay);
      expect(v.phase, PotPhase.running);
      expect(v.remaining, hour * 2);
      expect(v.progress, closeTo(1 / 3, 1e-9));
      expect(v.skipGems, 6);
      expect(three().view(0, at(t0))!.progress, 0);
      expect(const PotShelf().view(0, at(t0)), isNull);
    });
  });

  test('JSON round trips the shelf, the timers and the queue; garbage loads as an empty shelf', () {
    var shelf = three4();
    shelf = shelf.start(0, at(t0, up: 5))!;
    final back = PotShelf.fromJson(shelf.toJson());
    expect([for (final s in back.slots) s?.tier], [for (final s in shelf.slots) s?.tier]);
    expect(back.slots[0]!.timer, shelf.slots[0]!.timer);
    expect(back.waiting, shelf.waiting);
    final junk = PotShelf.fromJson({
      'slots': [5, {'t': 'bronze'}, null, {'t': 'gold'}],
      'waiting': ['clay', 'nope', 3],
    });
    expect(junk.slots, hasLength(3));
    expect(junk.slots.every((s) => s == null), isTrue);
    expect(junk.waiting, [PotTier.clay]);
    expect(PotShelf.fromJson(const {}).filled, 0);
  });
}

/// Three pots on the shelf and one waiting in the queue.
PotShelf three4() {
  var s = const PotShelf();
  for (final t in [PotTier.clay, PotTier.silver, PotTier.gold]) {
    s = s.add(t).$1;
  }
  return s.add(PotTier.clay, queue: true).$1;
}
