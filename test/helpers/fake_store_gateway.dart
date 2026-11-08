// A scriptable app store, so the Remove-ads flow can be tested without Google
// Play or StoreKit. Purchase updates are pushed by the test with [emit], the way
// the real store delivers them on the purchase stream.
//
//   final store = FakeStoreGateway();
//   … ProviderContainer(overrides: [storeGatewayProvider.overrideWithValue(store)]);
//   store.onBuy = () => store.emit(PurchaseStatus.purchased);

import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:ludo_mela/core/purchases/remove_ads_service.dart';
import 'package:ludo_mela/core/purchases/store_gateway.dart';

class FakeStoreGateway extends StoreGateway {
  FakeStoreGateway({this.available = true, this.price = r'$0.99'});

  /// Whether a store is reachable.
  bool available;

  /// The price text the product shows.
  String? price;

  /// Whether [buy] manages to open the store sheet.
  bool buyStarts = true;

  /// Runs when [buy] is called (a test pushes the outcome from here).
  void Function()? onBuy;

  /// Runs when [restore] is called.
  void Function()? onRestore;

  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  int buys = 0;
  int restores = 0;
  final List<PurchaseDetails> completed = [];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetails?> product(String id) async => id == kRemoveAdsProductId && price != null
      ? ProductDetails(id: id, title: 'Remove ads', description: 'No banner, no break ads', price: price!, rawPrice: .99, currencyCode: 'USD')
      : null;

  @override
  Stream<List<PurchaseDetails>> get purchases => _controller.stream;

  @override
  Future<bool> buy(ProductDetails product) async {
    buys++;
    onBuy?.call();
    return buyStarts;
  }

  @override
  Future<void> restore() async {
    restores++;
    onRestore?.call();
  }

  @override
  Future<void> complete(PurchaseDetails purchase) async => completed.add(purchase);

  /// Delivers a purchase update for [productId] (default: Remove ads).
  void emit(PurchaseStatus status, {String productId = kRemoveAdsProductId, bool pendingComplete = true}) {
    final p = PurchaseDetails(
      purchaseID: 'test-order',
      productID: productId,
      verificationData: PurchaseVerificationData(localVerificationData: 'local', serverVerificationData: 'server', source: 'test'),
      transactionDate: '0',
      status: status,
    )..pendingCompletePurchase = pendingComplete;
    _controller.add([p]);
  }

  Future<void> dispose() => _controller.close();
}
