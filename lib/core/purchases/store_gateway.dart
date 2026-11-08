// The app store as the purchase logic needs it.
//
// Why an interface: RemoveAdsController must be testable without Google Play or
// the App Store. [InAppPurchaseGateway] is a thin pass-through to the
// `in_app_purchase` plugin (it uses the plugin's own ProductDetails /
// PurchaseDetails, which tests can build directly); [NoStoreGateway] stands in
// where there is no store (desktop, widget tests).

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

abstract class StoreGateway {
  const StoreGateway();

  /// Whether a store can be reached on this phone.
  Future<bool> isAvailable();

  /// The product [id], or null when the store does not know it.
  Future<ProductDetails?> product(String id);

  /// Purchase updates (new, pending, restored, cancelled, failed). Listen early:
  /// the store may deliver an unfinished purchase right at launch.
  Stream<List<PurchaseDetails>> get purchases;

  /// Starts the one-time purchase flow of [product]; false when it could not
  /// start. The outcome arrives on [purchases].
  Future<bool> buy(ProductDetails product);

  /// Asks the store to replay past purchases onto [purchases].
  Future<void> restore();

  /// Tells the store a delivered purchase has been handled (Google Play
  /// refunds an unacknowledged purchase after three days).
  Future<void> complete(PurchaseDetails purchase);
}

/// The real store (Google Play Billing / StoreKit).
class InAppPurchaseGateway extends StoreGateway {
  InAppPurchaseGateway();

  /// Off in tests and on platforms without a store.
  static bool get supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && !Platform.environment.containsKey('FLUTTER_TEST');

  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ProductDetails?> product(String id) async {
    try {
      final response = await _iap.queryProductDetails({id});
      for (final p in response.productDetails) {
        if (p.id == id) return p;
      }
    } catch (_) {}
    return null;
  }

  @override
  Stream<List<PurchaseDetails>> get purchases => _iap.purchaseStream;

  @override
  Future<bool> buy(ProductDetails product) async {
    try {
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();

  @override
  Future<void> complete(PurchaseDetails purchase) => _iap.completePurchase(purchase);
}

/// No store: nothing can be bought or restored.
class NoStoreGateway extends StoreGateway {
  const NoStoreGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<ProductDetails?> product(String id) async => null;

  @override
  Stream<List<PurchaseDetails>> get purchases => const Stream.empty();

  @override
  Future<bool> buy(ProductDetails product) async => false;

  @override
  Future<void> restore() async {}

  @override
  Future<void> complete(PurchaseDetails purchase) async {}
}
