import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service to load card images from the Android Play Asset Delivery (PAD) install-time asset pack,
/// with fallback to local disk files and rootBundle for Desktop/Windows.
class CardAssetPackService {
  CardAssetPackService._();
  static final CardAssetPackService instance = CardAssetPackService._();

  static const MethodChannel _channel = MethodChannel('com.useadvance.picture_dict/asset_pack');

  // In-memory LRU-like byte cache to ensure smooth scrolling without redundant channel calls
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  static const int _maxCacheSize = 250;

  /// Clear the in-memory cache
  void clearCache() {
    _cache.clear();
  }

  /// Check if the image bytes are already cached in memory
  Uint8List? getFromCache(String path) {
    final key = _normalizeKey(path);
    return _cache[key];
  }

  String _normalizeKey(String path) {
    return path.replaceAll('\\', '/').trim();
  }

  /// Load raw image bytes for a card from the asset pack or local disk
  Future<Uint8List?> loadCardBytes(String rawPath) async {
    final path = _normalizeKey(rawPath);
    if (path.isEmpty) return null;

    if (_cache.containsKey(path)) {
      return _cache[path];
    }

    // 1. On Android: Try loading via native AssetManager (Play Asset Delivery install-time pack)
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _channel.invokeMethod<Uint8List>('getCardBytes', {'path': path});
        if (result != null && result.isNotEmpty) {
          _putInCache(path, result);
          return result;
        }
      } catch (_) {
        // Fall through to other strategies
      }
    }

    // 2. On Desktop / Windows: Check direct local disk file
    if (!kIsWeb) {
      try {
        final clean = path.replaceFirst('file://', '');
        final direct = File(clean);
        if (await direct.exists()) {
          final bytes = await direct.readAsBytes();
          _putInCache(path, bytes);
          return bytes;
        }

        // Try project-relative paths
        final filename = clean.split(RegExp(r'[/\\]')).last;
        final projectCandidates = [
          'D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$filename',
          'assets/cards/$filename',
          clean,
        ];
        for (final candidate in projectCandidates) {
          final f = File(candidate);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            _putInCache(path, bytes);
            return bytes;
          }
        }
      } catch (_) {}
    }

    // 3. Try standard rootBundle as a last resort
    try {
      final clean = path.startsWith('assets/') ? path : 'assets/$path';
      final byteData = await rootBundle.load(clean);
      final bytes = byteData.buffer.asUint8List();
      _putInCache(path, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Check if a card asset exists
  Future<bool> hasCard(String rawPath) async {
    final path = _normalizeKey(rawPath);
    if (_cache.containsKey(path)) return true;

    if (!kIsWeb && Platform.isAndroid) {
      try {
        final exists = await _channel.invokeMethod<bool>('checkCardExists', {'path': path});
        return exists ?? false;
      } catch (_) {
        return false;
      }
    }

    // On other platforms, check file existence
    if (!kIsWeb) {
      final filename = path.split(RegExp(r'[/\\]')).last;
      final f = File('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$filename');
      if (f.existsSync()) return true;
    }

    try {
      final clean = path.startsWith('assets/') ? path : 'assets/$path';
      await rootBundle.load(clean);
      return true;
    } catch (_) {
      return false;
    }
  }

  void _putInCache(String key, Uint8List bytes) {
    if (_cache.length >= _maxCacheSize) {
      // Remove the oldest 50 entries
      final keysToRemove = _cache.keys.take(50).toList();
      for (final k in keysToRemove) {
        _cache.remove(k);
      }
    }
    _cache[key] = bytes;
  }
}

