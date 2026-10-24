import 'dart:convert';
import 'dart:io';
import 'bundled_cards_data.dart';


/// Smart Automatic Category Classifier and High-Definition Image Resolver
class SmartAutoTagger {
  static const Map<String, List<String>> _categoryKeywords = {
    'Nature & Animals': [
      'animal', 'bird', 'mammal', 'creature', 'wildlife', 'dog', 'cat', 'lion',
      'tiger', 'elephant', 'eagle', 'dolphin', 'whale', 'fish', 'insect', 'reptile',
      'forest', 'tree', 'flower', 'plant', 'leaf', 'botany', 'river', 'lake',
      'ocean', 'sea', 'mountain', 'glacier', 'valley', 'desert', 'volcano',
      'weather', 'rain', 'snow', 'storm', 'cloud', 'environment', 'ecology',
      'habitat', 'wild', 'species', 'fauna', 'flora', 'marsupial', 'koala',
      'canopy', 'rodent', 'squirrel', 'acorn', 'claw', 'fang',
    ],
    'Science & Space': [
      'space', 'planet', 'star', 'galaxy', 'universe', 'astronaut', 'cosmonaut',
      'telescope', 'astronomy', 'orbit', 'satellite', 'gravity', 'physics',
      'chemistry', 'chemical', 'element', 'atom', 'molecule', 'microscope',
      'laboratory', 'experiment', 'scientific', 'scientist', 'biology', 'quantum',
      'solar', 'lunar', 'asteroid', 'comet', 'radiation',
    ],
    'Technology & Computing': [
      'computer', 'software', 'hardware', 'digital', 'network', 'internet',
      'website', 'app', 'application', 'code', 'programming', 'algorithm',
      'cyber', 'electronic', 'microchip', 'processor', 'data', 'database',
      'server', 'robot', 'robotics', 'ai', 'cloud', 'device', 'decrypt',
      'encryption', 'cybersecurity', 'screen', 'sensor',
    ],
    'Vehicles & Transport': [
      'vehicle', 'transport', 'car', 'automobile', 'truck', 'bus', 'train',
      'locomotive', 'railway', 'airplane', 'aircraft', 'helicopter', 'ship',
      'boat', 'submarine', 'vessel', 'bicycle', 'motorcycle', 'engine',
      'pilot', 'driver', 'highway', 'road', 'buggy', 'stroller', 'carriage',
      'embark', 'voyage', 'cargo',
    ],
    'Law & Justice': [
      'law', 'legal', 'court', 'judge', 'justice', 'jury', 'crime', 'criminal',
      'police', 'attorney', 'lawyer', 'verdict', 'penalty', 'prison', 'jail',
      'rights', 'legislation', 'government', 'acquit', 'convict', 'blame',
      'testify', 'witness', 'constitution', 'statute', 'defense', 'guilty',
      'impose', 'canon', 'canonical', 'fugitive', 'escape', 'runaway', 'outlaw', 'absconder',
    ],
    'Medical & Health': [
      'medical', 'medicine', 'disease', 'illness', 'health', 'doctor', 'hospital',
      'surgery', 'treatment', 'patient', 'anatomy', 'organ', 'blood', 'cell',
      'virus', 'bacteria', 'infection', 'pharmacy', 'symptom', 'diagnosis',
      'therapy', 'nurse', 'brain', 'heart', 'bone', 'muscle', 'vaccine',
      'quarantine', 'cannabis', 'ventral', 'fart', 'digestive', 'enervate',
      'fatigue', 'knuckle',
    ],
    'Food & Culinary': [
      'food', 'cook', 'cooking', 'cuisine', 'fruit', 'vegetable', 'dish', 'meal',
      'eat', 'eating', 'taste', 'flavor', 'bread', 'meat', 'soup', 'salad',
      'kitchen', 'chef', 'restaurant', 'bake', 'baking', 'dessert', 'beverage',
      'drink', 'spice', 'herb', 'edible', 'recipe', 'breakfast', 'dinner',
      'dearth', 'famine', 'pan', 'skillet',
    ],
    'Music & Arts': [
      'music', 'musical', 'instrument', 'xylophone', 'piano', 'guitar', 'violin',
      'song', 'harmony', 'melody', 'rhythm', 'orchestra', 'concert', 'sound',
      'art', 'painting', 'drawing', 'sculpture', 'artist', 'museum', 'canvas',
    ],
    'Emotions & Feelings': [
      'feeling', 'emotion', 'happy', 'sad', 'angry', 'joy', 'jovial', 'jubilant',
      'fascinate', 'malice', 'evil', 'wail', 'grief', 'cry', 'weep', 'outrage',
      'furious', 'indignation', 'fear', 'phobia', 'zoophobia', 'zoosadismophobia',
      'delight', 'cheerful',
    ],
    'People & Life Stages': [
      'person', 'people', 'human', 'child', 'baby', 'infant', 'adolescent',
      'teenager', 'adult', 'elderly', 'youth', 'family', 'parent', 'mother',
      'father', 'friend', 'crowd', 'society', 'community', 'culture', 'generation',
      'cannibal', 'funeral', 'yob', 'woo', 'court', 'romance', 'love',
    ],
    'Actions & Processes': [
      'gather', 'collect', 'accumulate', 'increase', 'move', 'run', 'walk',
      'jump', 'fly', 'push', 'pull', 'create', 'build', 'destroy', 'change',
      'grow', 'devise', 'embark', 'engulf', 'gnaw', 'nod', 'tickle', 'yawn',
      'unleash', 'unravel', 'release',
    ],
  };

  /// High-definition curated image bank mapping for vocabulary words
  static const Map<String, String> _curatedImageBank = {
    'accumulate': 'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&w=1200&q=80',
    'acquit': 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=1200&q=80',
    'adolescent': 'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?auto=format&fit=crop&w=1200&q=80',
    'astronaut': 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?auto=format&fit=crop&w=1200&q=80',
    'telescope': 'https://images.unsplash.com/photo-1516339901601-2e1b62dc0c45?auto=format&fit=crop&w=1200&q=80',
    'microscope': 'https://images.unsplash.com/photo-1582719471384-894fbb16e074?auto=format&fit=crop&w=1200&q=80',
    'eagle': 'https://images.unsplash.com/photo-1611689342806-0863700ce1e4?auto=format&fit=crop&w=1200&q=80',
    'dolphin': 'https://images.unsplash.com/photo-1570481662006-a3a1374699e8?auto=format&fit=crop&w=1200&q=80',
    'volcano': 'https://images.unsplash.com/photo-1541845157-a6d2d100c931?auto=format&fit=crop&w=1200&q=80',
    'glacier': 'https://images.unsplash.com/photo-1517411032315-54ef2cb783bb?auto=format&fit=crop&w=1200&q=80',
    'locomotive': 'https://images.unsplash.com/photo-1474487548417-781cb71495f3?auto=format&fit=crop&w=1200&q=80',
    'lighthouse': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
    'pyramid': 'https://images.unsplash.com/photo-1503177119275-0aa32b3a9368?auto=format&fit=crop&w=1200&q=80',
    'bonfire': 'https://images.unsplash.com/photo-1508873696983-2df5293cb32f?auto=format&fit=crop&w=1200&q=80',
    'buggy': 'https://images.unsplash.com/photo-1591088398332-8a7791972843?auto=format&fit=crop&w=1200&q=80',
    'cannabis': 'https://images.unsplash.com/photo-1536939459926-301728717817?auto=format&fit=crop&w=1200&q=80',
    'cannibal': 'https://images.unsplash.com/photo-1534447677768-be436bb09401?auto=format&fit=crop&w=1200&q=80',
    'canon': 'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=1200&q=80',
    'canonical': 'https://images.unsplash.com/photo-1532012164546-f432f2e3777a?auto=format&fit=crop&w=1200&q=80',
    'canopy': 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1200&q=80',
    'dearth': 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
    'decrypt': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80',
    'devise': 'https://images.unsplash.com/photo-1581091226825-a6a2a5aee158?auto=format&fit=crop&w=1200&q=80',
    'embark': 'https://images.unsplash.com/photo-1500835556837-99ac94a94552?auto=format&fit=crop&w=1200&q=80',
    'enervate': 'https://images.unsplash.com/photo-1518611012118-696072aa579a?auto=format&fit=crop&w=1200&q=80',
    'engulf': 'https://images.unsplash.com/photo-1518457607834-6e8d80c183c5?auto=format&fit=crop&w=1200&q=80',
    'fart': 'https://images.unsplash.com/photo-1541781774459-bb2af2f05b55?auto=format&fit=crop&w=1200&q=80',
    'fascinate': 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=1200&q=80',
    'funeral': 'https://images.unsplash.com/photo-1516589178581-6cd7833ae3b2?auto=format&fit=crop&w=1200&q=80',
    'gnaw': 'https://images.unsplash.com/photo-1507666405895-422eee7d517f?auto=format&fit=crop&w=1200&q=80',
    'harmony': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80',
    'hypocrite': 'https://images.unsplash.com/photo-1509281373149-e957c6296406?auto=format&fit=crop&w=1200&q=80',
    'impose': 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=1200&q=80',
    'jovial': 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=1200&q=80',
    'jubilant': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
    'knuckle': 'https://images.unsplash.com/photo-1583863788434-e58a36330cf0?auto=format&fit=crop&w=1200&q=80',
    'lavish': 'https://images.unsplash.com/photo-1542314831-068cd1dbfeeb?auto=format&fit=crop&w=1200&q=80',
    'malice': 'https://images.unsplash.com/photo-1509248961158-e54f6934749c?auto=format&fit=crop&w=1200&q=80',
    'nod': 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=1200&q=80',
    'ochlophilia': 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=1200&q=80',
    'paltry': 'https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?auto=format&fit=crop&w=1200&q=80',
    'pan': 'https://images.unsplash.com/photo-1584990347449-39bbf8a59400?auto=format&fit=crop&w=1200&q=80',
    'quarantine': 'https://images.unsplash.com/photo-1584483766114-2cea6facdf57?auto=format&fit=crop&w=1200&q=80',
    'rationale': 'https://images.unsplash.com/photo-1434030216411-0b793f4b4173?auto=format&fit=crop&w=1200&q=80',
    'shabby': 'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=1200&q=80',
    'tickle': 'https://images.unsplash.com/photo-1485546246426-74dc88dec4d9?auto=format&fit=crop&w=1200&q=80',
    'tidy': 'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=1200&q=80',
    'unleash': 'https://images.unsplash.com/photo-1548767797-d8c844163c4c?auto=format&fit=crop&w=1200&q=80',
    'unravel': 'https://images.unsplash.com/photo-1584992236310-6edddc08acff?auto=format&fit=crop&w=1200&q=80',
    'ventral': 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80',
    'wail': 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?auto=format&fit=crop&w=1200&q=80',
    'xylophone': 'https://images.unsplash.com/photo-1519892300165-cb5542fb47c7?auto=format&fit=crop&w=1200&q=80',
    'yawn': 'https://images.unsplash.com/photo-1517849845537-4d257902454a?auto=format&fit=crop&w=1200&q=80',
    'yestreen': 'https://images.unsplash.com/photo-1507499739999-097706ad8914?auto=format&fit=crop&w=1200&q=80',
    'yob': 'https://images.unsplash.com/photo-1509114397022-ed747cca3f65?auto=format&fit=crop&w=1200&q=80',
    'zoophobia': 'https://images.unsplash.com/photo-1500485035595-cbe6f645feb1?auto=format&fit=crop&w=1200&q=80',
    'zoosadismophobia': 'https://images.unsplash.com/photo-1535268647677-300dbf3d78d1?auto=format&fit=crop&w=1200&q=80',
    'outrage': 'https://images.unsplash.com/photo-1516251193007-45ef944ab0c6?auto=format&fit=crop&w=1200&q=80',
    'woo': 'https://images.unsplash.com/photo-1518199266791-5375a83190b7?auto=format&fit=crop&w=1200&q=80',
    'helicopter': 'https://images.unsplash.com/photo-1508614589041-895b88991e3e?auto=format&fit=crop&w=1200&q=80',
    'submarine': 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?auto=format&fit=crop&w=1200&q=80',
    'koala': 'https://images.unsplash.com/photo-1540573133985-87b6da6d54a9?auto=format&fit=crop&w=1200&q=80',
    'fugitive': 'https://images.unsplash.com/photo-1509281373149-e957c6296406?auto=format&fit=crop&w=1200&q=80',
  };

  /// Automatically predicts the best educational topic category using exact word token boundaries
  static String autoClassify({
    required String word,
    required String meaning,
    String? example,
    String? pos,
  }) {
    final text = ' $word $meaning ${example ?? ''} '.toLowerCase();

    String bestCategory = 'General Vocabulary';
    int maxScore = 0;

    _categoryKeywords.forEach((category, keywords) {
      int score = 0;
      for (final kw in keywords) {
        // Use whole-word boundary matching to avoid partial substring false matches
        final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
        if (regex.hasMatch(text)) {
          score += (kw == word.toLowerCase()) ? 5 : 2;
        }
      }
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    });

    // POS based fallback if no keyword matched
    if (maxScore == 0 && pos != null) {
      final p = pos.toLowerCase();
      if (p.contains('verb')) return 'Actions & Processes';
      if (p.contains('adj')) return 'Descriptive Qualities';
    }

    return bestCategory;
  }

  static const Map<String, String> _categoryFallbackImages = {
    'Nature & Animals': 'https://images.unsplash.com/photo-1517411032315-54ef2cb783bb?auto=format&fit=crop&w=1200&q=80',
    'Science & Space': 'https://images.unsplash.com/photo-1446776811953-b23d57bd21aa?auto=format&fit=crop&w=1200&q=80',
    'Technology & Computing': 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?auto=format&fit=crop&w=1200&q=80',
    'Vehicles & Transport': 'https://images.unsplash.com/photo-1474487548417-781cb71495f3?auto=format&fit=crop&w=1200&q=80',
    'Law & Justice': 'https://images.unsplash.com/photo-1589829545856-d10d557cf95f?auto=format&fit=crop&w=1200&q=80',
    'Medical & Health': 'https://images.unsplash.com/photo-1584483766114-2cea6facdf57?auto=format&fit=crop&w=1200&q=80',
    'Food & Culinary': 'https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&w=1200&q=80',
    'Music & Arts': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?auto=format&fit=crop&w=1200&q=80',
    'Emotions & Feelings': 'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?auto=format&fit=crop&w=1200&q=80',
    'People & Life Stages': 'https://images.unsplash.com/photo-1529333166437-7750a6dd5a70?auto=format&fit=crop&w=1200&q=80',
    'Actions & Processes': 'https://images.unsplash.com/photo-1579621970563-ebec7560ff3e?auto=format&fit=crop&w=1200&q=80',
    'General Vocabulary': 'https://images.unsplash.com/photo-1455390582262-044cdead277a?auto=format&fit=crop&w=1200&q=80',
  };

  /// Constructs an exact educational image generation URL matching the word meaning
  static String buildAiFlashcardUrl({
    required String word,
    required String meaning,
    String? pos,
  }) {
    final firstSentence = meaning.split(RegExp(r'\. |\.\n')).first.trim();
    final cleanMeaning = firstSentence.replaceAll(RegExp(r'[\r\n"]'), ' ');
    final prompt = 'Educational dictionary flashcard visual depicting "$cleanMeaning", representing vocabulary word "$word" ($pos), realistic photographic style, high clarity, didactic storytelling composition';
    final encoded = Uri.encodeComponent(prompt);
    return 'https://image.pollinations.ai/prompt/$encoded?width=800&height=600&nologo=true';
  }

  /// Automatically resolves a high-definition image URL or bundled asset for any word
  static String autoResolveImage(
    String word, {
    String? category,
    String? rawLink,
    String? meaning,
    String? pos,
  }) {
    final lower = word.trim().toLowerCase();

    // 1. Check if an exact local curated flashcard is bundled in assets/cards/
    if (BundledCardsData.wordToAssetMap.containsKey(lower)) {
      return BundledCardsData.wordToAssetMap[lower]!;
    }

    final clean = (rawLink ?? '').trim();
    // 2. Direct web URL or asset path
    if (clean.startsWith('assets/') ||
        ((clean.startsWith('http://') || clean.startsWith('https://')) &&
            !clean.contains('wikipedia.org/api/rest_v1'))) {
      return clean;
    }

    // 3. AI generated visual matching meaning if meaning is available
    if (meaning != null && meaning.trim().isNotEmpty) {
      return buildAiFlashcardUrl(word: word, meaning: meaning, pos: pos);
    }

    // 4. Curated image bank
    if (_curatedImageBank.containsKey(lower)) {
      return _curatedImageBank[lower]!;
    }

    // 5. Fallback to category-based curated image
    return _categoryFallbackImages[category] ?? _categoryFallbackImages['General Vocabulary']!;
  }

  /// Asynchronously fetches an image: bundled asset > AI flashcard > Wikipedia > category fallback
  static Future<String> resolveImageAsync(
    String word, {
    String? category,
    String? rawLink,
    String? meaning,
    String? pos,
  }) async {
    final lower = word.trim().toLowerCase();

    // 1. First check bundled flashcard asset
    if (BundledCardsData.wordToAssetMap.containsKey(lower)) {
      return BundledCardsData.wordToAssetMap[lower]!;
    }

    final clean = (rawLink ?? '').trim();
    if (clean.startsWith('assets/') ||
        ((clean.startsWith('http://') || clean.startsWith('https://')) &&
            !clean.contains('wikipedia.org/api/rest_v1'))) {
      return clean;
    }

    // 2. High-precision didactic visual generated directly from meaning
    if (meaning != null && meaning.trim().isNotEmpty) {
      return buildAiFlashcardUrl(word: word, meaning: meaning, pos: pos);
    }

    if (_curatedImageBank.containsKey(lower)) {
      return _curatedImageBank[lower]!;
    }

    // 3. Fallback to Wikipedia thumbnail
    final wikiImg = await fetchWikipediaThumbnail(lower);
    if (wikiImg != null && wikiImg.isNotEmpty) {
      return wikiImg;
    }

    return autoResolveImage(word, category: category, rawLink: rawLink, meaning: meaning, pos: pos);
  }

  /// Fetch thumbnail image from Wikipedia
  static Future<String?> fetchWikipediaThumbnail(String word) async {
    try {
      final cleanWord = Uri.encodeComponent(word.trim().toLowerCase());
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final req = await client.getUrl(Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$cleanWord'));
      req.headers.set('User-Agent', 'USEAdvancePictureDictionary/1.0 (educational)');
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        final thumb = data['thumbnail']?['source']?.toString();
        if (thumb != null && thumb.startsWith('http')) {
          return thumb;
        }
        final orig = data['originalimage']?['source']?.toString();
        if (orig != null && orig.startsWith('http')) {
          return orig;
        }
      }
    } catch (_) {}
    return null;
  }
}
