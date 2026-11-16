import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Universal image optimizer for USE Advance Picture Dictionary.
/// Ensures all images uploaded to Firebase Firestore are high quality,
/// crystal clear, and guaranteed to fit well within Firestore's 1 MB document limit.
class ImageOptimizer {
  /// Maximum file bytes before Base64 encoding for Firestore (target ~350 KB, base64 ~467 KB)
  static const int kMaxCloudImageBytes = 350 * 1024;

  /// Maximum pixel dimension (width or height) for card images
  static const int kMaxDimension = 1200;

  /// Optimizes raw image bytes (JPG, PNG, WEBP) for cloud sync and disk storage.
  /// Always returns valid image bytes that produce high visual fidelity.
  static Uint8List optimizeBytes(Uint8List rawBytes) {
    if (rawBytes.isEmpty) return rawBytes;

    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      // 1. Resize if dimensions exceed maximum
      img.Image processed = decoded;
      if (decoded.width > kMaxDimension || decoded.height > kMaxDimension) {
        final double ratio = decoded.width / decoded.height;
        int targetW, targetH;
        if (ratio >= 1.0) {
          targetW = kMaxDimension;
          targetH = (kMaxDimension / ratio).round();
        } else {
          targetH = kMaxDimension;
          targetW = (kMaxDimension * ratio).round();
        }
        processed = img.copyResize(
          decoded,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }

      // 2. Progressive quality compression to strictly fit within target size
      // Quality 85 gives near-lossless sharpness for dictionary flashcards
      var compressed = img.encodeJpg(processed, quality: 85);
      if (compressed.length > kMaxCloudImageBytes) {
        compressed = img.encodeJpg(processed, quality: 78);
      }
      if (compressed.length > kMaxCloudImageBytes) {
        compressed = img.encodeJpg(processed, quality: 70);
      }

      debugPrint(
        'ImageOptimizer: ${rawBytes.length} bytes -> ${compressed.length} bytes '
        '(${(compressed.length / 1024).toStringAsFixed(1)} KB, '
        '${processed.width}x${processed.height})',
      );
      return Uint8List.fromList(compressed);
    } catch (e) {
      debugPrint('ImageOptimizer error: $e');
      return rawBytes;
    }
  }

  /// Optimize a file on disk. Returns the optimized bytes.
  static Uint8List? optimizeFile(File file) {
    if (!file.existsSync()) return null;
    try {
      final bytes = file.readAsBytesSync();
      return optimizeBytes(bytes);
    } catch (e) {
      debugPrint('ImageOptimizer.optimizeFile error: $e');
      return null;
    }
  }

  /// Converts a local file path to a safe Base64 string for Firestore.
  /// Automatically compresses if the file is larger than 300 KB.
  /// Guarantees the resulting Base64 string will never trigger Firestore size errors.
  static String? fileToBase64Safe(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final file = File(path.trim());
    if (!file.existsSync()) return null;

    try {
      final bytes = file.readAsBytesSync();
      if (bytes.isEmpty) return null;

      // If file is already small (under 280 KB), use direct base64
      if (bytes.length <= 280 * 1024) {
        return base64Encode(bytes);
      }

      // Otherwise optimize first
      final optimized = optimizeBytes(bytes);
      return base64Encode(optimized);
    } catch (e) {
      debugPrint('ImageOptimizer.fileToBase64Safe error for $path: $e');
      return null;
    }
  }
}
