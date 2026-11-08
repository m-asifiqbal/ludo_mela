// "Remove ads" is the one real-money item, so its flow is tested end to end with a
// scripted store: buy, cancel, error, restore (with and without a past purchase),
// an unfinished purchase delivered at launch, and the entitlement it saves.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ludo_mela/core/purchases/remove_ads_service.dart';
import 'package:ludo_mela/core/purchases/store_gateway.dart';
import 'package:ludo_mela/core/storage/save_store.dart';
import 'package:ludo_mela/domain/save_data.dart';
import 'package:ludo_mela/state/save_controller.dart';

import '../../helpers/fake_store_gateway.dart';

void main() {
  late FakeStoreGateway store;
  late ProviderContainer container;
  late MemorySaveStore saved;

  ProviderContainer make({DeviceState device = const DeviceState()}) {
    final save = SaveData.fresh(now: DateTime(2026, 11, 7), profileId: 'p1').copyWith(device: device);
    saved = MemorySaveStore(save);
    final c = ProviderContainer(
      overrides: [
        saveStoreProvider.overrideWithValue(saved),
        initialSaveProvider.overrideWithValue(save),
        storeGatewayProvider.overrideWithValue(store),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  RemoveAdsController controller() => container.read(removeAdsProvider.notifier);
  RemoveAdsState state() => container.read(removeAdsProvider);

  setUp(() {
    store = FakeStoreGateway();
    container = make();
    addTearDown(store.dispose);
  });

  test('the product id is remove_ads', () {
    expect(kRemoveAdsProductId, 'remove_ads');
  });

  group('start', () {
    test('loads the price so Settings can show it', () async {
      expect(state().canBuy, isFalse);
      await controller().start();
      expect(state().price, r'$0.99');
      expect(state().canBuy, isTrue);
      expect(state().busy, isFalse);
    });

    test('is idempotent', () async {
      await controller().start();
      await controller().start();
      expect(state().price, r'$0.99');
    });

    test('without a store there is no price and nothing can be bought', () async {
      store.available = false;
      await controller().start();
      expect(state().canBuy, isFalse);
      expect(await controller().buy(), PurchaseResult.unavailable);
      expect(await controller().restore(), PurchaseResult.unavailable);
      expect(container.read(adsRemovedProvider), isFalse);
    });

    test('a store that does not know the product: unavailable', () async {
      store.price = null;
      expect(await controller().buy(), PurchaseResult.unavailable);
    });
  });

  group('buy', () {
    test('a completed purchase removes ads, is acknowledged to the store and saved', () async {
      store.onBuy = () => store.emit(PurchaseStatus.purchased);
      final result = await controller().buy();
      expect(result, PurchaseResult.purchased);
      expect(container.read(adsRemovedProvider), isTrue);
      expect(store.completed, hasLength(1), reason: 'Google refunds an unacknowledged purchase after 3 days');
      expect(state().busy, isFalse);
      expect(saved.data!.device.adsRemoved, isTrue, reason: 'persisted, so it survives a restart');
      expect(store.buys, 1);
    });

    test('closing the store sheet changes nothing', () async {
      store.onBuy = () => store.emit(PurchaseStatus.canceled);
      expect(await controller().buy(), PurchaseResult.canceled);
      expect(container.read(adsRemovedProvider), isFalse);
      expect(state().busy, isFalse);
    });

    test('a store error is reported and changes nothing', () async {
      store.onBuy = () => store.emit(PurchaseStatus.error);
      expect(await controller().buy(), PurchaseResult.failed);
      expect(container.read(adsRemovedProvider), isFalse);
      expect(state().busy, isFalse);
    });

    test('a store that cannot open its sheet fails cleanly', () async {
      store.buyStarts = false;
      expect(await controller().buy(), PurchaseResult.failed);
      expect(state().busy, isFalse);
    });

    test('a pending purchase keeps waiting until the store settles it', () async {
      store.onBuy = () => store.emit(PurchaseStatus.pending, pendingComplete: false);
      final future = controller().buy();
      await pumpEventQueue();
      expect(state().busy, isTrue);
      expect(container.read(adsRemovedProvider), isFalse);
      store.emit(PurchaseStatus.purchased);
      expect(await future, PurchaseResult.purchased);
      expect(container.read(adsRemovedProvider), isTrue);
    });

    test('a second buy while one is running is refused', () async {
      store.onBuy = () => store.emit(PurchaseStatus.pending, pendingComplete: false);
      final first = controller().buy();
      await pumpEventQueue();
      expect(await controller().buy(), PurchaseResult.failed);
      expect(store.buys, 1);
      store.emit(PurchaseStatus.canceled);
      await first;
    });

    test('already owned: the store is not even asked', () async {
      container = make(device: const DeviceState(adsRemoved: true));
      expect(await controller().buy(), PurchaseResult.alreadyOwned);
      expect(await controller().restore(), PurchaseResult.alreadyOwned);
      expect(store.buys + store.restores, 0);
    });
  });

  group('restore', () {
    test('a past purchase is found and ads go off', () async {
      store.onRestore = () => store.emit(PurchaseStatus.restored);
      expect(await controller().restore(), PurchaseResult.restored);
      expect(container.read(adsRemovedProvider), isTrue);
      expect(store.restores, 1);
      expect(store.completed, hasLength(1));
      expect(state().busy, isFalse);
    });

    testWidgets('nothing to restore: the store stays silent, so it ends after a wait', (tester) async {
      container = make();
      final future = controller().restore();
      await tester.pump(RemoveAdsController.restoreWait + const Duration(seconds: 1));
      expect(await future, PurchaseResult.nothingToRestore);
      expect(container.read(adsRemovedProvider), isFalse);
      expect(state().busy, isFalse);
    });

    test('a restore that errors reports failure', () async {
      store.onRestore = () => store.emit(PurchaseStatus.error);
      expect(await controller().restore(), PurchaseResult.failed);
      expect(container.read(adsRemovedProvider), isFalse);
    });
  });

  group('purchases the store delivers on its own', () {
    test('an unfinished purchase arriving at launch removes ads', () async {
      await controller().start();
      store.emit(PurchaseStatus.purchased);
      await pumpEventQueue();
      expect(container.read(adsRemovedProvider), isTrue);
      expect(store.completed, hasLength(1));
    });

    test('a restored purchase arriving at launch removes ads too', () async {
      await controller().start();
      store.emit(PurchaseStatus.restored);
      await pumpEventQueue();
      expect(container.read(adsRemovedProvider), isTrue);
    });

    test('another product is acknowledged but never unlocks anything', () async {
      await controller().start();
      store.emit(PurchaseStatus.purchased, productId: 'something_else');
      await pumpEventQueue();
      expect(container.read(adsRemovedProvider), isFalse);
      expect(store.completed, hasLength(1));
    });

    test('a purchase that needs no acknowledgement is not acknowledged twice', () async {
      await controller().start();
      store.emit(PurchaseStatus.purchased, pendingComplete: false);
      await pumpEventQueue();
      expect(container.read(adsRemovedProvider), isTrue);
      expect(store.completed, isEmpty);
    });
  });

  group('NoStoreGateway (desktop, tests)', () {
    test('offers nothing', () async {
      const gateway = NoStoreGateway();
      expect(await gateway.isAvailable(), isFalse);
      expect(await gateway.product(kRemoveAdsProductId), isNull);
      expect(await gateway.purchases.isEmpty, isTrue);
      await gateway.restore();
      expect(InAppPurchaseGateway.supported, isFalse, reason: 'tests never touch the store plugin');
    });
  });
}
