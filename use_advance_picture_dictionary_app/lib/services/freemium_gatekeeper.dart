import 'billing_service.dart';
import 'picture_database_service.dart';

/// Gatekeeper logic determining which words/features are accessible on Free vs Pro.
class FreemiumGatekeeper {
  /// Number of starter words completely free for all users
  static const int freeWordLimit = 1000;

  /// Cache of canonical free words (lowercase)
  static final Set<String> _freeWords = <String>{};

  /// Initialize the canonical free words set from the database
  static Future<void> init() async {
    try {
      final freeSet = await PictureDatabaseService.instance.getFreeWordSet(limit: freeWordLimit);
      _freeWords.clear();
      _freeWords.addAll(freeSet);
    } catch (_) {}
  }

  /// Manually populate or update free words from a list of words
  static void setFreeWords(Iterable<String> words) {
    _freeWords.clear();
    for (final w in words.take(freeWordLimit)) {
      _freeWords.add(w.trim().toLowerCase());
    }
  }

  /// Checks if a word is unlocked for the current user.
  /// Accepts either a word [String] or a legacy [int] index.
  static bool isWordUnlocked(dynamic wordOrIndex) {
    // 1. Pro users and admins have full lifetime access to all words
    if (BillingService.instance.isProUnlocked) return true;

    // 2. If a String word is provided
    if (wordOrIndex is String) {
      final clean = wordOrIndex.trim().toLowerCase();
      if (_freeWords.isNotEmpty) {
        return _freeWords.contains(clean);
      }
      return false;
    }

    // 3. If an integer index is provided (legacy fallback)
    if (wordOrIndex is int) {
      return wordOrIndex < freeWordLimit;
    }

    return false;
  }
}
