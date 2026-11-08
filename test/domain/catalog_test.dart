// The catalog is the Collection board in data: every dice, piece and board with its
// rarity, price, level gate and stats (board C · "Rarity, prices & gates"). These tests
// pin the rules the boards state and the links between files (art skins, Mela Road).

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/art/board_skins.dart';
import 'package:ludo_mela/core/art/dice_skin.dart';
import 'package:ludo_mela/core/art/piece_skin.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/road.dart';

void main() {
  group('the items', () {
    test('ids are unique and every kind has its list', () {
      final ids = [for (final i in Catalog.all) i.id];
      expect(ids.toSet(), hasLength(ids.length));
      expect(Catalog.dice, hasLength(7));
      expect(Catalog.pieces, hasLength(8));
      expect(Catalog.boards, hasLength(6));
      for (final kind in ItemKind.values) {
        expect(Catalog.ofKind(kind).every((i) => i.kind == kind), isTrue);
      }
      expect(Catalog.byId('ruby_jelly')!.name, 'Ruby Jelly');
      expect(Catalog.byId('nope'), isNull);
      expect(Catalog.byId(null), isNull);
    });

    test('an item id is the id of an art skin the match screen can draw', () {
      final diceSkins = {for (final s in DiceSkins.all) s.id};
      final pieceSkins = {for (final s in PieceSkins.all) s.id};
      for (final i in Catalog.dice) {
        expect(diceSkins, contains(i.skin), reason: i.id);
      }
      for (final i in Catalog.pieces) {
        expect(pieceSkins, contains(i.skin), reason: i.id);
      }
      for (final i in Catalog.boards) {
        expect(BoardSkins.byId(i.skin).id, i.skin, reason: i.id);
      }
    });

    test('the starters are the three free items, one per kind', () {
      expect(Catalog.starterIds, {'mela_classic', 'lotus', 'mela_wood'});
      for (final kind in ItemKind.values) {
        final s = Catalog.starter(kind);
        expect(s.isFree, isTrue);
        expect(s.rarity, Rarity.standard);
        expect(Catalog.starterIds, contains(s.id));
      }
      expect(Catalog.all.where((i) => i.isFree), hasLength(3));
    });
  });

  group('rarity bands (board C)', () {
    test('Standard is free or 800–1,500 coins from level 1', () {
      for (final i in Catalog.all.where((i) => i.rarity == Rarity.standard)) {
        expect(i.unlockLevel, 1, reason: i.id);
        if (!i.isFree) {
          expect(i.price.kind, PriceKind.coins, reason: i.id);
          expect(i.price.amount, inInclusiveRange(800, 1500), reason: i.id);
        }
      }
    });

    test('Rare costs 3,000–8,000 coins or shards, from level 3', () {
      final rares = Catalog.all.where((i) => i.rarity == Rarity.rare).toList();
      expect(rares, isNotEmpty);
      for (final i in rares) {
        expect(i.unlockLevel, 3, reason: i.id);
        if (i.price.kind == PriceKind.coins) expect(i.price.amount, inInclusiveRange(3000, 8000), reason: i.id);
        expect({PriceKind.coins, PriceKind.shards}, contains(i.price.kind), reason: i.id);
      }
    });

    test('Epic costs 120–180 gems (or shards / the Road), from level 10', () {
      for (final i in Catalog.all.where((i) => i.rarity == Rarity.epic)) {
        if (i.price.kind == PriceKind.gems) {
          expect(i.price.amount, inInclusiveRange(120, 180), reason: i.id);
          expect(i.unlockLevel, 10, reason: i.id);
        } else if (i.price.kind == PriceKind.shards) {
          expect(i.unlockLevel, 10, reason: i.id);
        } else {
          expect(i.price.kind, PriceKind.road, reason: i.id);
        }
      }
    });

    test('Legendary is shards or the Mela Road only, from level 20', () {
      for (final i in Catalog.all.where((i) => i.rarity == Rarity.legendary)) {
        expect({PriceKind.shards, PriceKind.road}, contains(i.price.kind), reason: i.id);
        if (i.price.kind == PriceKind.shards) expect(i.unlockLevel, 20, reason: i.id);
      }
    });

    test('Mela items are earn-only (events, the Mela Cup) and never for sale', () {
      final mela = Catalog.all.where((i) => i.rarity == Rarity.mela).toList();
      expect(mela.map((i) => i.id), containsAll(['mela_lantern', 'elephant', 'champion']));
      for (final i in mela) {
        expect(i.price.kind, PriceKind.event, reason: i.id);
        expect(i.isEarnOnly, isTrue);
        expect(i.shardsNeeded, 0);
      }
      expect(Catalog.byId('champion')!.price.event, 'mela_cup');
    });

    test('shard items need the amounts the Collection board shows', () {
      expect(Catalog.byId('peacock_royal')!.shardsNeeded, 60);
      expect(Catalog.byId('crown')!.shardsNeeded, 40);
      expect(Catalog.byId('ruby_jelly')!.shardsNeeded, 0);
    });
  });

  group('stats and upgrades', () {
    test('three bars: two cosmetic 0–5 and an XP boost of 0–3 steps (none for the starters, full for Legendary)', () {
      for (final i in Catalog.all) {
        expect(i.stats.a, inInclusiveRange(0, 5), reason: i.id);
        expect(i.stats.b, inInclusiveRange(0, 5), reason: i.id);
        expect(i.stats.xpBoost, inInclusiveRange(0, 3), reason: i.id);
      }
      expect(Catalog.starter(ItemKind.dice).stats.xpBoost, 0);
      expect(Catalog.byId('peacock_royal')!.stats.xpBoost, 3);
      for (final kind in ItemKind.values) {
        expect(kind.statLabels, hasLength(3));
        expect(kind.statLabels.last, 'XP boost');
      }
    });

    test('an upgrade costs base × (level + 1) / 2 — Ruby Jelly level 2 → 3 is the 1,500 on the board', () {
      final ruby = Catalog.byId('ruby_jelly')!;
      expect(ruby.upgradeCost(1), 1000);
      expect(ruby.upgradeCost(2), 1500);
      expect(ruby.upgradeCost(4), 2500);
      expect(Catalog.byId('mela_classic')!.upgradeCost(1), 800);
    });

    test('items bought with the Mela Road are the ones the Road hands over at that level', () {
      for (final i in Catalog.all.where((i) => i.price.kind == PriceKind.road)) {
        expect(MelaRoad.rewardFor(i.price.amount).itemId, i.id, reason: '${i.id} at level ${i.price.amount}');
        expect(i.unlockLevel, i.price.amount);
      }
    });
  });
}
