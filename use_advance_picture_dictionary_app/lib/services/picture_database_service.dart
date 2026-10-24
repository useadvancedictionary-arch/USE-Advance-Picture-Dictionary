import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import '../models/picture_word_entry.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'smart_auto_tagger.dart';
import 'bundled_cards_data.dart';

class PictureDatabaseService {
  static final PictureDatabaseService instance = PictureDatabaseService._init();
  static Database? _database;

  PictureDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('use_advance_picture_dictionary.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createDB(db, version);
        await _seedFullDictionary(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _seedFullDictionary(db);
      },
    );

    // Ensure all 15,916 dictionary entries are populated
    try {
      final countRes = await db.rawQuery('SELECT COUNT(*) FROM picture_entries');
      final count = (countRes.isNotEmpty && countRes.first.values.isNotEmpty)
          ? ((countRes.first.values.first as num?)?.toInt() ?? 0)
          : 0;
      if (count < 1000) {
        await _seedFullDictionary(db);
      }
    } catch (e) {
      debugPrint('DB entry check error: $e');
    }

    return db;
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE picture_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL UNIQUE,
        part_of_speech TEXT NOT NULL,
        english_meaning TEXT NOT NULL,
        synonyms TEXT,
        antonyms TEXT,
        image_url TEXT NOT NULL,
        thumbnail_url TEXT,
        category TEXT NOT NULL,
        example_sentence TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_pic_word ON picture_entries(word)');
    await db.execute('CREATE INDEX idx_pic_cat ON picture_entries(category)');

    // Seed initial starter entries
    final starterEntries = _getInitialStarterEntries();
    for (final entry in starterEntries) {
      await db.insert(
        'picture_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  
  Future<int> insertEntry(PictureWordEntry entry) async {
    final db = await database;
    return await db.insert(
      'picture_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> deleteEntry(int id) async {
    final db = await database;
    return await db.delete('picture_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PictureWordEntry>> getAllEntries() async {
    final db = await database;
    final maps = await db.query('picture_entries', orderBy: 'word ASC');
    return maps.map((m) => PictureWordEntry.fromMap(m)).toList();
  }

  Future<List<PictureWordEntry>> searchEntries(String query) async {
    final db = await database;
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return getAllEntries();

    final maps = await db.rawQuery(
      '''
      SELECT * FROM picture_entries
      WHERE LOWER(word) LIKE ? OR LOWER(category) LIKE ? OR LOWER(english_meaning) LIKE ? OR LOWER(synonyms) LIKE ?
      ORDER BY
        CASE
          WHEN LOWER(word) = ? THEN 0
          WHEN LOWER(word) LIKE ? || '%' THEN 1
          ELSE 2
        END,
        word ASC
      LIMIT 100
      ''',
      ['%$trimmed%', '%$trimmed%', '%$trimmed%', '%$trimmed%', trimmed, trimmed],
    );
    final results = maps.map((m) => PictureWordEntry.fromMap(m)).toList();

    // If no direct local matches, check if query matches dictionary
    if (results.isEmpty) {
      // 1. Try exact word match
      final exactEntry = await fetchOrGenerateEntry(trimmed);
      if (exactEntry != null) {
        return [exactEntry];
      }

      // 2. Check for prefix matches in dictionary cache
      await _ensureDictionaryLoaded();
      if (_dictionaryMap != null) {
        int count = 0;
        for (final item in _dictionaryMap!.values) {
          final w = (item['word'] ?? '').toString();
          if (w.toLowerCase().startsWith(trimmed) || w.toLowerCase().contains(trimmed)) {
            final gen = await fetchOrGenerateEntry(w);
            if (gen != null) {
              results.add(gen);
              count++;
              if (count >= 12) break;
            }
          }
        }
      }
    }

    return results;
  }

  Future<List<PictureWordEntry>> getEntriesByCategory(String category) async {
    final db = await database;
    final maps = await db.query(
      'picture_entries',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'word ASC',
    );
    return maps.map((m) => PictureWordEntry.fromMap(m)).toList();
  }

  Future<PictureWordEntry?> getEntryByWord(String word) async {
    final db = await database;
    final maps = await db.query(
      'picture_entries',
      where: 'LOWER(word) = ?',
      whereArgs: [word.trim().toLowerCase()],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return PictureWordEntry.fromMap(maps.first);
    }
    return null;
  }

  
  static Map<String, Map<String, dynamic>>? _dictionaryMap;
  static bool _isLoadingDict = false;

  Future<void> _ensureDictionaryLoaded() async {
    if (_dictionaryMap != null) return;
    if (_isLoadingDict) {
      while (_isLoadingDict) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }
    _isLoadingDict = true;
    try {
      final jsonString = await rootBundle.loadString('assets/data/dictionary.json');
      final list = jsonDecode(jsonString) as List<dynamic>;
      final map = <String, Map<String, dynamic>>{};
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final w = (item['word'] ?? '').toString().trim().toLowerCase();
          if (w.isNotEmpty) {
            map[w] = item;
          }
        }
      }
      _dictionaryMap = map;
      debugPrint('Loaded ${_dictionaryMap!.length} dictionary entries into memory cache');
    } catch (e) {
      debugPrint('Error loading dictionary.json: $e');
      _dictionaryMap = {};
    } finally {
      _isLoadingDict = false;
    }
  }

  Future<Map<String, dynamic>?> getDictionaryWord(String word) async {
    await _ensureDictionaryLoaded();
    return _dictionaryMap?[word.trim().toLowerCase()];
  }

  /// On-demand fetch/generate picture word entry for words not yet in local DB
  Future<PictureWordEntry?> fetchOrGenerateEntry(String word) async {
    final trimmed = word.trim();
    if (trimmed.isEmpty) return null;

    final existing = await getEntryByWord(trimmed);
    if (existing != null) return existing;

    final dictEntry = await getDictionaryWord(trimmed);
    String pos = 'Noun';
    String meaning = '';
    List<String> synonyms = [];
    List<String> antonyms = [];
    String? example;

    if (dictEntry != null) {
      pos = dictEntry['partOfSpeech']?.toString() ?? 'Noun';
      meaning = dictEntry['englishMeaning']?.toString() ?? '';
      synonyms = _parseWordList(dictEntry['synonyms']?.toString() ?? '');
      antonyms = _parseWordList(dictEntry['antonyms']?.toString() ?? '');
      example = dictEntry['examples']?.toString();
    }

    if (meaning.isEmpty && dictEntry == null) {
      return null;
    }

    final category = SmartAutoTagger.autoClassify(
      word: trimmed,
      meaning: meaning,
      example: example,
      pos: pos,
    );

    final imageUrl = await SmartAutoTagger.resolveImageAsync(
      trimmed,
      category: category,
      meaning: meaning,
      pos: pos,
    );

    final entry = PictureWordEntry(
      word: dictEntry?['word']?.toString() ?? trimmed,
      partOfSpeech: pos,
      englishMeaning: meaning,
      synonyms: synonyms,
      antonyms: antonyms,
      imageUrl: imageUrl,
      thumbnailUrl: imageUrl,
      category: category,
      exampleSentence: example,
    );

    await insertEntry(entry);
    return entry;
  }

  Future<List<String>> getAllCategories() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT category FROM picture_entries ORDER BY category ASC');
    return result.map((r) => r['category'] as String).toList();
  }

  /// RFC-4180 robust CSV parser handling multi-line strings, embedded quotes, and commas
  List<List<String>> parseCsvRows(String input) {
    final rows = <List<String>>[];
    final currentField = StringBuffer();
    final currentRow = <String>[];
    bool inQuotes = false;

    for (int i = 0; i < input.length; i++) {
      final char = input[i];

      if (char == '"') {
        if (inQuotes && i + 1 < input.length && input[i + 1] == '"') {
          currentField.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(currentField.toString().trim());
        currentField.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
          i++;
        }
        currentRow.add(currentField.toString().trim());
        currentField.clear();
        if (currentRow.any((c) => c.isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
      } else {
        currentField.write(char);
      }
    }

    if (currentField.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentField.toString().trim());
      if (currentRow.any((c) => c.isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
    }

    return rows;
  }

  static int _columnLettersToIndex(String letters) {
    var index = 0;
    for (final code in letters.codeUnits) {
      index = index * 26 + (code - 64);
    }
    return index - 1;
  }

  static List<String> _readSharedStrings(ArchiveFile? file) {
    if (file == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
    return doc.findAllElements('si').map((si) {
      final texts = si.findAllElements('t').map((t) => t.innerText);
      return texts.join();
    }).toList();
  }

  /// Parses native Excel (.xlsx) bytes into a 2D table of strings
  static List<List<String>> readXlsxSheetRows(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? findFile(String suffix) {
      for (final f in archive.files) {
        if (f.name.endsWith(suffix)) return f;
      }
      return null;
    }

    final sharedStrings = _readSharedStrings(findFile('sharedStrings.xml'));
    final sheetFile = findFile('worksheets/sheet1.xml') ??
        archive.files.firstWhere(
          (f) => f.name.contains('worksheets/') && f.name.endsWith('.xml'),
          orElse: () => throw const FormatException('No worksheet found in .xlsx file.'),
        );

    final doc = XmlDocument.parse(utf8.decode(sheetFile.content as List<int>));
    final rowElements = doc.findAllElements('row').toList();
    if (rowElements.isEmpty) return const [];

    var maxCol = 0;
    final sparse = <int, Map<int, String>>{};

    for (final rowEl in rowElements) {
      final rowIndex = int.tryParse(rowEl.getAttribute('r') ?? '') ??
          (sparse.keys.isEmpty ? 1 : sparse.keys.reduce((a, b) => a > b ? a : b) + 1);
      sparse.putIfAbsent(rowIndex, () => {});
      final rowMap = sparse[rowIndex]!;

      for (final cell in rowEl.findElements('c')) {
        final ref = cell.getAttribute('r') ?? '';
        final colLetters = RegExp(r'^[A-Z]+').firstMatch(ref)?.group(0) ?? 'A';
        final colIndex = _columnLettersToIndex(colLetters);
        if (colIndex > maxCol) maxCol = colIndex;

        final type = cell.getAttribute('t');
        final valueEl = cell.getElement('v');
        final inlineMatches = cell.findElements('t');
        final inlineEl = inlineMatches.isEmpty ? null : inlineMatches.first;
        var value = '';
        if (type == 's' && valueEl != null) {
          final idx = int.tryParse(valueEl.innerText) ?? -1;
          if (idx >= 0 && idx < sharedStrings.length) {
            value = sharedStrings[idx];
          }
        } else if (type == 'inlineStr' && inlineEl != null) {
          value = inlineEl.innerText;
        } else if (valueEl != null) {
          value = valueEl.innerText;
        }
        rowMap[colIndex] = value;
      }
    }

    final sortedRowIndexes = sparse.keys.toList()..sort();
    return sortedRowIndexes.map((rowIndex) {
      final rowMap = sparse[rowIndex]!;
      return List<String>.generate(maxCol + 1, (col) => rowMap[col] ?? '');
    }).toList();
  }

  /// Parse list separated by comma or semicolon
  static List<String> _parseWordList(String raw) {
    if (raw.trim().isEmpty) return [];
    return raw
        .replaceAll(';', ',')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.toLowerCase().contains('backup'))
        .toList();
  }

  /// Smart dynamic bulk import with column header matching from any 2D row table
  Future<int> importFromRows(List<List<String>> rows) async {
    if (rows.isEmpty) return 0;

    final db = await database;
    int importedCount = 0;

    int colWord = -1;
    int colPos = -1;
    int colMeaning = -1;
    int colSyn = -1;
    int colAnt = -1;
    int colImg = -1;
    int colCat = -1;
    int colEx = -1;

    final firstRow = rows.first.map((e) => e.toLowerCase().trim()).toList();
    for (int i = 0; i < firstRow.length; i++) {
      final h = firstRow[i];
      if (h == 'word' || h == 'headword' || h == 'term') {
        colWord = i;
      } else if (h.contains('part') || h.contains('pos')) {
        colPos = i;
      } else if (h.contains('meaning') || h.contains('definition')) {
        colMeaning = i;
      } else if (h.contains('synonym')) {
        colSyn = i;
      } else if (h.contains('antonym')) {
        colAnt = i;
      } else if (h.contains('picture') || h.contains('image') || h.contains('photo') || h.contains('link')) {
        if (colImg == -1) {
          colImg = i;
        }
      } else if (h.contains('categor') || h.contains('topic')) {
        colCat = i;
      } else if (h.contains('example') || h.contains('sentence')) {
        colEx = i;
      }
    }

    int startRow = 1;
    if (colWord == -1) {
      startRow = 0;
      colWord = 0;
      colPos = 1;
      colMeaning = 2;
      colSyn = 3;
      colAnt = 4;
      colImg = 5;
      colCat = 6;
      colEx = 7;
    }

    final batch = db.batch();
    for (int i = startRow; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;

      final word = colWord < row.length ? row[colWord].trim() : '';
      if (word.isEmpty || word.toLowerCase() == 'word') continue;

      final pos = colPos != -1 && colPos < row.length && row[colPos].isNotEmpty
          ? row[colPos].trim()
          : 'Noun';
      final meaning = colMeaning != -1 && colMeaning < row.length
          ? row[colMeaning].trim()
          : '';
      final synonyms = colSyn != -1 && colSyn < row.length
          ? _parseWordList(row[colSyn])
          : <String>[];
      final antonyms = colAnt != -1 && colAnt < row.length
          ? _parseWordList(row[colAnt])
          : <String>[];
      final example = colEx != -1 && colEx < row.length && row[colEx].isNotEmpty
          ? row[colEx].trim()
          : null;

      // Automatically classify category if missing or generic
      String category = colCat != -1 && colCat < row.length ? row[colCat].trim() : '';
      if (category.isEmpty || category.toLowerCase() == 'general' || category.toLowerCase() == 'uncategorized') {
        category = SmartAutoTagger.autoClassify(
          word: word,
          meaning: meaning,
          example: example,
          pos: pos,
        );
      }

      // Automatically resolve image if missing or not a direct link
      final rawImg = colImg != -1 && colImg < row.length ? row[colImg].trim() : '';
      final imageUrl = SmartAutoTagger.autoResolveImage(
        word,
        category: category,
        rawLink: rawImg,
        meaning: meaning,
        pos: pos,
      );

      final entry = PictureWordEntry(
        word: word,
        partOfSpeech: pos,
        englishMeaning: meaning,
        synonyms: synonyms,
        antonyms: antonyms,
        imageUrl: imageUrl,
        thumbnailUrl: imageUrl,
        category: category,
        exampleSentence: example,
      );

      batch.insert(
        'picture_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      importedCount++;
    }

    await batch.commit(noResult: true);
    return importedCount;
  }

  /// Bulk import from CSV string
  Future<int> importFromCsv(String csvContent) async {
    final rows = parseCsvRows(csvContent);
    return importFromRows(rows);
  }

  /// Bulk import directly from Excel (.xlsx) bytes
  Future<int> importFromXlsx(Uint8List bytes) async {
    final rows = readXlsxSheetRows(bytes);
    return importFromRows(rows);
  }

  List<PictureWordEntry> _getInitialStarterEntries() {
    return BundledCardsData.getStarterEntries();
  }

  Future<void> _seedFullDictionary(Database db) async {
    try {
      // 1. First insert all curated starter entries (with HD local cards)
      final starterEntries = _getInitialStarterEntries();
      final starterWords = <String>{};
      for (final entry in starterEntries) {
        starterWords.add(entry.word.trim().toLowerCase());
        await db.insert(
          'picture_entries',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // 2. Read full dictionary.json (all 15,916 entries)
      final jsonString = await rootBundle.loadString('assets/data/dictionary.json');
      final list = jsonDecode(jsonString) as List<dynamic>;

      // Insert in chunks of 500 for fast SQLite performance
      const chunkSize = 500;
      for (int i = 0; i < list.length; i += chunkSize) {
        final batch = db.batch();
        final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
        for (int j = i; j < end; j++) {
          final item = list[j] as Map<String, dynamic>;
          final word = (item['word'] ?? '').toString().trim();
          if (word.isEmpty) continue;
          final lower = word.toLowerCase();
          if (starterWords.contains(lower)) continue;

          final rawPos = (item['partOfSpeech'] ?? 'Noun').toString().trim();
          final meaning = (item['englishMeaning'] ?? '').toString().trim();
          final synonyms = _parseWordList(item['synonyms']?.toString() ?? '');
          final antonyms = _parseWordList(item['antonyms']?.toString() ?? '');
          final example = (item['examples'] ?? '').toString().trim();

          final cat = SmartAutoTagger.autoClassify(
            word: word,
            meaning: meaning,
            example: example,
            pos: rawPos,
          );

          String img = '';
          if (BundledCardsData.wordToAssetMap.containsKey(lower)) {
            img = BundledCardsData.wordToAssetMap[lower]!;
          } else {
            img = SmartAutoTagger.autoResolveImage(
              word,
              category: cat,
              meaning: meaning,
              pos: rawPos,
            );
          }

          final entry = PictureWordEntry(
            word: word,
            partOfSpeech: rawPos.isEmpty ? 'Noun' : rawPos,
            englishMeaning: meaning,
            synonyms: synonyms,
            antonyms: antonyms,
            imageUrl: img,
            thumbnailUrl: img,
            category: cat,
            exampleSentence: example.isNotEmpty ? example : null,
          );

          batch.insert(
            'picture_entries',
            entry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
      debugPrint('Successfully seeded full dictionary (${list.length} entries) into SQLite');
    } catch (e) {
      debugPrint('Error in _seedFullDictionary: $e');
    }
  }
}
