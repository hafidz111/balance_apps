import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class RewardedAds extends StatefulWidget {
  final String adUnitId;
  final Future<void> Function() onRewarded;
  final String? label;
  final String? loadingLabel;
  final IconData icon;
  final Color color;
  final bool enabled; // 🔥 tambahkan ini

  const RewardedAds({
    super.key,
    required this.adUnitId,
    required this.onRewarded,
    required this.icon,
    required this.color,
    this.label,
    this.loadingLabel,
    this.enabled = true, // default true
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
        onAdFailedToLoad: (_) {
          setState(() => _isReady = false);
        },
      ),
    );
  }

  void _showAd() {
    if (_rewardedAd == null) return;

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) async {
        setState(() => _isProcessing = true);

        await widget.onRewarded();

        setState(() => _isProcessing = false);
      },
    );

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadAd();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canPress = widget.enabled && _isReady && !_isProcessing;

    final bool hasLabel = widget.label != null;

    if (!hasLabel) {
      return IconButton(
        onPressed: canPress ? _showAd : null,
        icon: Icon(
          _isProcessing ? Icons.hourglass_top : widget.icon,
          color: widget.color,
        ),
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
