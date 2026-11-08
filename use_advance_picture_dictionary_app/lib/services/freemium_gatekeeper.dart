import 'billing_service.dart';

/// Gatekeeper logic determining which words/features are accessible on Free vs Pro.
class FreemiumGatekeeper {
  /// Number of starter words completely free for all users
  static const int freeWordLimit = 1000;

  /// Checks if a word entry at [index] in the dictionary is unlocked.
  static bool isWordUnlocked(int? index) {
    if (BillingService.instance.isProUnlocked) return true;
    if (index == null) return true;
    return index < freeWordLimit;
  }
}

