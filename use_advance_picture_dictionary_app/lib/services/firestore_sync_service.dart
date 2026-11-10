import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/picture_word_entry.dart';
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
  static const String _kFirestoreProjectId = 'use-advance-picture-dict-1861e';

  /// Ensure the user is signed in (anonymous is fine for reads and writes under open rules).
  /// On Windows, bypasses Firebase Auth since FlutterFire lacks a Windows auth plugin
  /// and Firestore rules allow open access. Never blocks or hangs.
  Future<bool> _ensureSignedIn() async {
    if (Platform.isWindows) return true;
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      await FirebaseAuth.instance.signInAnonymously().timeout(const Duration(seconds: 4));
      lastAuthError = null;
      return true;
    } catch (e) {
      lastAuthError = e.toString();
      debugPrint('FirestoreSyncService auth error: $e');
      return true; // Still allow sync because Firestore has open rules
    }
  }

  /// Convert a local raw Map to Firestore REST API JSON format.
  Map<String, dynamic> _toFirestoreRestPayload(Map<String, dynamic> map) {
    final fields = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) {
        fields[key] = {'nullValue': null};
      } else if (value is bool) {
        fields[key] = {'booleanValue': value};
      } else if (value is int) {
        fields[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        fields[key] = {'doubleValue': value};
      } else if (value is String) {
        fields[key] = {'stringValue': value};
      } else if (value is List) {
        fields[key] = {
          'arrayValue': {
            'values': value.map((v) => {'stringValue': v.toString()}).toList(),
          }
        };
      }
    });
    fields['updatedAt'] = {'timestampValue': DateTime.now().toUtc().toIso8601String()};
    return {'fields': fields};
  }

  /// Push a document to Firestore using the standard HTTP REST API.
  /// Works universally on all platforms including Windows without native plugins.
  Future<bool> _pushToFirestoreRest(String docId, Map<String, dynamic> data) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final url = 'https://firestore.googleapis.com/v1/projects/$_kFirestoreProjectId/databases/(default)/documents/$kFirestorePictureEntriesCollection/$docId';
      final req = await client.patchUrl(Uri.parse(url)).timeout(const Duration(seconds: 8));
      req.headers.set('Content-Type', 'application/json');
      final payload = _toFirestoreRestPayload(data);
      req.add(utf8.encode(jsonEncode(payload)));
      final res = await req.close().timeout(const Duration(seconds: 10));
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('_pushToFirestoreRest error for $docId: $e');
      return false;
    } finally {
      client.close();
    }
  }

  /// Reads local image file into base64 string if it exists on disk.
  String? _getLocalImageBase64(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    try {
      final file = File(path.trim());
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        if (bytes.isNotEmpty) {
          return base64Encode(bytes);
        }
      }
    } catch (e) {
      debugPrint('Error reading image bytes from $path: $e');
    }
    return null;
  }

  /// Saves a base64 image string to the device's local app storage directory.
  /// Returns the saved File, or null if decoding fails.
  Future<File?> _saveBase64ImageLocally(String word, String base64Str) async {
    try {
      final bytes = base64Decode(base64Str);
      if (bytes.isEmpty) return null;
      final appDir = await getApplicationDocumentsDirectory();
      final cardsDir = Directory('${appDir.path}/cards');
      if (!await cardsDir.exists()) {
        await cardsDir.create(recursive: true);
      }
      final sanitized = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      final file = File('${cardsDir.path}/${sanitized}_card.png');
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Error saving base64 image locally for $word: $e');
      return null;
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
  /// Automatically embeds image bytes as Base64 when the entry points to a local file,
  /// guaranteeing cloud sync to all devices without requiring Firebase Cloud Storage or a Blaze plan.
  Future<bool> pushPictureEntry(PictureWordEntry entry, {String? imageBase64}) async {
    final docId = documentIdForWord(entry.word);
    final b64 = imageBase64 ?? _getLocalImageBase64(entry.imageUrl);
    final map = _pictureEntryToFirestoreMap(entry, imageBase64: b64);

    if (Platform.isWindows) {
      return await _pushToFirestoreRest(docId, map);
    }

    try {
      await FirebaseFirestore.instance
          .collection(kFirestorePictureEntriesCollection)
          .doc(docId)
          .set(map, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
      debugPrint('FirestoreSyncService: Pushed "${entry.word}" to Firestore via SDK');
      return true;
    } catch (e) {
      debugPrint('FirestoreSyncService SDK push failed ($e), falling back to REST...');
      return await _pushToFirestoreRest(docId, map);
    }
  }

  /// Delete a picture entry in Firestore (marks deleted: true so all clients remove it).
  Future<bool> deletePictureEntry(String word) async {
    final docId = documentIdForWord(word);
    final map = {
      'word': word,
      'deleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (Platform.isWindows) {
      return await _pushToFirestoreRest(docId, {
        'word': word,
        'deleted': true,
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection(kFirestorePictureEntriesCollection)
          .doc(docId)
          .set(map, SetOptions(merge: true))
          .timeout(const Duration(seconds: 5));
      debugPrint('FirestoreSyncService: Marked "$word" as deleted in Firestore');
      return true;
    } catch (e) {
      return await _pushToFirestoreRest(docId, {
        'word': word,
        'deleted': true,
      });
    }
  }

  /// Push a batch of picture entries to Firestore.
  Future<int> pushBatchPictureEntries(List<PictureWordEntry> entries) async {
    if (entries.isEmpty) return 0;

    int totalPushed = 0;
    for (final entry in entries) {
      final ok = await pushPictureEntry(entry);
      if (ok) totalPushed++;
    }
    debugPrint('FirestoreSyncService: Batch pushed $totalPushed/${entries.length} entries');
    return totalPushed;
  }

  /// Pull picture entries from Firestore.
  Future<List<Map<String, dynamic>>> pullRawPictureDocuments({
    int? sinceMs,
    int limit = 500,
  }) async {
    final results = <Map<String, dynamic>>[];

    try {
      if (Platform.isWindows) {
        // Direct REST query on Windows
        final client = HttpClient();
        try {
          final url = 'https://firestore.googleapis.com/v1/projects/$_kFirestoreProjectId/databases/(default)/documents/$kFirestorePictureEntriesCollection?pageSize=$limit';
          final req = await client.getUrl(Uri.parse(url));
          final res = await req.close();
          if (res.statusCode == 200) {
            final body = await res.transform(utf8.decoder).join();
            final json = jsonDecode(body) as Map<String, dynamic>;
            final docs = json['documents'] as List? ?? [];
            for (final doc in docs) {
              final parsed = _fromFirestoreRestDoc(doc as Map<String, dynamic>);
              results.add(parsed);
            }
          }
        } finally {
          client.close();
        }
        return results;
      }

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
    } catch (e) {
      debugPrint('pullRawPictureDocuments error: $e');
    }

    return results;
  }

  /// Parse a Firestore REST document into a flat `Map<String, dynamic>`.
  Map<String, dynamic> _fromFirestoreRestDoc(Map<String, dynamic> doc) {
    final out = <String, dynamic>{};
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    fields.forEach((k, v) {
      if (v is Map) {
        if (v.containsKey('stringValue')) {
          out[k] = v['stringValue'];
        } else if (v.containsKey('booleanValue')) {
          out[k] = v['booleanValue'];
        } else if (v.containsKey('integerValue')) {
          out[k] = int.tryParse(v['integerValue'].toString()) ?? 0;
        } else if (v.containsKey('doubleValue')) {
          out[k] = v['doubleValue'];
        } else if (v.containsKey('timestampValue')) {
          out[k] = v['timestampValue'];
        } else if (v.containsKey('arrayValue')) {
          final arr = v['arrayValue']['values'] as List? ?? [];
          out[k] = arr.map((item) => (item as Map)['stringValue'] ?? '').toList();
        }
      }
    });
    return out;
  }

  /// Sync picture entries from Firestore into the local SQLite database.
  /// Handles both additions/updates and deletions, saving base64 images locally on device.
  Future<SyncResult> syncPictureEntriesToLocal({bool forceFullSync = false}) async {
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
          // If Firestore contains embedded image Base64, save it to local app storage
          final b64 = data['image_base64']?.toString();
          if (b64 != null && b64.isNotEmpty) {
            final localCard = await _saveBase64ImageLocally(word, b64);
            if (localCard != null) {
              data['image_url'] = localCard.path;
              data['thumbnail_url'] = localCard.path;
            }
          }

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
      return SyncResult(
        success: false,
        message: 'Sync failed: $e',
      );
    }
  }

  Map<String, dynamic> _pictureEntryToFirestoreMap(
    PictureWordEntry entry, {
    String? imageBase64,
  }) {
    final b64 = imageBase64 ?? _getLocalImageBase64(entry.imageUrl);
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
      'image_base64': b64 ?? '',
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
  /// file-system path as their imageUrl (e.g. C:\... or /...).
  ///
  /// For every such entry it:
  ///   1. Reads the local image bytes and encodes to Base64.
  ///   2. Pushes the entry and embedded image directly to Cloud Firestore.
  ///   3. Syncs to ALL devices (Android, etc.) without requiring Firebase Cloud Storage!
  ///
  /// Returns a [SyncResult] describing how many were uploaded vs failed.
  Future<SyncResult> uploadPendingLocalImages({
    void Function(int done, int total, String word)? onProgress,
  }) async {
    final db = PictureDatabaseService.instance;
    final allEntries = await db.getAllEntries();

    // Filter entries whose imageUrl is a local path (starts with drive letter or /)
    final pendingEntries = allEntries.where((e) {
      final url = (e.imageUrl).trim();
      if (url.isEmpty) return false;
      if (url.startsWith('http://') || url.startsWith('https://')) return false;
      if (url.startsWith('assets/')) return false;
      if (RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(url)) return true;
      if (url.startsWith('/')) return true;
      return false;
    }).toList();

    if (pendingEntries.isEmpty) {
      return const SyncResult(
        success: true,
        addedOrUpdated: 0,
        message: 'No pending local images found – all pictures are already in sync ✓',
      );
    }

    int uploaded = 0;
    int failed = 0;
    final failedWords = <String>[];

    // Known backup folder on Windows where cropped cards are saved
    final fallbackDir = Directory(r'C:\Users\Dell\Documents\USE_Advance_Picture_Dictionary\custom_cards');

    for (int i = 0; i < pendingEntries.length; i++) {
      final entry = pendingEntries[i];
      onProgress?.call(i + 1, pendingEntries.length, entry.word);

      File localFile = File(entry.imageUrl.trim());
      if (!localFile.existsSync()) {
        final sanitized = entry.word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
        final candidate = File('${fallbackDir.path}/${sanitized}_card.png');
        if (candidate.existsSync()) {
          localFile = candidate;
        } else {
          try {
            final matches = fallbackDir.listSync().whereType<File>().where((f) {
              final name = f.uri.pathSegments.last.toLowerCase();
              return name.startsWith('${sanitized}_card');
            }).toList();
            if (matches.isNotEmpty) {
              matches.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
              localFile = matches.first;
            }
          } catch (_) {}
        }
      }

      if (!localFile.existsSync()) {
        debugPrint('uploadPendingLocalImages: file not found for "${entry.word}": ${entry.imageUrl}');
        failed++;
        failedWords.add(entry.word);
        continue;
      }

      try {
        final bytes = await localFile.readAsBytes();
        final b64 = base64Encode(bytes);
        final ok = await pushPictureEntry(entry, imageBase64: b64);

        if (ok) {
          uploaded++;
          debugPrint('uploadPendingLocalImages [$uploaded/${pendingEntries.length}]: "${entry.word}" uploaded to Firestore ✓');
        } else {
          failed++;
          failedWords.add(entry.word);
          debugPrint('uploadPendingLocalImages: push failed for "${entry.word}"');
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
        message: 'All $uploaded pictures successfully uploaded to cloud & synced to all devices! ✓',
      );
    } else {
      final failList = failedWords.take(5).join(', ');
      final more = failedWords.length > 5 ? ' …and ${failedWords.length - 5} more' : '';
      return SyncResult(
        success: uploaded > 0,
        addedOrUpdated: uploaded,
        message: 'Uploaded $uploaded of $total to cloud. ($failed failed: $failList$more)',
      );
    }
  }
}
