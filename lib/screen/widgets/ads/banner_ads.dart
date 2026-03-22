import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../service/premium_service.dart';
import '../../../utils/ads_helper.dart';

class BannerAds extends StatefulWidget {
  const BannerAds({super.key});

  @override
  State<BannerAds> createState() => _BannerAdsState();
}

class _BannerAdsState extends State<BannerAds> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  BannerAd? _bannerAd;
  bool _isPremium = false;
  final ValueNotifier<int> _renderTick = ValueNotifier<int>(0);

  void _refresh() {
    _renderTick.value++;
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isPremium = PremiumService.cachedPremium
        ? true
        : await PremiumService.isPremium();

    if (!_isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAd();
      });
    }

    if (mounted) _refresh();
  }

  Future<void> _loadAd() async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) return;

    final banner = BannerAd(
      adUnitId: AdsHelper.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _analytics.logEvent(name: "banner_ad_loaded");
          if (!mounted) {
            ad.dispose();
            return;
          }

          _bannerAd = ad as BannerAd;
          _refresh();
        },
        onAdFailedToLoad: (ad, error) {
          _analytics.logEvent(
            name: "banner_ad_failed",
            parameters: {"error": error.code},
          );
          debugPrint("Ad failed: $error");
          ad.dispose();
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _renderTick,
      builder: (_, __, ___) {
        if (_isPremium || _bannerAd == null) {
          return const SizedBox();
        }

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: _bannerAd!.size.width.toDouble(),
            height: _bannerAd!.size.height.toDouble(),
            child: AdWidget(ad: _bannerAd!),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _renderTick.dispose();
    super.dispose();
  }
}
