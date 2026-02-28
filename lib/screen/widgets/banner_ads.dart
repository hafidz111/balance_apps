import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../utils/ads_helper.dart';

class BannerAds extends StatefulWidget {
  const BannerAds({super.key});

  @override
  State<BannerAds> createState() => _BannerAdsState();
}

class _BannerAdsState extends State<BannerAds> {
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
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd = ad as BannerAd;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint("Ad failed: $error");
          ad.dispose();
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
