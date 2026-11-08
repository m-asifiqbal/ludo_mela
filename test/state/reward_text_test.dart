// The sentences screens show for what a reward or a purchase did — in English, and in
// Bangla / Hindi from the bundled packs — and the boot-clock helper behind the timers.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_mela/core/l10n/app_language.dart';
import 'package:ludo_mela/core/l10n/l10n.dart';
import 'package:ludo_mela/domain/catalog.dart';
import 'package:ludo_mela/domain/collection.dart';
import 'package:ludo_mela/domain/grant.dart';
import 'package:ludo_mela/domain/grant_apply.dart';
import 'package:ludo_mela/domain/pot_tier.dart';
import 'package:ludo_mela/state/core_providers.dart';
import 'package:ludo_mela/state/reward_text.dart';

import '../domain/fixtures.dart';

void main() {
  tearDown(L10n.reset);

  Map<String, String> pack(String code) => {
    for (final name in ['core', 'domain', 'state'])
      ...(jsonDecode(File('assets/l10n/$code/$name.json').readAsStringSync()) as Map).cast<String, String>(),
  };

  group('receiptLines', () {
    test('a plain payout lists coins, gems and spins, with singular and plural', () {
      final (_, r) = applyGrant(freshProfile(), const Grant(coins: 250, gems: 1, spins: 2));
      expect(receiptLines(r), ['+250 coins', '+1 gem', '+2 free spins']);
      expect(receiptLines(applyGrant(freshProfile(), const Grant(coins: 1)).$2), ['+1 coin']);
      expect(receiptLines(const GrantReceipt()), isEmpty);
    });

    test('new items, shard unlocks and pots are named', () {
      var (p, r) = applyGrant(freshProfile(), const Grant(items: ['moon'], pots: [PotTier.clay]));
      expect(receiptLines(r), ['New: Moon Gems', 'Clay pot added to your shelf.']);
      (p, r) = applyGrant(p, const Grant(shards: {'marble_palace': 30}));
      expect(receiptLines(r), ['Marble Palace unlocked!']);
      final full = applyGrant(freshProfile(), const Grant(pots: [PotTier.clay, PotTier.clay, PotTier.clay, PotTier.gold])).$2;
      expect(receiptLines(full).last, 'Gold pot is waiting for a free spot on your shelf.');
    });

    test('a duplicate says what it turned into and does not count twice as coins', () {
      final owned = applyGrant(freshProfile(), const Grant(items: ['moon'])).$1;
      final (_, r) = applyGrant(owned, const Grant(coins: 100, items: ['moon']));
      expect(receiptLines(r), ['+100 coins', 'You already had it, so you got 2000 coins instead.']);
    });

    test('in Bangla and Hindi', () {
      final owned = applyGrant(freshProfile(), const Grant(items: ['moon'])).$1;
      final (_, r) = applyGrant(owned, const Grant(coins: 100, gems: 2, items: ['moon']));
      L10n.activate(AppLanguage.bn, pack('bn'));
      expect(receiptLines(r), ['+100 কয়েন', '+2 জেম', 'এটা আগেই তোমার ছিল, তাই বদলে 2000 কয়েন পেলে।']);
      L10n.activate(AppLanguage.hi, pack('hi'));
      expect(receiptLines(r), ['+100 सिक्के', '+2 जेम', 'यह पहले से तुम्हारे पास था, इसलिए बदले में 2000 सिक्के मिले।']);
    });
  });

  group('purchaseBlockText', () {
    test('every refusal has a sentence; success has none', () {
      for (final b in PurchaseBlock.values) {
        expect(purchaseBlockText(b).isEmpty, b == PurchaseBlock.none, reason: '$b');
      }
    });

    test('the level and the currency come from the item', () {
      expect(purchaseBlockText(PurchaseBlock.levelTooLow, item: Catalog.byId('gold_mohur')), 'Reach level 10 to unlock this.');
      expect(purchaseBlockText(PurchaseBlock.cannotAfford, item: Catalog.byId('gold_mohur')), 'Not enough gems.');
      expect(purchaseBlockText(PurchaseBlock.cannotAfford, item: Catalog.byId('ruby_jelly')), 'Not enough coins.');
      expect(purchaseBlockText(PurchaseBlock.cannotAfford, item: Catalog.byId('gold_mohur'), upgrade: true), 'Not enough coins.', reason: 'upgrades cost coins');
      expect(purchaseBlockText(PurchaseBlock.maxLevel), 'Already at the top level.');
    });

    test('translated', () {
      L10n.activate(AppLanguage.hi, pack('hi'));
      expect(purchaseBlockText(PurchaseBlock.levelTooLow, item: Catalog.byId('ruby_jelly')), 'इसे अनलॉक करने के लिए लेवल 3 तक पहुँचो।');
      expect(purchaseBlockText(PurchaseBlock.cannotAfford), 'सिक्के काफ़ी नहीं हैं।');
    });
  });

  group('the boot clock', () {
    test('parseProcUptime reads the first number of /proc/uptime', () {
      expect(parseProcUptime('12345.67 98765.43\n'), const Duration(milliseconds: 12345670));
      expect(parseProcUptime('  5.5   1\n'), const Duration(milliseconds: 5500));
      expect(parseProcUptime('0.00 0.00'), Duration.zero);
    });

    test('anything else is "no reading"', () {
      for (final bad in ['', 'x', '-5 3', 'NaN 1', '9999999999 1']) {
        expect(parseProcUptime(bad), isNull, reason: bad);
      }
    });

    test('under flutter_test the real boot time is never used, so a faked clock stays in charge', () {
      expect(bootUptime(), isNull);
    });
  });
}
