import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Service to handle uploading and managing picture dictionary images in Firebase Cloud Storage.
/// Provides resilient upload with automatic fallback to Firebase Storage REST API.
class CloudImageService {
  static final CloudImageService instance = CloudImageService._();
  CloudImageService._();

  static const String storageBucket = 'use-advance-picture-dict-1861e.firebasestorage.app';

  /// Sanitize word string for use in cloud storage file paths.
  String _sanitizeWord(String word) {
    return word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
  }

  /// Ensure Firebase user is signed in (anonymous authentication) before uploading.
  Future<bool> _ensureSignedIn() async {
    if (!Firebase.apps.isNotEmpty) return false;
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      await FirebaseAuth.instance.signInAnonymously();
      return true;
    } catch (e) {
      debugPrint('CloudImageService anonymous sign-in error: $e');
      return false;
    }
  }

  /// Upload raw image bytes to Firebase Cloud Storage.
  /// Returns the permanent public download URL, or null if upload failed.
  Future<String?> uploadImageBytes(
    Uint8List bytes, {
    required String word,
    String format = 'jpg',
  }) async {
    final sanitized = _sanitizeWord(word);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = format.toLowerCase().replaceAll('.', '');
    final fileName = '${sanitized}_$timestamp.$ext';
    final storagePath = 'picture_cards/$fileName';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

    // 1. Try standard FlutterFire FirebaseStorage
    try {
      await _ensureSignedIn();
      final storageRef = FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: storageBucket,
      ).ref().child(storagePath);

      final metadata = SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'word': word,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await storageRef.putData(bytes, metadata);
      if (uploadTask.state == TaskState.success) {
        final downloadUrl = await storageRef.getDownloadURL();
        debugPrint('CloudImageService: Uploaded via FirebaseStorage -> $downloadUrl');
        return downloadUrl;
      }
    } catch (e) {
      debugPrint('CloudImageService: FirebaseStorage upload error: $e. Falling back to REST API...');
    }

    // 2. Fallback to Firebase Storage HTTP REST API
    try {
      return await _uploadViaRest(
        bytes: bytes,
        storagePath: storagePath,
        contentType: contentType,
      );
    } catch (e) {
      debugPrint('CloudImageService: REST upload error: $e');
      return null;
    }
  }

  /// Direct HTTP REST upload to Google Cloud / Firebase Storage
  Future<String?> _uploadViaRest({
    required Uint8List bytes,
    required String storagePath,
    required String contentType,
  }) async {
    final encodedPath = Uri.encodeComponent(storagePath);
    final uri = Uri.parse(
      'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o?uploadType=media&name=$encodedPath',
    );

    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', contentType);

      // Add auth token if signed in
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        if (token != null && token.isNotEmpty) {
          request.headers.set('Authorization', 'Firebase $token');
        }
      } catch (_) {}

      request.add(bytes);
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        final token = data['downloadTokens']?.toString() ?? '';
        final name = data['name']?.toString() ?? storagePath;
        final downloadUrl = 'https://firebasestorage.googleapis.com/v0/b/$storageBucket/o/${Uri.encodeComponent(name)}?alt=media${token.isNotEmpty ? '&token=$token' : ''}';
        debugPrint('CloudImageService: REST upload success -> $downloadUrl');
        return downloadUrl;
      } else {
        debugPrint('CloudImageService: REST upload returned status ${response.statusCode}: $body');
        return null;
      }
    } finally {
      client.close();
    }
  }

  /// Upload a local image file to Firebase Storage.
  Future<String?> uploadLocalFile(File file, {required String word}) async {
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    final format = file.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    return await uploadImageBytes(bytes, word: word, format: format);
  }

  /// Download an ephemeral network image (e.g. AI-generated preview) and upload
  /// it to Firebase Storage so it becomes a permanent official asset.
  Future<String?> uploadNetworkImage(String imageUrl, {required String word}) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(imageUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        client.close();
        return null;
      }

      final bytesBuilder = BytesBuilder();
      await for (final chunk in response) {
        bytesBuilder.add(chunk);
      }
      client.close();

      final bytes = bytesBuilder.toBytes();
      if (bytes.isEmpty) return null;

      final format = imageUrl.toLowerCase().contains('.png') ? 'png' : 'jpg';
      return await uploadImageBytes(bytes, word: word, format: format);
    } catch (e) {
      debugPrint('CloudImageService: Failed to download & upload network image: $e');
      return null;
    }
  }
}
