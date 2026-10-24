import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cleanUrl = imageUrl.trim();

    // 1. Local Flutter Asset (e.g. assets/cards/abandon.jpg)
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(
        cleanUrl,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) {
          return _buildFallback(context, theme);
        },
      );
    }

    // 2. Local File System Path (saved on disk)
    if (!kIsWeb && (cleanUrl.startsWith('/') || cleanUrl.contains(':\\') || cleanUrl.startsWith('file://'))) {
      final filePath = cleanUrl.replaceFirst('file://', '');
      final file = File(filePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallback(context, theme);
          },
        );
      }
    }

    // 3. Remote Network URL
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
        errorWidget: (context, url, error) =>
            errorWidget ?? _buildFallback(context, theme),
      );
    }

    // 4. Default fallback
    return _buildFallback(context, theme);
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
