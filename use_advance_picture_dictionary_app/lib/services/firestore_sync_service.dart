import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/picture_word_entry.dart';
import 'cloud_image_service.dart';
import 'picture_database_service.dart';

/// Result object for sync operations.
class SyncResult {
  final bool success;
  final int addedOrUpdated;
  final int deleted;
  final String message;

  const SyncResult({
    required this.success,
    this.addedOrUpdated = 0,
    this.deleted = 0,
    required this.message,
  });
}

/// Firestore collection names (shared with USE Advance Dictionary project)
const String kFirestoreDictionaryCollection = 'dictionary_entries';
const String kFirestoreSentencesCollection = 'daily_sentences';
const String kFirestorePictureEntriesCollection = 'picture_entries';
const String kFirestoreAdminsCollection = 'sync_admins';

/// Firestore sync service for USE Advance Picture Dictionary.
/// Reads dictionary_entries and daily_sentences from the shared Firebase project
/// and syncs picture_entries bidirectionally across all users.
class FirestoreSyncService {
  static final FirestoreSyncService instance = FirestoreSyncService._init();
  FirestoreSyncService._init();

  static bool get firebaseReady => Firebase.apps.isNotEmpty;
  String? lastAuthError;

  /// Ensure the user is signed in (anonymous is fine for reads and writes under open rules).
  Future<bool> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      await FirebaseAuth.instance.signInAnonymously();
      lastAuthError = null;
      return true;
    } catch (e) {
      lastAuthError = e.toString();
      debugPrint('FirestoreSyncService auth error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Sync Metadata Persistence ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  Future<File> _getMetaFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/.picture_dict_sync_meta.json');
  }

  Future<int?> getLastSyncTime() async {
    try {
      final file = await _getMetaFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        return data['lastSyncMs'] as int?;
      }
    } catch (e) {
      debugPrint('Error reading sync metadata: $e');
    }
    return null;
  }

  Future<void> _saveLastSyncTime(int timestampMs) async {
    try {
      final file = await _getMetaFile();
      final data = {
        'lastSyncMs': timestampMs,
        'lastSyncDate': DateTime.fromMillisecondsSinceEpoch(timestampMs).toIso8601String(),
      };
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('Error saving sync metadata: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Dictionary Entries (read-only from shared Firestore) ──────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pull all dictionary entries from Firestore (shared with USE Advance Dictionary).
  Future<List<Map<String, dynamic>>> pullDictionaryEntries({
    int? sinceMs,
    int limit = 500,
  }) async {
    if (!firebaseReady) return [];
    if (!(await _ensureSignedIn())) return [];

    final results = <Map<String, dynamic>>[];
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection(kFirestoreDictionaryCollection);

    if (sinceMs != null && sinceMs > 0) {
      ref = ref.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs),
      );
    }
    ref = ref.orderBy('updatedAt').limit(limit);

    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      var currentQuery = ref;
      if (lastDoc != null) {
        currentQuery = currentQuery.startAfterDocument(lastDoc);
      }

      final snap = await currentQuery.get();
      if (snap.docs.isEmpty) break;
      lastDoc = snap.docs.last;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['deleted'] == true) continue;
        results.add({
          'id': data['id'] ?? int.tryParse(doc.id),
          'word': data['word']?.toString() ?? '',
          'englishMeaning': data['englishMeaning']?.toString() ?? '',
          'sindhiMeaning': data['sindhiMeaning']?.toString() ?? '',
          'urduMeaning': data['urduMeaning']?.toString() ?? '',
          'examples': data['examples']?.toString() ?? '',
          'synonyms': data['synonyms']?.toString() ?? '',
          'antonyms': data['antonyms']?.toString() ?? '',
          'partOfSpeech': data['partOfSpeech']?.toString() ?? '',
        });
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Daily Sentences (read-only from shared Firestore) ─────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pull all daily sentences from Firestore (shared with USE Advance Dictionary).
  Future<List<Map<String, dynamic>>> pullDailySentences({
    int? sinceMs,
    int limit = 500,
  }) async {
    if (!firebaseReady) return [];
    if (!(await _ensureSignedIn())) return [];

    final results = <Map<String, dynamic>>[];
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection(kFirestoreSentencesCollection);

    if (sinceMs != null && sinceMs > 0) {
      ref = ref.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs),
      );
    }
    ref = ref.orderBy('updatedAt').limit(limit);

    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      var currentQuery = ref;
      if (lastDoc != null) {
        currentQuery = currentQuery.startAfterDocument(lastDoc);
      }

      final snap = await currentQuery.get();
      if (snap.docs.isEmpty) break;
      lastDoc = snap.docs.last;

      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['deleted'] == true) continue;
        results.add({
          'id': data['id'] ?? int.tryParse(doc.id),
          'sentence': data['sentence']?.toString() ?? '',
          'english': data['english']?.toString() ?? '',
          'sindhi': data['sindhi']?.toString() ?? '',
          'urdu': data['urdu']?.toString() ?? '',
        });
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Picture Entries (read/write for all users) ────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Format document ID uniformly for words in Firestore.
  static String documentIdForWord(String word) {
    return word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Push a single picture entry to Firestore.
  Future<bool> pushPictureEntry(PictureWordEntry entry) async {
    if (!firebaseReady) return false;
    if (!(await _ensureSignedIn())) return false;

    try {
      final docId = documentIdForWord(entry.word);
      await FirebaseFirestore.instance
          .collection(kFirestorePictureEntriesCollection)
          .doc(docId)
          .set(
            _pictureEntryToFirestoreMap(entry),
            SetOptions(merge: true),
          );
      debugPrint('FirestoreSyncService: Pushed "${entry.word}" to Firestore');
      return true;
    } on FirebaseException catch (e) {
      debugPrint('FirestoreSyncService push error: $e');
      if (e.code == 'permission-denied') return false;
      rethrow;
    } catch (e) {
      debugPrint('FirestoreSyncService push error: $e');
      return false;
    }
  }

  /// Delete a picture entry in Firestore (marks deleted: true so all clients remove it).
  Future<bool> deletePictureEntry(String word) async {
    if (!firebaseReady) return false;
    if (!(await _ensureSignedIn())) return false;

    try {
      final docId = documentIdForWord(word);
      await FirebaseFirestore.instance
          .collection(kFirestorePictureEntriesCollection)
          .doc(docId)
          .set({
        'word': word,
        'deleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FirestoreSyncService: Marked "$word" as deleted in Firestore');
      return true;
    } catch (e) {
      debugPrint('FirestoreSyncService delete error: $e');
      return false;
    }
  }

  /// Push a batch of picture entries in transactions of 400 items.
  Future<int> pushBatchPictureEntries(List<PictureWordEntry> entries) async {
    if (!firebaseReady || entries.isEmpty) return 0;
    if (!(await _ensureSignedIn())) return 0;

    int totalPushed = 0;
    const chunkSize = 400;
    for (int i = 0; i < entries.length; i += chunkSize) {
      final chunk = entries.sublist(
        i,
        (i + chunkSize > entries.length) ? entries.length : i + chunkSize,
      );
      final batch = FirebaseFirestore.instance.batch();
      for (final entry in chunk) {
        final docId = documentIdForWord(entry.word);
        final docRef = FirebaseFirestore.instance
            .collection(kFirestorePictureEntriesCollection)
            .doc(docId);
        batch.set(docRef, _pictureEntryToFirestoreMap(entry), SetOptions(merge: true));
      }
      await batch.commit();
      totalPushed += chunk.length;
      debugPrint('FirestoreSyncService: Batch committed $totalPushed/${entries.length} entries');
    }
    return totalPushed;
  }

  /// Pull picture entries from Firestore.
  Future<List<Map<String, dynamic>>> pullRawPictureDocuments({
    int? sinceMs,
    int limit = 500,
  }) async {
    if (!firebaseReady) return [];
    if (!(await _ensureSignedIn())) return [];

    final results = <Map<String, dynamic>>[];
    Query<Map<String, dynamic>> ref = FirebaseFirestore.instance
        .collection(kFirestorePictureEntriesCollection);

    if (sinceMs != null && sinceMs > 0) {
      ref = ref.where(
        'updatedAt',
        isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(sinceMs),
      );
    }
    ref = ref.orderBy('updatedAt').limit(limit);

    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      var currentQuery = ref;
      if (lastDoc != null) {
        currentQuery = currentQuery.startAfterDocument(lastDoc);
      }

      final snap = await currentQuery.get();
      if (snap.docs.isEmpty) break;
      lastDoc = snap.docs.last;

      for (final doc in snap.docs) {
        final data = doc.data();
        results.add(data);
      }
    }

    return results;
  }

  /// Sync picture entries from Firestore into the local SQLite database.
  /// Handles both additions/updates and deletions, propagating admin edits to all users.
  Future<SyncResult> syncPictureEntriesToLocal({bool forceFullSync = false}) async {
    if (!firebaseReady) {
      return const SyncResult(success: false, message: 'Firebase is not initialized.');
    }
    
    // Attempt authentication, but proceed to test connection if Firestore has open read rules
    final signedIn = await _ensureSignedIn();
    if (!signedIn) {
      debugPrint('FirestoreSyncService: Auth did not succeed ($lastAuthError). Trying Firestore directly...');
    }

    try {
      final lastSyncMs = forceFullSync ? null : await getLastSyncTime();
      final startTimestamp = DateTime.now().millisecondsSinceEpoch;

      final docs = await pullRawPictureDocuments(sinceMs: lastSyncMs);
      if (docs.isEmpty) {
        await _saveLastSyncTime(startTimestamp);
        return const SyncResult(
          success: true,
          addedOrUpdated: 0,
          deleted: 0,
          message: 'Already up to date with cloud.',
        );
      }

      final db = PictureDatabaseService.instance;
      int addedOrUpdated = 0;
      int deletedCount = 0;

      for (final data in docs) {
        final word = data['word']?.toString() ?? '';
        if (word.trim().isEmpty) continue;

        final isDeleted = data['deleted'] == true;
        if (isDeleted) {
          await db.deleteEntryByWord(word);
          deletedCount++;
        } else {
          final entry = _firestoreDataToPictureEntry(data);
          await db.insertOrUpdateEntry(entry);
          addedOrUpdated++;
        }
      }

      await _saveLastSyncTime(startTimestamp);
      debugPrint('FirestoreSyncService: Sync finished (updated: $addedOrUpdated, deleted: $deletedCount)');

      return SyncResult(
        success: true,
        addedOrUpdated: addedOrUpdated,
        deleted: deletedCount,
        message: 'Sync completed: $addedOrUpdated updated, $deletedCount deleted.',
      );
    } catch (e) {
      debugPrint('FirestoreSyncService sync error: $e');
      final detail = lastAuthError != null ? '$e [Auth: $lastAuthError]' : '$e';
      return SyncResult(
        success: false,
        message: 'Sync failed: $detail',
      );
    }
  }

  Map<String, dynamic> _pictureEntryToFirestoreMap(PictureWordEntry entry) {
    return {
      'word': entry.word,
      'part_of_speech': entry.partOfSpeech,
      'english_meaning': entry.englishMeaning,
      'synonyms': jsonEncode(entry.synonyms),
      'antonyms': jsonEncode(entry.antonyms),
      'image_url': entry.imageUrl,
      'thumbnail_url': entry.thumbnailUrl ?? '',
      'category': entry.category,
      'example_sentence': entry.exampleSentence ?? '',
      'deleted': false,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  PictureWordEntry _firestoreDataToPictureEntry(Map<String, dynamic> data) {
    List<String> parseList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      try {
        final decoded = jsonDecode(value.toString());
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return value.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return PictureWordEntry(
      word: data['word']?.toString() ?? '',
      partOfSpeech: data['part_of_speech']?.toString() ?? 'noun',
      englishMeaning: data['english_meaning']?.toString() ?? '',
      synonyms: parseList(data['synonyms']),
      antonyms: parseList(data['antonyms']),
      imageUrl: data['image_url']?.toString() ?? '',
      thumbnailUrl: data['thumbnail_url']?.toString(),
      category: data['category']?.toString() ?? 'General',
      exampleSentence: data['example_sentence']?.toString(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Upload Pending Local Images ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Scans ALL entries in the local SQLite database that still have a local
  /// file-system path as their imageUrl (i.e. starts with a drive letter like
  /// C:\ or /Users/...) instead of a cloud https:// URL.
  ///
  /// For every such entry it:
  ///   1. Uploads the image file to Firebase Cloud Storage.
  ///   2. Replaces the local path with the returned cloud https:// URL in SQLite.
  ///   3. Pushes the updated entry to Firestore so ALL devices receive the cloud URL.
  ///
  /// Returns a [SyncResult] describing how many were fixed vs failed.
  Future<SyncResult> uploadPendingLocalImages({
    void Function(int done, int total, String word)? onProgress,
  }) async {
    if (!firebaseReady) {
      return const SyncResult(
        success: false,
        message: 'Firebase is not ready. Check internet connection.',
      );
    }

    if (!(await _ensureSignedIn())) {
      return SyncResult(
        success: false,
        message: 'Could not authenticate with Firebase${lastAuthError != null ? ': $lastAuthError' : '.'}',
      );
    }

    final db = PictureDatabaseService.instance;
    final allEntries = await db.getAllEntries();

    // Filter entries whose imageUrl is a local path (not http/https/assets)
    final pendingEntries = allEntries.where((e) {
      final url = (e.imageUrl).trim();
      if (url.isEmpty) return false;
      if (url.startsWith('http://') || url.startsWith('https://')) return false;
      if (url.startsWith('assets/')) return false;
      // Windows absolute path: C:\..., D:\...
      if (RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(url)) return true;
      // Unix-style absolute path
      if (url.startsWith('/')) return true;
      return false;
    }).toList();

    if (pendingEntries.isEmpty) {
      return const SyncResult(
        success: true,
        addedOrUpdated: 0,
        message: 'No pending images found – all pictures are already on the cloud ✓',
      );
    }

    int uploaded = 0;
    int failed = 0;
    final failedWords = <String>[];

    for (int i = 0; i < pendingEntries.length; i++) {
      final entry = pendingEntries[i];
      onProgress?.call(i + 1, pendingEntries.length, entry.word);

      final localFile = File(entry.imageUrl.trim());
      if (!await localFile.exists()) {
        debugPrint('uploadPendingLocalImages: file not found for "${entry.word}": ${entry.imageUrl}');
        failed++;
        failedWords.add(entry.word);
        continue;
      }

      try {
        final cloudUrl = await CloudImageService.instance.uploadLocalFile(
          localFile,
          word: entry.word,
        );

        if (cloudUrl != null && cloudUrl.isNotEmpty) {
          final updatedEntry = entry.copyWith(
            imageUrl: cloudUrl,
            thumbnailUrl: cloudUrl,
          );
          // 1. Update local SQLite
          await db.insertOrUpdateEntry(updatedEntry);
          // 2. Push to Firestore
          await pushPictureEntry(updatedEntry);
          uploaded++;
          debugPrint('uploadPendingLocalImages [$uploaded/${pendingEntries.length}]: "${entry.word}" -> $cloudUrl');
        } else {
          failed++;
          failedWords.add(entry.word);
          debugPrint('uploadPendingLocalImages: upload returned null for "${entry.word}"');
        }
      } catch (e) {
        failed++;
        failedWords.add(entry.word);
        debugPrint('uploadPendingLocalImages error for "${entry.word}": $e');
      }
    }

    final total = pendingEntries.length;
    if (failed == 0) {
      return SyncResult(
        success: true,
        addedOrUpdated: uploaded,
        message: 'All $uploaded pending image(s) uploaded to cloud and synced to all devices ✓',
      );
    } else {
      final failList = failedWords.take(5).join(', ');
      final more = failedWords.length > 5 ? ' …and ${failedWords.length - 5} more' : '';
      return SyncResult(
        success: uploaded > 0,
        addedOrUpdated: uploaded,
        message: 'Uploaded $uploaded of $total. $failed failed (file missing?): $failList$more',
      );
    }
  }
}
