import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'billing_service.dart';

/// Manages AdMob banners, interstitials, and rewarded ads.
/// Automatically disables all ads if user has purchased Pro.
class AdService {
  static final AdService instance = AdService._internal();
  AdService._internal();

  bool _isInitialized = false;

  // Production Google AdMob ad unit IDs
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3912695475743612/9666570517'; // Production banner
    }
    return '';
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Google test interstitial
    }
    return '';
  }

  /// Initialize Mobile Ads SDK (only on supported platforms)
  Future<void> init() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      debugPrint('AdService: MobileAds initialized successfully');
    } catch (e) {
      debugPrint('AdService: MobileAds init failed: $e');
    }
  }

  /// Create a banner ad if user is on Free tier
  BannerAd? createBannerAd({required Function() onAdLoaded, required Function(LoadAdError) onAdFailed}) {
    if (BillingService.instance.isProUnlocked) return null;
    if (kIsWeb || !Platform.isAndroid) return null;
    if (!_isInitialized) return null;

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('AdService: Banner loaded');
          onAdLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdService: Banner failed to load: $error');
          ad.dispose();
          onAdFailed(error);
        },
      ),
    );
  }
}

