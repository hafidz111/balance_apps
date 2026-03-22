import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:starvy/screen/widgets/custom_snack_bar.dart';

import '../../../service/premium_service.dart';

class RewardedAds extends StatefulWidget {
  final String adUnitId;
  final Future<void> Function() onRewarded;
  final String? label;
  final String? loadingLabel;
  final IconData? icon;
  final Color? color;
  final bool enabled;
  final String featureName;
  final Widget? customChild;
  final String interstitialAdUnitId;

  const RewardedAds({
    super.key,
    required this.adUnitId,
    required this.onRewarded,
    this.icon,
    this.color,
    this.label,
    this.loadingLabel,
    this.enabled = true,
    required this.featureName,
    this.customChild,
    required this.interstitialAdUnitId,
  });

  @override
  State<RewardedAds> createState() => _RewardedAdsState();
}

class _RewardedAdsState extends State<RewardedAds> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  RewardedAd? _rewardedAd;
  bool _isReady = false;
  bool _isProcessing = false;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialReady = false;

  bool _isPremium = false;
  final ValueNotifier<int> _renderTick = ValueNotifier<int>(0);

  void _refresh() {
    if (mounted) _renderTick.value++;
  }

  @override
  void initState() {
    super.initState();

    _checkPremium().then((_) {
      if (!mounted) return;
      if (!_isPremium) {
        _loadAd();
        _loadInterstitial();
      }
    });
  }

  Future<void> _checkPremium() async {
    _isPremium = PremiumService.cachedPremium
        ? true
        : await PremiumService.isPremium();
  }

  void _loadAd() {
    if (!mounted) return;
    RewardedAd.load(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _rewardedAd = ad;
          ad.onPaidEvent =
              (
                Ad ad,
                double valueMicros,
                PrecisionType precision,
                String currencyCode,
              ) {
                if (!mounted) return;
                final revenue = valueMicros / 1000000;

                _analytics.logEvent(
                  name: "ad_revenue",
                  parameters: {
                    "ad_type": "rewarded",
                    "feature": widget.featureName,
                    "value": revenue,
                    "currency": currencyCode,
                    "precision": precision.name,
                  },
                );
              };
          _analytics.logEvent(
            name: "rewarded_ad_loaded",
            parameters: {"feature": widget.featureName},
          );
          _isReady = true;
          _refresh();
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          _analytics.logEvent(
            name: "rewarded_ad_failed",
            parameters: {"error": error.code},
          );
          _isReady = false;
          _refresh();

          Future.delayed(const Duration(seconds: 5), () {
            if (!mounted) return;
            _loadAd();
          });
        },
      ),
    );
  }

  void _showAd() async {
    if (_isProcessing) return;

    _isProcessing = true;
    _refresh();
    await Future.delayed(const Duration(milliseconds: 300));

    if (_isPremium) {
      await widget.onRewarded();
      if (mounted) {
        _isProcessing = false;
        _refresh();
      }
      return;
    }

    if (_interstitialAd != null && _isInterstitialReady) {
      _showInterstitialOnly();
      return;
    }

    if (_rewardedAd != null && _isReady) {
      _showRewardedAdOnly();
      return;
    }

    if (mounted) {
      CustomSnackBar.show(
        context,
        message: "Iklan sedang tidak tersedia.",
        type: SnackType.error,
      );
      _isProcessing = false;
      _refresh();
    }
  }

  void _showInterstitialOnly() {
    _analytics.logEvent(
      name: "interstitial_ad_clicked",
      parameters: {"feature": widget.featureName},
    );

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        _loadInterstitial();

        _analytics.logEvent(
          name: "interstitial_ad_dismissed",
          parameters: {"feature": widget.featureName},
        );

        await widget.onRewarded();

        if (mounted) {
          _isProcessing = false;
          _refresh();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        _isInterstitialReady = false;
        _loadInterstitial();

        _analytics.logEvent(
          name: "interstitial_ad_failed_to_show",
          parameters: {"feature": widget.featureName, "error": error.message},
        );

        if (mounted) {
          _showRewardedOrFinishWithError();
        }
      },
    );

    _interstitialAd!.show();
  }

  void _showRewardedOrFinishWithError() {
    if (_rewardedAd != null && _isReady) {
      _showRewardedAdOnly();
      return;
    }

    CustomSnackBar.show(
      context,
      message: "Iklan sedang tidak tersedia.",
      type: SnackType.error,
    );
    _isProcessing = false;
    _refresh();
  }

  void _showRewardedAdOnly() {
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd();
        if (mounted) {
          _isProcessing = false;
          _refresh();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadAd();

        if (mounted) {
          CustomSnackBar.show(
            context,
            message: "Iklan gagal ditampilkan. Coba lagi dalam 1 jam.",
            type: SnackType.error,
          );
          _isProcessing = false;
          _refresh();
        }
      },
    );

    _analytics.logEvent(
      name: "rewarded_ad_clicked",
      parameters: {"feature": widget.featureName},
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        if (!mounted) return;
        _analytics.logEvent(
          name: "rewarded_ad_completed",
          parameters: {
            "feature": widget.featureName,
            "reward_type": reward.type,
            "reward_amount": reward.amount,
          },
        );
        await widget.onRewarded();
      },
    );
  }

  void _loadInterstitial() {
    if (!mounted) return;
    InterstitialAd.load(
      adUnitId: widget.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          _interstitialAd = ad;
          _isInterstitialReady = true;

          _analytics.logEvent(
            name: "interstitial_loaded",
            parameters: {"feature": widget.featureName},
          );
        },
        onAdFailedToLoad: (error) {
          if (!mounted) return;
          _isInterstitialReady = false;

          _analytics.logEvent(
            name: "interstitial_failed",
            parameters: {"error": error.code},
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _renderTick,
      builder: (_, __, ___) {
        final bool canPress = widget.enabled && !_isProcessing;

        if (widget.customChild != null) {
          return AbsorbPointer(
            absorbing: !canPress,
            child: GestureDetector(
              onTap: canPress ? _showAd : null,
              child: widget.customChild!,
            ),
          );
        }

        final bool hasLabel = widget.label != null;

        if (!hasLabel) {
          return IconButton(
            onPressed: canPress ? _showAd : null,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.icon ?? Icons.star,
                    color: widget.color ?? Theme.of(context).iconTheme.color,
                  ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: canPress ? _showAd : null,
            icon: Icon(
              _isProcessing ? Icons.hourglass_top : (widget.icon),
              size: 18,
            ),
            label: Text(
              _isProcessing
                  ? (widget.loadingLabel ?? widget.label!)
                  : widget.label!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color ?? Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  (widget.color ?? Theme.of(context).primaryColor).withValues(
                    alpha: 0.4,
                  ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isReady = false;
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialReady = false;
    _renderTick.dispose();
    super.dispose();
  }
}
