import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../service/premium_service.dart';
import '../utils/ads_helper.dart';

class BannerAdsProvider extends ChangeNotifier {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  BannerAd? _bannerAd;
  bool _isPremium = false;
  bool _isInitialized = false;

  BannerAd? get bannerAd => _bannerAd;

  bool get isPremium => _isPremium;

  bool get isInitialized => _isInitialized;

  BannerAdsProvider() {
    _init();
  }

  Future<void> _init() async {
    _isPremium = PremiumService.cachedPremium
        ? true
        : await PremiumService.isPremium();

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> loadAd(int maxWidth) async {
    if (_isPremium || _bannerAd != null) return;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      maxWidth,
    );

    if (size == null) return;

    final banner = BannerAd(
      adUnitId: AdsHelper.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _analytics.logEvent(name: "banner_ad_loaded");
          _bannerAd = ad as BannerAd;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          _analytics.logEvent(
            name: "banner_ad_failed",
            parameters: {"error": error.code},
          );
          debugPrint("Ad failed: $error");
          ad.dispose();
          _bannerAd = null;
          notifyListeners();
        },
        onPaidEvent:
            (
              Ad ad,
              double valueMicros,
              PrecisionType precision,
              String currencyCode,
            ) {
              final revenue = valueMicros / 1000000;
              _analytics.logEvent(
                name: "ad_revenue",
                parameters: {
                  "ad_type": "banner",
                  "value": revenue,
                  "currency": currencyCode,
                  "precision": precision.name,
                },
              );
            },
      ),
    );

    banner.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
