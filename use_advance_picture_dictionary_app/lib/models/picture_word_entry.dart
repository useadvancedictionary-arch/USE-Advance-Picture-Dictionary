import 'dart:convert';

class PictureWordEntry {
  final int? id;
  final String word;
  final String partOfSpeech;
  final String englishMeaning;
  final List<String> synonyms;
  final List<String> antonyms;
  final String imageUrl;
  final String? thumbnailUrl;
  final String category;
  final String? exampleSentence;

  const PictureWordEntry({
    this.id,
    required this.word,
    required this.partOfSpeech,
    required this.englishMeaning,
    required this.synonyms,
    required this.antonyms,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.category,
    this.exampleSentence,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'word': word,
      'part_of_speech': partOfSpeech,
      'english_meaning': englishMeaning,
      'synonyms': jsonEncode(synonyms),
      'antonyms': jsonEncode(antonyms),
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'category': category,
      'example_sentence': exampleSentence,
    };
  }

  factory PictureWordEntry.fromMap(Map<String, dynamic> map) {
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
      id: map['id'] as int?,
      word: map['word']?.toString() ?? '',
      partOfSpeech: map['part_of_speech']?.toString() ?? 'noun',
      englishMeaning: map['english_meaning']?.toString() ?? '',
      synonyms: parseList(map['synonyms']),
      antonyms: parseList(map['antonyms']),
      imageUrl: map['image_url']?.toString() ?? '',
      thumbnailUrl: map['thumbnail_url']?.toString(),
      category: map['category']?.toString() ?? 'General',
      exampleSentence: map['example_sentence']?.toString(),
    );
  }
}