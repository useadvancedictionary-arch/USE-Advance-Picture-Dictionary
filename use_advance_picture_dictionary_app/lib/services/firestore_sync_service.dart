import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/picture_word_entry.dart';
import 'picture_database_service.dart';

/// Firestore collection names (shared with USE Advance Dictionary project)
const String kFirestoreDictionaryCollection = 'dictionary_entries';
const String kFirestoreSentencesCollection = 'daily_sentences';
const String kFirestorePictureEntriesCollection = 'picture_entries';
const String kFirestoreAdminsCollection = 'sync_admins';

/// Firestore sync service for USE Advance Picture Dictionary.
/// Reads dictionary_entries and daily_sentences from the shared Firebase project
/// (same Firestore DB as USE Advance Dictionary) and can also sync picture_entries.
class FirestoreSyncService {
  static final FirestoreSyncService instance = FirestoreSyncService._init();
  FirestoreSyncService._init();

  static bool get firebaseReady => Firebase.apps.isNotEmpty;

  /// Ensure the user is signed in (anonymous is fine for reads).
  Future<bool> _ensureSignedIn() async {
    if (FirebaseAuth.instance.currentUser != null) return true;
    try {
      await FirebaseAuth.instance.signInAnonymously();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ─── Dictionary Entries (read-only from shared Firestore) ──────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Pull all dictionary entries from Firestore (shared with USE Advance Dictionary).
  /// Returns a list of maps with word data.
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
  // ─── Picture Entries (read/write for this app) ─────────────────────────
  // ═══════════════════════════════════════════════════════════════════════════

  /// Push a picture entry to Firestore.
  Future<bool> pushPictureEntry(PictureWordEntry entry) async {
    if (!firebaseReady) return false;
    if (!(await _ensureSignedIn())) return false;

    try {
      final docId = entry.word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
      await FirebaseFirestore.instance
          .collection(kFirestorePictureEntriesCollection)
          .doc(docId)
          .set(
            _pictureEntryToFirestoreMap(entry),
            SetOptions(merge: true),
          );
      return true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
  }

  /// Pull picture entries from Firestore.
  Future<List<PictureWordEntry>> pullPictureEntries({
    int? sinceMs,
    int limit = 500,
  }) async {
    if (!firebaseReady) return [];
    if (!(await _ensureSignedIn())) return [];

    final results = <PictureWordEntry>[];
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
        if (data['deleted'] == true) continue;
        results.add(_firestoreDataToPictureEntry(data));
      }
    }

    return results;
  }

  /// Sync picture entries: pull from Firestore and merge into local SQLite.
  Future<int> syncPictureEntriesToLocal() async {
    final entries = await pullPictureEntries();
    if (entries.isEmpty) return 0;

    final db = PictureDatabaseService.instance;
    int count = 0;
    for (final entry in entries) {
      final existing = await db.getEntryByWord(entry.word);
      if (existing == null) {
        await db.insertEntry(entry);
        count++;
      }
    }
    return count;
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
}
