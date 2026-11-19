import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'state.dart';

/// Product ID of the one-time purchase in Play Console (Monetize › Products › In-app products).
const fullVersionId = 'tabmath_full';

/// Google Play purchase of the full version (one-time, no subscription).
/// The price shown comes from Google Play, in the buyer's currency.
class Billing {
  final AppState app;
  Billing(this.app);

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  ProductDetails? product;
  bool available = false;

  /// Messages for the screen that started a purchase: buy_done, buy_pending, buy_error.
  void Function(String key)? onMessage;

  Future<void> init() async {
    try {
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (_) => onMessage?.call('buy_error'));
      available = await _iap.isAvailable();
      if (!available) return;
      final r = await _iap.queryProductDetails({fullVersionId});
      if (r.productDetails.isNotEmpty) product = r.productDetails.first;
      // Brings back a purchase made earlier on this Google account (e.g. after reinstalling).
      await _iap.restorePurchases();
    } catch (_) {
      available = false;
    }
  }

  /// Price from Google Play, e.g. "4,99 zł"; null until the store has answered.
  String? get price => product?.price;

  Future<bool> buy() async {
    if (product == null) await init();
    final p = product;
    if (!available || p == null) return false;
    try {
      return await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
    } catch (_) {
      return false;
    }
  }

  Future<bool> restore() async {
    if (!available) await init();
    if (!available) return false;
    try {
      await _iap.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.productID != fullVersionId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          app.purchase();
          onMessage?.call('buy_done');
        case PurchaseStatus.pending:
          onMessage?.call('buy_pending');
        case PurchaseStatus.error:
          onMessage?.call('buy_error');
        case PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(p);
        } catch (_) {}
      }
    }
  }

  void dispose() => _sub?.cancel();
}

/// One instance for the whole app, created in main().
late Billing billing;
