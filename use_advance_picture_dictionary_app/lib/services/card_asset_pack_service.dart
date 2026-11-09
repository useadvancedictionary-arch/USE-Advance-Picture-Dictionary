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
  Uint8List? getFromCache(String path, [String? word]) {
    final key = _normalizeKey(path);
    if (_cache.containsKey(key)) return _cache[key];

    if (word != null && word.trim().isNotEmpty) {
      final safeWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
      for (final ext in ['jpg', 'png']) {
        final wk1 = 'assets/cards/$safeWord.$ext';
        final wk2 = 'cards/$safeWord.$ext';
        if (_cache.containsKey(wk1)) return _cache[wk1];
        if (_cache.containsKey(wk2)) return _cache[wk2];
      }
    }
    return null;
  }

  String _normalizeKey(String path) {
    return path.replaceAll('\\', '/').trim();
  }

  /// Load raw image bytes for a card from the asset pack or local disk
  Future<Uint8List?> loadCardBytes(String rawPath, [String? word]) async {
    final path = _normalizeKey(rawPath);
    if (path.isEmpty && (word == null || word.trim().isEmpty)) return null;

    final cached = getFromCache(rawPath, word);
    if (cached != null) return cached;

    // Build ordered list of candidate paths to check
    final candidates = <String>[];
    if (path.isNotEmpty) {
      candidates.add(path);
      // Clean path if it has "file://" or leading slashes
      final clean = path.replaceFirst('file://', '');
      final filename = clean.split('/').last;
      final nameWithoutExt = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final baseName = nameWithoutExt
          .replaceAll(RegExp(r'(_card)?_\d+$'), '')
          .replaceAll(RegExp(r'_card$'), '');

      if (baseName.isNotEmpty && baseName != nameWithoutExt) {
        candidates.add('assets/cards/$baseName.jpg');
        candidates.add('assets/cards/$baseName.png');
        candidates.add('cards/$baseName.jpg');
        candidates.add('cards/$baseName.png');
      }

      if (clean.contains('cards/')) {
        candidates.add('assets/cards/$filename');
        candidates.add('cards/$filename');
      }
    }

    if (word != null && word.trim().isNotEmpty) {
      final safeWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
      candidates.add('assets/cards/$safeWord.jpg');
      candidates.add('assets/cards/$safeWord.png');
      candidates.add('cards/$safeWord.jpg');
      candidates.add('cards/$safeWord.png');
    }

    // Try candidates one by one
    for (final candidate in candidates) {
      final bytes = await _loadSinglePathBytes(candidate);
      if (bytes != null && bytes.isNotEmpty) {
        if (path.isNotEmpty) {
          _putInCache(path, bytes);
        }
        return bytes;
      }
    }
    return null;
  }

  Future<Uint8List?> _loadSinglePathBytes(String path) async {
    if (_cache.containsKey(path)) return _cache[path];

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

        // Try project-relative and exe-relative paths
        final filename = clean.split(RegExp(r'[/\\]')).last;
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        final projectCandidates = [
          '$exeDir/data/flutter_assets/assets/cards/$filename',
          '$exeDir/assets/cards/$filename',
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
  Future<bool> hasCard(String rawPath, [String? word]) async {
    final path = _normalizeKey(rawPath);
    if (_cache.containsKey(path)) return true;

    final bytes = await loadCardBytes(rawPath, word);
    return bytes != null && bytes.isNotEmpty;
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

