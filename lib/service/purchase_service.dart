import 'dart:async';

import 'package:starvy/service/premium_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PurchaseService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  static const String removeAdsId = "remove_ads";

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  Future<void> init() async {
    if (_subscription != null) return;

    final bool available = await _iap.isAvailable();
    if (!available) return;

    _subscription = _iap.purchaseStream.listen(
      _listenToPurchaseUpdated,
      onDone: () => _subscription?.cancel(),
      onError: (error) {},
    );

    await _iap.restorePurchases();
  }

  Future<void> buyRemoveAds() async {
    final response = await _iap.queryProductDetails({removeAdsId});

    if (response.productDetails.isEmpty) {
      throw Exception("Produk tidak ditemukan");
    }

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );

    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        if (purchase.productID == removeAdsId) {
          await PremiumService.setPremium(
            purchaseToken: purchase.verificationData.serverVerificationData,
          );
        }

        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      }

      if (purchase.status == PurchaseStatus.error) {
        print("Purchase error: ${purchase.error}");
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
