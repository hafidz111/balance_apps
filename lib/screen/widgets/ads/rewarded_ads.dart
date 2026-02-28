import 'package:balance/screen/widgets/custom_snack_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAds extends StatefulWidget {
  final String adUnitId;
  final Future<void> Function() onRewarded;
  final String? label;
  final String? loadingLabel;
  final IconData icon;
  final Color color;
  final bool enabled;

  const RewardedAds({
    super.key,
    required this.adUnitId,
    required this.onRewarded,
    required this.icon,
    required this.color,
    this.label,
    this.loadingLabel,
    this.enabled = true,
  });

  @override
  State<RewardedAds> createState() => _RewardedAdsState();
}

class _RewardedAdsState extends State<RewardedAds> {
  RewardedAd? _rewardedAd;
  bool _isReady = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    RewardedAd.load(
      adUnitId: widget.adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          setState(() => _isReady = true);
        },
        onAdFailedToLoad: (error) {
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

    if (_rewardedAd == null || !_isReady) {
      if(!mounted) return;
      CustomSnackBar.show(
        context,
        message: "Iklan sedang tidak tersedia. Coba lagi nanti.",
        type: SnackType.error,
      );

      setState(() => _isProcessing = false);
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

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        await widget.onRewarded();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPress = widget.enabled && !_isProcessing;

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
            : Icon(widget.icon, color: widget.color),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: canPress ? _showAd : null,
        icon: Icon(_isProcessing ? Icons.hourglass_top : widget.icon, size: 18),
        label: Text(
          _isProcessing
              ? (widget.loadingLabel ?? widget.label!)
              : widget.label!,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: widget.color.withValues(alpha: 0.4),
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
