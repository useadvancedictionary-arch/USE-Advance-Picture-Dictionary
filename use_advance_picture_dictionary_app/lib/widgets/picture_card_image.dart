import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/card_asset_pack_service.dart';

/// Unified Picture Image component that supports local assets, local files, and remote URLs
class PictureCardImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? word;

  const PictureCardImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
    this.word,
  });

  /// Resolve a local fallback file on disk when Image.asset or a file path cannot be resolved directly
  static File? resolveLocalDiskFile(String rawUrl, [String? word]) {
    if (kIsWeb) return null;
    try {
      final clean = rawUrl.trim().replaceFirst('file://', '');
      if (clean.isEmpty) return null;

      // 1. Direct file check
      final direct = File(clean);
      if (direct.existsSync()) return direct;

      final filename = clean.split(Platform.isWindows ? RegExp(r'[/\\]') : RegExp(r'/')).last;
      final nameWithoutExt = filename.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final baseName = nameWithoutExt
          .replaceAll(RegExp(r'(_card)?_\d+$'), '')
          .replaceAll(RegExp(r'_card$'), '');

      // Common directories where cards might reside
      final candidates = <String>[];

      // Next to the running executable (e.g. Release build flutter_assets)
      try {
        final exeDir = File(Platform.resolvedExecutable).parent.path;
        candidates.add('$exeDir/data/flutter_assets/$clean');
        candidates.add('$exeDir/data/flutter_assets/assets/cards/$filename');
        if (baseName.isNotEmpty && baseName != nameWithoutExt) {
          candidates.add('$exeDir/data/flutter_assets/assets/cards/$baseName.jpg');
          candidates.add('$exeDir/data/flutter_assets/assets/cards/$baseName.png');
        }
        if (word != null && word.trim().isNotEmpty) {
          final safeWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
          candidates.add('$exeDir/data/flutter_assets/assets/cards/$safeWord.jpg');
          candidates.add('$exeDir/data/flutter_assets/assets/cards/$safeWord.png');
        }
      } catch (_) {}

      // Project directory on disk
      candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/$clean');
      candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$filename');
      if (baseName.isNotEmpty && baseName != nameWithoutExt) {
        candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$baseName.jpg');
        candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$baseName.png');
      }

      // Safe word in project directory
      if (word != null && word.trim().isNotEmpty) {
        final safeWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
        candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$safeWord.jpg');
        candidates.add('D:/USE_Advance_Picture_Dictionary/use_advance_picture_dictionary_app/assets/cards/$safeWord.png');
      }

      // User Profile Documents / custom_cards
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final customCardsDir = '$userProfile/Documents/USE_Advance_Picture_Dictionary/custom_cards';
        candidates.add('$customCardsDir/$filename');
        candidates.add('$customCardsDir/${nameWithoutExt}_card.png');
        candidates.add('$customCardsDir/${nameWithoutExt}_card.jpg');
        candidates.add('$customCardsDir/$nameWithoutExt.png');
        candidates.add('$customCardsDir/$nameWithoutExt.jpg');
        if (baseName.isNotEmpty && baseName != nameWithoutExt) {
          candidates.add('$customCardsDir/${baseName}_card.png');
          candidates.add('$customCardsDir/${baseName}_card.jpg');
          candidates.add('$customCardsDir/$baseName.png');
          candidates.add('$customCardsDir/$baseName.jpg');
        }

        if (word != null && word.trim().isNotEmpty) {
          final safeWord = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
          candidates.add('$customCardsDir/${safeWord}_card.png');
          candidates.add('$customCardsDir/${safeWord}_card.jpg');
          candidates.add('$customCardsDir/$safeWord.png');
          candidates.add('$customCardsDir/$safeWord.jpg');
        }
      }

      // Check all candidate paths (and try alternating .png <-> .jpg)
      for (final candidate in candidates) {
        final normalized = candidate.replaceAll('\\', '/');
        final f = File(normalized);
        if (f.existsSync()) return f;

        if (normalized.endsWith('.png')) {
          final alt = File('${normalized.substring(0, normalized.length - 4)}.jpg');
          if (alt.existsSync()) return alt;
        } else if (normalized.endsWith('.jpg')) {
          final alt = File('${normalized.substring(0, normalized.length - 4)}.png');
          if (alt.existsSync()) return alt;
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanUrl = imageUrl.trim();

    // 0. Remote Network URL (http/https)
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: cleanUrl,
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: 600,
        memCacheHeight: 450,
        maxWidthDiskCache: 1200,
        maxHeightDiskCache: 900,
        placeholder: (context, url) =>
            placeholder ??
            Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        errorWidget: (context, url, error) {
          // Fall back to local disk / asset pack if network image is unavailable
          return _buildLocalOrAssetPackFallback(context, theme, cleanUrl);
        },
      );
    }

    // 1. Android: check if we should load via CardAssetPackService (Play Asset Delivery)
    // On Android, ANY local path (including Windows desktop paths like C:\...) or asset path
    // is checked via CardAssetPackService which looks inside the install-time asset pack
    if (!kIsWeb && Platform.isAndroid) {
      // If a local file directly exists on this Android device filesystem, load it
      if (cleanUrl.startsWith('/') && File(cleanUrl).existsSync()) {
        return Image.file(
          File(cleanUrl),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _buildAndroidAssetPackImage(context, theme, cleanUrl),
        );
      }
      return _buildAndroidAssetPackImage(context, theme, cleanUrl);
    }

    // 2. Desktop / Windows / Linux / macOS: Local disk file resolution
    if (!kIsWeb) {
      final diskFile = resolveLocalDiskFile(cleanUrl, word);
      if (diskFile != null) {
        return Image.file(
          diskFile,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return _buildLocalOrAssetPackFallback(context, theme, cleanUrl);
          },
        );
      }
    }

    // 3. Local Flutter Asset (e.g. assets/cards/abandon.jpg)
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return _buildLocalOrAssetPackFallback(context, theme, cleanUrl);
        },
      );
    }

    // 4. Default fallback: attempt asset pack or disk resolution for the word
    return _buildLocalOrAssetPackFallback(context, theme, cleanUrl);
  }

  Widget _buildAndroidAssetPackImage(BuildContext context, ThemeData theme, String cleanUrl) {
    final cached = CardAssetPackService.instance.getFromCache(cleanUrl, word);
    if (cached != null) {
      return Image.memory(
        cached,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => _buildFallback(context, theme),
      );
    }
    return FutureBuilder<Uint8List?>(
      future: CardAssetPackService.instance.loadCardBytes(cleanUrl, word),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (_, _, _) => _buildFallback(context, theme),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ??
              Container(
                width: width,
                height: height,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
              );
        }
        return _buildFallback(context, theme);
      },
    );
  }

  Widget _buildLocalOrAssetPackFallback(BuildContext context, ThemeData theme, String cleanUrl) {
    if (!kIsWeb && Platform.isAndroid) {
      return _buildAndroidAssetPackImage(context, theme, cleanUrl);
    }

    if (!kIsWeb) {
      final diskFile = resolveLocalDiskFile(cleanUrl, word);
      if (diskFile != null) {
        return Image.file(
          diskFile,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _buildFallback(context, theme),
        );
      }
    }

    if (word != null && word!.trim().isNotEmpty) {
      final safeWord = word!.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
      return Image.asset(
        'assets/cards/$safeWord.jpg',
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) => Image.asset(
          'assets/cards/$safeWord.png',
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (_, _, _) => _buildFallback(context, theme),
        ),
      );
    }

    return errorWidget ?? _buildFallback(context, theme);
  }

  Widget _buildFallback(BuildContext context, ThemeData theme) {
    return Container(
      width: width,
      height: height,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
      padding: const EdgeInsets.all(12),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_outlined,
              size: 36,
              color: theme.colorScheme.primary,
            ),
            if (word != null && word!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                word!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
