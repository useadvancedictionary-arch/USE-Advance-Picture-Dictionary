import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../widgets/picture_card_image.dart';
import '../models/picture_word_entry.dart';
import '../services/picture_database_service.dart';

class PictureQuizScreen extends StatefulWidget {
  const PictureQuizScreen({super.key});

  @override
  State<PictureQuizScreen> createState() => _PictureQuizScreenState();
}

class _PictureQuizScreenState extends State<PictureQuizScreen> {
  List<PictureWordEntry> _allEntries = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _score = 0;
  bool _hasAnswered = false;
  String? _selectedOption;
  List<String> _currentOptions = [];
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    final entries = await PictureDatabaseService.instance.getAllEntries();
    entries.shuffle(Random());
    if (mounted) {
      setState(() {
        _allEntries = entries;
        _isLoading = false;
        _currentIndex = 0;
        _score = 0;
        _hasAnswered = false;
        _selectedOption = null;
      });
      _setupQuestion();
    }
  }

  void _setupQuestion() {
    if (_allEntries.isEmpty) return;
    final current = _allEntries[_currentIndex];
    final options = <String>{current.word};

    // Pick 3 random distractors
    final random = Random();
    final candidateWords = _allEntries.where((e) => e.word != current.word).map((e) => e.word).toList();
    candidateWords.shuffle(random);

    for (final w in candidateWords) {
      if (options.length >= 4) break;
      options.add(w);
    }

    final shuffledOptions = options.toList()..shuffle(random);
    setState(() {
      _currentOptions = shuffledOptions;
      _hasAnswered = false;
      _selectedOption = null;
    });
  }

  void _handleOptionSelected(String option) {
    if (_hasAnswered) return;
    final correctWord = _allEntries[_currentIndex].word;
    final isCorrect = option == correctWord;

    setState(() {
      _hasAnswered = true;
      _selectedOption = option;
      if (isCorrect) _score++;
    });

    _tts.speak(correctWord);
  }

  void _nextQuestion() {
    if (_currentIndex + 1 < _allEntries.length) {
      setState(() {
        _currentIndex++;
      });
      _setupQuestion();
    } else {
      _showResultDialog();
    }
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quiz Completed! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 64),
            const SizedBox(height: 12),
            Text(
              'Your Score: $_score / ${_allEntries.length}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _score == _allEntries.length
                  ? 'Mastermind! Perfect visual vocabulary!'
                  : 'Well done! Keep practicing to master all picture words.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Exit to Home'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadQuiz();
            },
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_allEntries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Visual Quiz')),
        body: const Center(child: Text('No picture words available for quiz.')),
      );
    }

    final currentEntry = _allEntries[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Vocabulary Quiz'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Score: $_score',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress Indicator
                LinearProgressIndicator(
                  value: (_currentIndex + 1) / _allEntries.length,
                  borderRadius: BorderRadius.circular(8),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  'Question ${_currentIndex + 1} of ${_allEntries.length}',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // Question Title
                const Text(
                  'What is shown in this picture?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // HD Picture Card
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      color: Colors.black12,
                      child: PictureCardImage(
                        imageUrl: currentEntry.imageUrl,
                        fit: BoxFit.cover,
                        word: currentEntry.word,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Meaning Clue
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clue [${currentEntry.partOfSpeech}]: ${currentEntry.englishMeaning}',
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4 Multiple Choice Options
                Expanded(
                  flex: 4,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    children: _currentOptions.map((opt) {
                      final isCorrect = opt == currentEntry.word;
                      final isSelected = opt == _selectedOption;

                      Color? btnColor;
                      Color textColor = Colors.black87;

                      if (_hasAnswered) {
                        if (isCorrect) {
                          btnColor = Colors.green.shade600;
                          textColor = Colors.white;
                        } else if (isSelected) {
                          btnColor = Colors.red.shade600;
                          textColor = Colors.white;
                        }
                      }

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: btnColor,
                          foregroundColor: textColor,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _hasAnswered && isCorrect ? Colors.green : Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onPressed: _hasAnswered ? null : () => _handleOptionSelected(opt),
                        child: Text(
                          opt,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Next Button
                if (_hasAnswered)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      _currentIndex + 1 < _allEntries.length ? 'Next Word' : 'See Results',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _nextQuestion,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}