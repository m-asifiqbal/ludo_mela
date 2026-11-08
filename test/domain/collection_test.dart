// One profile's Collection: buying, using, upgrading, shards, the XP boost — every
// change is a pure function from (Collection, Wallet) to the next pair (board C and
// the Collection / TryOn boards).

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/wallet.dart';

void main() {
  const rich = Wallet(coins: 100000, gems: 1000);

  group('starting point', () {
    test('the three starters are owned and in use; nothing is new', () {
      const c = Collection();
      expect(c.owned, Catalog.starterIds);
      for (final kind in ItemKind.values) {
        expect(c.selectedId(kind), Catalog.starter(kind).id);
        expect(c.newCount(kind), 0);
      }
      expect(c.xpBoostPercent, 0);
      expect(c.levelOf('ruby_jelly'), 1);
      expect(c.shardsOf('ocean_glass'), 0);
    });

    test('a selection that is not owned (or of another kind) falls back to the starter', () {
      const c = Collection(selected: {ItemKind.dice: 'gold_mohur', ItemKind.piece: 'mela_classic'});
      expect(c.selectedId(ItemKind.dice), 'mela_classic');
      expect(c.selectedId(ItemKind.piece), 'lotus');
    });
  });

  group('buying', () {
    test('coins buy Standard and Rare items at their level; the wallet and collection both change', () {
      final r = const Collection().buy('star', level: 1, wallet: const Wallet(coins: 1000, gems: 0));
      expect(r.ok, isTrue);
      expect(r.wallet, const Wallet(coins: 200, gems: 0));
      expect(r.collection!.owns('star'), isTrue);
      expect(r.collection!.unseen, {'star'}, reason: 'a new item shows the NEW badge');
      expect(r.collection!.newCount(ItemKind.piece), 1);
    });

    test('gems buy Epic items', () {
      final r = const Collection().buy('gold_mohur', level: 10, wallet: const Wallet(coins: 0, gems: 150));
      expect(r.ok, isTrue);
      expect(r.wallet, const Wallet(coins: 0, gems: 10));
    });

    test('the level gate, the price and ownership are checked, in that order of kindness', () {
      expect(const Collection().buy('ruby_jelly', level: 2, wallet: rich).block, PurchaseBlock.levelTooLow);
      expect(const Collection().buy('ruby_jelly', level: 3, wallet: const Wallet(coins: 2999, gems: 99)).block, PurchaseBlock.cannotAfford);
      expect(const Collection().buy('gold_mohur', level: 10, wallet: const Wallet(coins: 99999, gems: 139)).block, PurchaseBlock.cannotAfford);
      expect(const Collection().buy('lotus', level: 1, wallet: rich).block, PurchaseBlock.owned);
      expect(const Collection().buy('nope', level: 1, wallet: rich).block, PurchaseBlock.unknownItem);
    });

    test('shard, Road and event items are never bought', () {
      for (final id in ['ocean_glass', 'midnight_gold', 'mela_lantern', 'champion', 'peacock_royal']) {
        expect(const Collection().buy(id, level: 50, wallet: rich).block, PurchaseBlock.notForSale, reason: id);
      }
    });
  });

  group('using', () {
    test('only an owned item can be selected, and it replaces the one of its kind', () {
      var c = const Collection().withItem('ruby_jelly');
      expect(c.select('gold_mohur'), same(c), reason: 'not owned: nothing changes');
      c = c.select('ruby_jelly');
      expect(c.selectedId(ItemKind.dice), 'ruby_jelly');
      expect(c.selectedId(ItemKind.piece), 'lotus');
      expect(c.selectedItem(ItemKind.dice).name, 'Ruby Jelly');
      expect(c.select('nope'), same(c));
    });

    test('opening a tab clears its NEW badges only', () {
      final c = const Collection().withItem('ruby_jelly').withItem('moon');
      expect(c.newCount(ItemKind.dice), 1);
      final seen = c.markSeen(ItemKind.dice);
      expect(seen.newCount(ItemKind.dice), 0);
      expect(seen.newCount(ItemKind.piece), 1);
    });

    test('withItem ignores owned and unknown ids', () {
      const c = Collection();
      expect(c.withItem('lotus'), same(c));
      expect(c.withItem('nope'), same(c));
    });
  });

  group('upgrades (coins; cosmetics and XP boost only)', () {
    test('level 1 → 2 costs the base price, each level costs more, level 5 is the top', () {
      var c = const Collection().withItem('ruby_jelly');
      var w = rich;
      final costs = <int>[];
      for (var level = 1; level < 5; level++) {
        expect(c.upgradeCostOf('ruby_jelly'), isNotNull);
        final r = c.upgrade('ruby_jelly', w);
        expect(r.ok, isTrue);
        costs.add(w.coins - r.wallet!.coins);
        c = r.collection!;
        w = r.wallet!;
      }
      expect(costs, [1000, 1500, 2000, 2500]);
      expect(c.levelOf('ruby_jelly'), 5);
      expect(c.upgradeCostOf('ruby_jelly'), isNull);
      expect(c.upgrade('ruby_jelly', w).block, PurchaseBlock.maxLevel);
    });

    test('refused when not owned, unknown or too expensive — and nothing is charged', () {
      expect(const Collection().upgrade('ruby_jelly', rich).block, PurchaseBlock.notOwned);
      expect(const Collection().upgrade('nope', rich).block, PurchaseBlock.unknownItem);
      expect(const Collection().upgrade('lotus', const Wallet(coins: 799, gems: 0)).block, PurchaseBlock.cannotAfford);
    });

    test('the XP boost is +5 % per step: the items in use, upgrades add one step per two levels, 45 % at most', () {
      var c = const Collection();
      expect(c.xpBoostPercent, 0);
      // Ruby Jelly has 1 step; upgraded to level 3 it has 2.
      c = c.withItem('ruby_jelly').select('ruby_jelly');
      expect(c.xpBoostPercent, 5);
      c = c.copyLevels({'ruby_jelly': 3});
      expect(c.xpBoostPercent, 10);
      // Everything legendary and fully upgraded hits the ceiling of 3 steps per item.
      c = const Collection(
        owned: {'peacock_royal', 'peacock', 'royal_durbar', 'mela_classic', 'lotus', 'mela_wood'},
        selected: {ItemKind.dice: 'peacock_royal', ItemKind.piece: 'peacock', ItemKind.board: 'royal_durbar'},
        levels: {'peacock_royal': 5, 'peacock': 5, 'royal_durbar': 5},
      );
      expect(c.xpBoostPercent, 45);
    });
  });

  group('shards', () {
    test('shards add up and the last one unlocks the item; the shard count is then dropped', () {
      var (c, unlocked) = const Collection().addShards('ocean_glass', 30);
      expect(unlocked, isFalse);
      expect(c.shardsOf('ocean_glass'), 30);
      expect(c.stateOf(Catalog.byId('ocean_glass')!, 5), ItemState.shards);
      (c, unlocked) = c.addShards('ocean_glass', 3);
      expect(unlocked, isTrue);
      expect(c.owns('ocean_glass'), isTrue);
      expect(c.shardsOf('ocean_glass'), 0);
      expect(c.unseen, contains('ocean_glass'));
    });

    test('shards of an owned, unknown or non-shard item change nothing', () {
      const c = Collection();
      expect(c.addShards('lotus', 5).$1, same(c));
      expect(c.addShards('nope', 5).$1, same(c));
      expect(c.addShards('ocean_glass', 0).$1, same(c));
      final (r, done) = c.addShards('ruby_jelly', 10);
      expect(done, isFalse, reason: 'a coin item has no shard target');
      expect(r.shardsOf('ruby_jelly'), 10);
    });
  });

  group('what a card shows', () {
    test('every state of the Collection board', () {
      final c = const Collection().withItem('ruby_jelly').select('ruby_jelly');
      ItemState of(String id, int level) => c.stateOf(Catalog.byId(id)!, level);
      expect(of('ruby_jelly', 3), ItemState.using);
      expect(of('mela_classic', 3), ItemState.owned);
      expect(of('moon', 3), ItemState.buyCoins);
      expect(of('moon', 2), ItemState.locked);
      expect(of('gold_mohur', 10), ItemState.buyGems);
      expect(of('gold_mohur', 9), ItemState.locked);
      expect(of('peacock_royal', 1), ItemState.shards);
      expect(of('midnight_gold', 1), ItemState.road);
      expect(of('mela_lantern', 1), ItemState.event);
    });
  });

  group('JSON', () {
    test('round trips', () {
      final c = const Collection()
          .withItem('ruby_jelly')
          .select('ruby_jelly')
          .addShards('ocean_glass', 7)
          .$1
          .copyLevels({'ruby_jelly': 4});
      final back = Collection.fromJson(c.toJson());
      expect(back.owned, c.owned);
      expect(back.selected, c.selected);
      expect(back.levels, c.levels);
      expect(back.shards, c.shards);
      expect(back.unseen, c.unseen);
    });

    test('garbage loads as a valid collection: starters owned, bad selections and numbers dropped', () {
      final c = Collection.fromJson({
        'owned': ['ruby_jelly', 5, null, ''],
        'selected': {'dice': 'gold_mohur', 'piece': 'ruby_jelly', 'board': 'night_bazaar', 'weird': 'x'},
        'levels': {'ruby_jelly': 99, 'moon': 0, 'star': 'x'},
        'shards': {'ocean_glass': 12, 'crown': -3},
        'unseen': ['ruby_jelly', 'gold_mohur'],
      });
      expect(c.owned, {...Catalog.starterIds, 'ruby_jelly'});
      expect(c.selectedId(ItemKind.dice), 'mela_classic', reason: 'not owned');
      expect(c.selectedId(ItemKind.piece), 'lotus', reason: 'wrong kind');
      expect(c.levelOf('ruby_jelly'), 5, reason: 'clamped to the top');
      expect(c.levels.containsKey('moon'), isFalse);
      expect(c.shards, {'ocean_glass': 12});
      expect(c.unseen, {'ruby_jelly'});
      expect(Collection.fromJson(const {}).owned, Catalog.starterIds);
    });
  });
}

extension on Collection {
  /// This collection with [levels] set (tests set levels directly).
  Collection copyLevels(Map<String, int> levels) =>
      Collection(owned: owned, selected: selected, levels: {...this.levels, ...levels}, shards: shards, unseen: unseen);
}
