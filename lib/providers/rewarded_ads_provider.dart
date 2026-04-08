import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../service/premium_service.dart';

class RewardedAdsProvider extends ChangeNotifier {
  final String adUnitId;
  final String interstitialAdUnitId;
  final String featureName;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  RewardedAd? _rewardedAd;
  bool _isReady = false;
  bool _isProcessing = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  bool _isPremium = false;

  bool get isReady => _isReady;

  bool get isProcessing => _isProcessing;

  bool get isPremium => _isPremium;

  RewardedAdsProvider({
    required this.adUnitId,
    required this.interstitialAdUnitId,
    required this.featureName,
  });

  Future<void> init() async {
    _isPremium = PremiumService.cachedPremium
        ? true
        : await PremiumService.isPremium();

    if (!_isPremium) {
      _loadAd();
      _loadInterstitial();
    } else {
      notifyListeners();
    }
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          ad.onPaidEvent =
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
                    "ad_type": "rewarded",
                    "feature": featureName,
                    "value": revenue,
                    "currency": currencyCode,
                    "precision": precision.name,
                  },
                );
              };
          _analytics.logEvent(
            name: "rewarded_ad_loaded",
            parameters: {"feature": featureName},
          );
          _isReady = true;
          notifyListeners();
        },
        onAdFailedToLoad: (error) {
          _analytics.logEvent(
            name: "rewarded_ad_failed",
            parameters: {"error": error.code},
          );
          _isReady = false;
          notifyListeners();

          Future.delayed(const Duration(seconds: 5), () {
            _loadAd();
          });
        },
      ),
    );
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;

          _analytics.logEvent(
            name: "interstitial_loaded",
            parameters: {"feature": featureName},
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialReady = false;
          _analytics.logEvent(
            name: "interstitial_failed",
            parameters: {"error": error.code},
          );
        },
      ),
    );
  }

  Future<bool> showAd(
    Future<void> Function() onRewarded,
    void Function(String message) showError,
  ) async {
    if (_isProcessing) return false;

    _isProcessing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    if (_isPremium) {
      await onRewarded();
      _isProcessing = false;
      notifyListeners();
      return true;
    }

    if (_interstitialAd != null && _isInterstitialReady) {
      _showInterstitialOnly(onRewarded, showError);
      return true;
    }

    if (_rewardedAd != null && _isReady) {
      _showRewardedAdOnly(onRewarded, showError);
      return true;
    }

    showError("Iklan sedang tidak tersedia.");
    _isProcessing = false;
    notifyListeners();
    return false;
  }

  void _showInterstitialOnly(
    Future<void> Function() onRewarded,
    void Function(String message) showError,
  ) {
    _analytics.logEvent(
      name: "interstitial_ad_clicked",
      parameters: {"feature": featureName},
    );

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        _loadInterstitial();

        _analytics.logEvent(
          name: "interstitial_ad_dismissed",
          parameters: {"feature": featureName},
        );

        await onRewarded();

        _isProcessing = false;
        notifyListeners();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        _loadInterstitial();

        _analytics.logEvent(
          name: "interstitial_ad_failed_to_show",
          parameters: {"feature": featureName, "error": error.message},
        );

        _showRewardedOrFinishWithError(onRewarded, showError);
      },
    );

    _interstitialAd!.show();
  }

  void _showRewardedOrFinishWithError(
    Future<void> Function() onRewarded,
    void Function(String message) showError,
  ) {
    if (_rewardedAd != null && _isReady) {
      _showRewardedAdOnly(onRewarded, showError);
      return;
    }

    showError("Iklan sedang tidak tersedia.");
    _isProcessing = false;
    notifyListeners();
  }

  void _showRewardedAdOnly(
    Future<void> Function() onRewarded,
    void Function(String message) showError,
  ) {
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd();
        _isProcessing = false;
        notifyListeners();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadAd();

        showError("Iklan gagal ditampilkan. Coba lagi dalam beberapa saat.");
        _isProcessing = false;
        notifyListeners();
      },
    );

    _analytics.logEvent(
      name: "rewarded_ad_clicked",
      parameters: {"feature": featureName},
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        _analytics.logEvent(
          name: "rewarded_ad_completed",
          parameters: {
            "feature": featureName,
            "reward_type": reward.type,
            "reward_amount": reward.amount,
          },
        );
        await onRewarded();
      },
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    super.dispose();
  }
}
