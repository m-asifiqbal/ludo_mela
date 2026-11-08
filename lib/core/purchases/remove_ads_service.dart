// "Remove ads" — the one real-money item (board C: one-time purchase, removes
// the banner and the break ads; reward ads stay as optional bonuses).
//
// Product id `remove_ads` (non-consumable). Flow:
//   * [RemoveAdsController.start] listens to the store's purchase stream at
//     launch (an unfinished or restored purchase can arrive any time) and loads
//     the product so Settings can show its price;
//   * [buy] opens the store sheet; [restore] replays past purchases (a new phone,
//     a reinstall). A purchased / restored `remove_ads` is acknowledged to the
//     store and saved as `DeviceState.adsRemoved` — that flag is all the rest of
//     the app (banner slot, break ads) looks at.
// Entitlement is trusted locally (no server): fine for a one-time "no ads".
// A purchase belongs to the store account, so backups never carry the flag.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../state/save_controller.dart';
import 'store_gateway.dart';

/// The store product id of "Remove ads".
const String kRemoveAdsProductId = 'remove_ads';

/// How a buy / restore ended.
enum PurchaseResult {
  /// Bought; ads are off.
  purchased,

  /// A past purchase was found and restored; ads are off.
  restored,

  /// The player closed the store sheet.
  canceled,

  /// The store reported an error.
  failed,

  /// Restore finished and found nothing for this account.
  nothingToRestore,

  /// No store on this phone, or it does not know the product.
  unavailable,

  /// Ads were already removed.
  alreadyOwned,
}

/// What Settings shows.
@immutable
class RemoveAdsState {
  const RemoveAdsState({this.price, this.busy = false});

  /// The store's price text ("$0.99", "৳ 120" …), or null until it is known.
  final String? price;

  /// A purchase or restore is in progress.
  final bool busy;

  /// Whether a buy can be offered (the store knows the product).
  bool get canBuy => price != null;

  RemoveAdsState copyWith({String? price, bool? busy}) =>
      RemoveAdsState(price: price ?? this.price, busy: busy ?? this.busy);
}

/// The store behind the controller. Overridden in tests with a fake.
final storeGatewayProvider = Provider<StoreGateway>(
  (ref) => InAppPurchaseGateway.supported ? InAppPurchaseGateway() : const NoStoreGateway(),
);

final removeAdsProvider = NotifierProvider<RemoveAdsController, RemoveAdsState>(RemoveAdsController.new);

class RemoveAdsController extends Notifier<RemoveAdsState> {
  /// How long a restore waits for the store to replay purchases before it
  /// concludes there is nothing to restore (the store sends nothing then).
  static const restoreWait = Duration(seconds: 8);

  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? _product;
  Completer<PurchaseResult>? _waiting;
  Timer? _restoreTimer;
  bool _restoring = false;

  StoreGateway get _store => ref.read(storeGatewayProvider);

  @override
  RemoveAdsState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _restoreTimer?.cancel();
    });
    return const RemoveAdsState();
  }

  /// Starts listening to the store and loads the product (price). Idempotent;
  /// called once after the first frame.
  Future<void> start() async {
    _sub ??= _store.purchases.listen(_onPurchases, onError: (Object _) => _finish(PurchaseResult.failed));
    await _loadProduct();
  }

  Future<ProductDetails?> _loadProduct() async {
    if (_product != null) return _product;
    if (!await _store.isAvailable()) return null;
    final p = await _store.product(kRemoveAdsProductId);
    if (p != null) {
      _product = p;
      state = state.copyWith(price: p.price);
    }
    return p;
  }

  /// Opens the store's purchase sheet and waits for the outcome.
  Future<PurchaseResult> buy() async {
    if (ref.read(adsRemovedProvider)) return PurchaseResult.alreadyOwned;
    if (state.busy) return PurchaseResult.failed;
    await start();
    final product = await _loadProduct();
    if (product == null) return PurchaseResult.unavailable;
    state = state.copyWith(busy: true);
    final waiting = _waiting = Completer<PurchaseResult>();
    final started = await _store.buy(product);
    if (!started) {
      _finish(PurchaseResult.failed);
    }
    return waiting.future;
  }

  /// Replays past purchases (a new phone, a reinstall).
  Future<PurchaseResult> restore() async {
    if (ref.read(adsRemovedProvider)) return PurchaseResult.alreadyOwned;
    if (state.busy) return PurchaseResult.failed;
    await start();
    if (!await _store.isAvailable()) return PurchaseResult.unavailable;
    state = state.copyWith(busy: true);
    _restoring = true;
    final waiting = _waiting = Completer<PurchaseResult>();
    try {
      await _store.restore();
    } catch (_) {
      _finish(PurchaseResult.failed);
      return waiting.future;
    }
    // The store answers with `restored` purchases, or with nothing at all.
    _restoreTimer = Timer(restoreWait, () {
      if (identical(_waiting, waiting)) _finish(PurchaseResult.nothingToRestore);
    });
    return waiting.future;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != kRemoveAdsProductId) {
        if (p.pendingCompletePurchase) await _store.complete(p);
        continue;
      }
      switch (p.status) {
        case PurchaseStatus.pending:
          break; // the store sheet is still working; stay busy
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          ref.read(saveProvider.notifier).setAdsRemoved(true);
          if (p.pendingCompletePurchase) await _store.complete(p);
          _finish(p.status == PurchaseStatus.restored || _restoring ? PurchaseResult.restored : PurchaseResult.purchased);
        case PurchaseStatus.canceled:
          if (p.pendingCompletePurchase) await _store.complete(p);
          _finish(PurchaseResult.canceled);
        case PurchaseStatus.error:
          if (p.pendingCompletePurchase) await _store.complete(p);
          _finish(PurchaseResult.failed);
      }
    }
  }

  /// Ends the current buy / restore with [result].
  void _finish(PurchaseResult result) {
    _restoring = false;
    _restoreTimer?.cancel();
    _restoreTimer = null;
    final waiting = _waiting;
    _waiting = null;
    if (state.busy) state = state.copyWith(busy: false);
    if (waiting != null && !waiting.isCompleted) waiting.complete(result);
  }
}
