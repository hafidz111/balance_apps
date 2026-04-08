import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../../../providers/banner_ads_provider.dart';

class BannerAds extends StatelessWidget {
  const BannerAds({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BannerAdsProvider>(
      builder: (context, provider, child) {
        if (!provider.isInitialized) {
          return const SizedBox();
        }

        if (provider.isPremium || provider.bannerAd == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted &&
                !provider.isPremium &&
                provider.bannerAd == null) {
              final maxWidth = MediaQuery.of(context).size.width.truncate();
              provider.loadAd(maxWidth);
            }
          });
          return const SizedBox();
        }

        final bannerAd = provider.bannerAd!;

        return Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: bannerAd.size.width.toDouble(),
            height: bannerAd.size.height.toDouble(),
            child: AdWidget(ad: bannerAd),
          ),
        );
      },
    );
  }
}
