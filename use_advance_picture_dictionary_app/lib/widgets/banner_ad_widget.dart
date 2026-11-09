import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/billing_service.dart';
import '../services/ad_service.dart';

/// Renders a banner ad at the bottom of the screen for Free tier users.
/// Automatically hides and disposes if the user upgrades to Pro.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
    BillingService.instance.addListener(_onBillingChanged);
  }

  void _onBillingChanged() {
    if (BillingService.instance.isProUnlocked) {
      _bannerAd?.dispose();
      _bannerAd = null;
      if (mounted) {
        setState(() => _isLoaded = false);
      }
    }
  }

  void _loadAd() {
    if (kIsWeb || !Platform.isAndroid) return;
    if (BillingService.instance.isProUnlocked) return;

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
          _bannerAd = null;
          if (mounted) {
            setState(() => _isLoaded = false);
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    BillingService.instance.removeListener(_onBillingChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BillingService.instance.isProUnlocked || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      top: false,
      child: Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        color: Theme.of(context).colorScheme.surface,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

