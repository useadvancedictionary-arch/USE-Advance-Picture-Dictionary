import 'package:flutter/foundation.dart';
import '../models/picture_word_entry.dart';
import 'picture_database_service.dart';

class FavoritesHistoryService extends ChangeNotifier {
  static final FavoritesHistoryService instance = FavoritesHistoryService._();
  FavoritesHistoryService._();

  final Set<String> _favoriteWords = {};
  bool _isInitialized = false;

  Set<String> get favoriteWords => Set.unmodifiable(_favoriteWords);

  bool isFavorite(String word) {
    return _favoriteWords.contains(word.trim().toLowerCase());
  }

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final words = await PictureDatabaseService.instance.getAllFavoriteWords();
      _favoriteWords.clear();
      for (final w in words) {
        _favoriteWords.add(w.trim().toLowerCase());
      }
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing favorites: $e');
    }
  }

  /// Toggles favorite for the given word. Returns true if now favorited, false if removed.
  Future<bool> toggleFavorite(String word) async {
    final clean = word.trim();
    if (clean.isEmpty) return false;
    final lower = clean.toLowerCase();

    final bool nowFavorite;
    if (_favoriteWords.contains(lower)) {
      _favoriteWords.remove(lower);
      nowFavorite = false;
      notifyListeners();
      await PictureDatabaseService.instance.removeFavorite(clean);
    } else {
      _favoriteWords.add(lower);
      nowFavorite = true;
      notifyListeners();
      await PictureDatabaseService.instance.addFavorite(clean);
    }
    return nowFavorite;
  }

  Future<void> removeFavorite(String word) async {
    final clean = word.trim();
    final lower = clean.toLowerCase();
    if (_favoriteWords.remove(lower)) {
      notifyListeners();
    }
    await PictureDatabaseService.instance.removeFavorite(clean);
  }

  Future<void> clearAllFavorites() async {
    _favoriteWords.clear();
    notifyListeners();
    await PictureDatabaseService.instance.clearAllFavorites();
  }

  Future<List<PictureWordEntry>> getFavoriteEntries() async {
    return await PictureDatabaseService.instance.getFavoriteEntries();
  }

  // ── History Methods ──
  Future<void> recordHistory(String word) async {
    final clean = word.trim();
    if (clean.isEmpty) return;
    await PictureDatabaseService.instance.addToHistory(clean);
    notifyListeners();
  }

  Future<void> removeFromHistory(String word) async {
    final clean = word.trim();
    if (clean.isEmpty) return;
    await PictureDatabaseService.instance.removeFromHistory(clean);
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    await PictureDatabaseService.instance.clearAllHistory();
    notifyListeners();
  }

  Future<List<PictureWordEntry>> getHistoryEntries() async {
    return await PictureDatabaseService.instance.getHistoryEntries();
  }
}

