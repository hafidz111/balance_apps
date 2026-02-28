import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../utils/ads_helper.dart';

class BannerAds extends StatefulWidget {
  const BannerAds({super.key});

  @override
  State<BannerAds> createState() => _BannerAdsState();
}

class _BannerAdsState extends State<BannerAds> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAd();
    });
  }

  Future<void> _loadAd() async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );

    if (size == null) {
      debugPrint("Ad size null");
      return;
    }

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

          setState(() {
            _bannerAd = ad as BannerAd;
          });
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
    if (_bannerAd == null) {
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
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }
}
