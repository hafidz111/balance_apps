import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/rewarded_ads_provider.dart';
import '../../widgets/custom_snack_bar.dart';

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
  late final RewardedAdsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = RewardedAdsProvider(
      adUnitId: widget.adUnitId,
      interstitialAdUnitId: widget.interstitialAdUnitId,
      featureName: widget.featureName,
    );
    _provider.init();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _handleShowAd() {
    _provider.showAd(widget.onRewarded, (message) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: message, type: SnackType.error);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<RewardedAdsProvider>(
        builder: (context, provider, child) {
          final bool canPress = widget.enabled && !provider.isProcessing;

          if (widget.customChild != null) {
            return AbsorbPointer(
              absorbing: !canPress,
              child: GestureDetector(
                onTap: canPress ? _handleShowAd : null,
                child: widget.customChild!,
              ),
            );
          }

          final bool hasLabel = widget.label != null;

          if (!hasLabel) {
            return Opacity(
              opacity: canPress ? 1.0 : 0.55,
              child: IconButton(
                onPressed: canPress ? _handleShowAd : null,
                icon: provider.isProcessing
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
                        color:
                            widget.color ?? Theme.of(context).iconTheme.color,
                      ),
              ),
            );
          }

          return Opacity(
            opacity: canPress ? 1.0 : 0.55,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: canPress ? _handleShowAd : null,
                icon: Icon(
                  provider.isProcessing ? Icons.hourglass_top : (widget.icon),
                  size: 18,
                ),
                label: Text(
                  provider.isProcessing
                      ? (widget.loadingLabel ?? widget.label!)
                      : widget.label!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.color ?? Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
