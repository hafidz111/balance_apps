import 'package:starvy/screen/widgets/custom_snack_bar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  @override
  void initState() {
    super.initState();

    _checkPremium().then((_) {
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
    RewardedAd.load(
      adUnitId: widget.adUnitId,
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
          setState(() => _isReady = true);
        },
        onAdFailedToLoad: (error) {
          _analytics.logEvent(
            name: "rewarded_ad_failed",
            parameters: {"error": error.code},
          );
          setState(() => _isReady = false);

          Future.delayed(const Duration(seconds: 5), () {
            _loadAd();
          });
        },
      ),
    );
  }

  void _showAd() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 300));

    if (_isPremium) {
      await widget.onRewarded();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
      return;
    }

    if (_rewardedAd == null || !_isReady) {
      await _showInterstitialFallback();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd();
        if (mounted) {
          setState(() => _isProcessing = false);
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
          setState(() => _isProcessing = false);
        }
      },
    );

    _analytics.logEvent(
      name: "rewarded_ad_clicked",
      parameters: {"feature": widget.featureName},
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
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
    InterstitialAd.load(
      adUnitId: widget.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialReady = true;

          _analytics.logEvent(
            name: "interstitial_loaded",
            parameters: {"feature": widget.featureName},
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

  Future<void> _showInterstitialFallback() async {
    if (_interstitialAd == null || !_isInterstitialReady) {
      CustomSnackBar.show(
        context,
        message: "Iklan sedang tidak tersedia.",
        type: SnackType.error,
      );

      setState(() => _isProcessing = false);
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _loadInterstitial();

        await widget.onRewarded();

        if (mounted) {
          setState(() => _isProcessing = false);
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitial();

        setState(() => _isProcessing = false);
      },
    );

    _interstitialAd!.show();
  }

  @override
  Widget build(BuildContext context) {
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
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }
}
