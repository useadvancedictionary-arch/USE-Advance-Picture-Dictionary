import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/picture_word_entry.dart';
import '../services/interlink_service.dart';
import '../services/picture_database_service.dart';
import '../widgets/picture_card_image.dart';

class PictureWordDetailScreen extends StatefulWidget {
  final PictureWordEntry entry;

  const PictureWordDetailScreen({super.key, required this.entry});

  @override
  State<PictureWordDetailScreen> createState() => _PictureWordDetailScreenState();
}

class _PictureWordDetailScreenState extends State<PictureWordDetailScreen> {
  late PictureWordEntry _currentEntry;
  final FlutterTts _tts = FlutterTts();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _initTts();
  }

  void _initTts() {
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

  Future<void> _speakWord() async {
    setState(() => _isPlayingAudio = true);
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.speak(_currentEntry.word);
  }

  Future<void> _navigateToWord(String word) async {
    final entry = await PictureDatabaseService.instance.getEntryByWord(word);
    if (!mounted) return;
    if (entry != null) {
      setState(() {
        _currentEntry = entry;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No picture found for "$word". Open in USE Advance Dictionary?'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => InterlinkService.instance.openInAdvanceDictionary(context, word),
          ),
        ),
      );
    }
  }

  Color _getPosColor(String pos) {
    switch (pos.toLowerCase()) {
      case 'noun':
        return Colors.indigo;
      case 'verb':
        return Colors.teal;
      case 'adjective':
        return Colors.deepPurple;
      case 'adverb':
        return Colors.amber.shade800;
      default:
        return Colors.blueGrey;
    }
  }

  void _openFullScreenViewer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(_currentEntry.word),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
              child: PictureCardImage(
                imageUrl: _currentEntry.imageUrl,
                fit: BoxFit.contain,
                word: _currentEntry.word,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posColor = _getPosColor(_currentEntry.partOfSpeech);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _currentEntry.word,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isPlayingAudio ? Icons.volume_up : Icons.volume_up_outlined,
              color: _isPlayingAudio ? theme.colorScheme.primary : null,
            ),
            tooltip: 'Listen Pronunciation',
            onPressed: _speakWord,
          ),
          IconButton(
            icon: const Icon(Icons.fullscreen),
            tooltip: 'View Full Picture',
            onPressed: _openFullScreenViewer,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: HD Picture card
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildImageCard(isWide),
                  ),
                ),
                // Vertical divider
                const VerticalDivider(width: 1),
                // Right column: Word details
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildDetailsContent(theme, posColor),
                  ),
                ),
              ],
            );
          } else {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildImageCard(isWide),
                  const SizedBox(height: 20),
                  _buildDetailsContent(theme, posColor),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildImageCard(bool isWide) {
    return GestureDetector(
      onTap: _openFullScreenViewer,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Hero(
            tag: 'word_img_${_currentEntry.word}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isWide ? 20 : 16),
              child: AspectRatio(
                aspectRatio: isWide ? 4 / 3 : 16 / 10,
                child: Container(
                  color: Colors.black12,
                    child: PictureCardImage(
                      imageUrl: _currentEntry.imageUrl,
                      fit: BoxFit.contain,
                      word: _currentEntry.word,
                    ),
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Tap to Zoom', style: TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsContent(ThemeData theme, Color posColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Headword, POS, and Category Badge
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                _currentEntry.word,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: posColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: posColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                _currentEntry.partOfSpeech.toUpperCase(),
                style: TextStyle(
                  color: posColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              _currentEntry.category,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const Divider(height: 28),

        // 2. English Meaning Card
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'English Meaning',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _currentEntry.englishMeaning,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                if (_currentEntry.exampleSentence != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('“ ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Expanded(
                          child: Text(
                            _currentEntry.exampleSentence!,
                            style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13.5),
                          ),
                        ),
                        const Text(' ”', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 3. Synonyms Chips
        if (_currentEntry.synonyms.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.sync_alt, size: 18, color: Colors.teal),
              SizedBox(width: 6),
              Text('Synonyms (Similar Words):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentEntry.synonyms.map((syn) {
              return ActionChip(
                avatar: const Icon(Icons.search, size: 14),
                label: Text(syn),
                backgroundColor: Colors.teal.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.teal.withValues(alpha: 0.25)),
                onPressed: () => _navigateToWord(syn),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],

        // 4. Antonyms Chips
        if (_currentEntry.antonyms.isNotEmpty) ...[
          const Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 18, color: Colors.deepOrange),
              SizedBox(width: 6),
              Text('Antonyms (Opposite Words):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _currentEntry.antonyms.map((ant) {
              return ActionChip(
                avatar: const Icon(Icons.search, size: 14),
                label: Text(ant),
                backgroundColor: Colors.deepOrange.withValues(alpha: 0.08),
                side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.25)),
                onPressed: () => _navigateToWord(ant),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // 5. Companion App Interlink Banner
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E3192).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.auto_stories, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'USE Advance Dictionary',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Explore Sindhi, Urdu, Grammar & MCQs',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF2E3192),
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.launch_rounded, size: 18),
                label: const Text(
                  'Open in USE Advance Dictionary',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  InterlinkService.instance.openInAdvanceDictionary(context, _currentEntry.word);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}