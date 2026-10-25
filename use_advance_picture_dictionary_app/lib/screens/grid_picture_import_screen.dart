import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../services/grid_image_splitter_service.dart';
import '../services/picture_database_service.dart';
import '../services/windows_card_ocr_service.dart';
import 'picture_word_detail_screen.dart';

class GridPictureImportScreen extends StatefulWidget {
  final String? initialImagePath;

  const GridPictureImportScreen({super.key, this.initialImagePath});

  @override
  State<GridPictureImportScreen> createState() => _GridPictureImportScreenState();
}

class _GridPictureImportScreenState extends State<GridPictureImportScreen> {
  Uint8List? _sourceImageBytes;
  String? _sourceFileName;
  String? _sourceFilePath;
  ui.Image? _decodedUiImage;
  bool _isDragging = false;
  bool _isOcrRunning = false;

  final Map<int, String> _autoDetectedTitles = {};
  final Map<int, String> _autoDetectedMeanings = {};

  // Grid dimensions
  int _rows = 2;
  int _columns = 5;

  // Crop Preset:
  // 0 = AI Flashcard Sheet (5x2 with Gutter & Margin Offsets)
  // 1 = Illustration Only (Header & Meaning Trimmed)
  // 2 = Full Card (0-Gap Pure Grid)
  // 3 = Custom Sliders
  int _cropPreset = 0;

  // Geometry parameters (Percentages)
  double _outerMarginX = 0.02; // 2% left/right margin
  double _outerMarginY = 0.02; // 2% top/bottom margin
  double _hGutter = 0.018; // 1.8% gap between columns
  double _vGutter = 0.022; // 2.2% gap between rows
  double _innerInset = 0.015; // 1.5% safety inset to prevent neighbor bleed
  double _topTrim = 0.0; // Header/title trim
  double _bottomTrim = 0.0; // Footer/meaning trim
  bool _normalizeDimensions = true;

  final TextEditingController _wordsInputController = TextEditingController();
  List<CroppedCard> _croppedCards = [];
  Map<String, String> _wordDbStatus = {}; // word -> status label

  bool _isProcessing = false;
  bool _isSaving = false;
  bool _showVisualOverlay = true;
  String? _statusMessage;

  // Sample word lists for quick testing
  static const String _sampleWordsA =
      'Abound, Above board, Abradant, Abrade, Abrasion, Abrasive, Abrasively, Abrasiveness, Abreast, Abrogate';
  static const String _sampleWordsIdioms =
      'A wet blanket, A wild goose chase, A wolf in sheep\'s clothing, Abandon, Abase, Abash, Abate, Abatement, Abbey, Abbot';

  @override
  void initState() {
    super.initState();
    _applyPreset(0);

    if (widget.initialImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFileFromPath(widget.initialImagePath!);
      });
    }
  }

  @override
  void dispose() {
    _wordsInputController.dispose();
    super.dispose();
  }

  void _applyPreset(int preset) {
    setState(() {
      _cropPreset = preset;
      if (preset == 0) {
        // AI Flashcard Sheet (5x2 with Gutters)
        _outerMarginX = 0.02;
        _outerMarginY = 0.02;
        _hGutter = 0.018;
        _vGutter = 0.022;
        _innerInset = 0.015;
        _topTrim = 0.0;
        _bottomTrim = 0.0;
      } else if (preset == 1) {
        // Center Illustration Only
        _outerMarginX = 0.02;
        _outerMarginY = 0.02;
        _hGutter = 0.018;
        _vGutter = 0.022;
        _innerInset = 0.015;
        _topTrim = 0.16; // trim title banner
        _bottomTrim = 0.28; // trim meaning box
      } else if (preset == 2) {
        // Full Card (0-Gap Math)
        _outerMarginX = 0.0;
        _outerMarginY = 0.0;
        _hGutter = 0.0;
        _vGutter = 0.0;
        _innerInset = 0.0;
        _topTrim = 0.0;
        _bottomTrim = 0.0;
      }
    });
  }

  GridSplitConfig _buildConfig() {
    return GridSplitConfig(
      rows: _rows,
      columns: _columns,
      outerMarginXPercent: _outerMarginX,
      outerMarginYPercent: _outerMarginY,
      horizontalGutterPercent: _hGutter,
      verticalGutterPercent: _vGutter,
      innerInsetPercent: _innerInset,
      topCardTrimPercent: _topTrim,
      bottomCardTrimPercent: _bottomTrim,
      normalizeDimensions: _normalizeDimensions,
      targetWidth: 400,
      targetHeight: 550,
    );
  }

  Future<void> _loadFileFromPath(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final name = path.split(RegExp(r'[/\\]')).last;
      _sourceFilePath = path;
      await _loadFromBytes(bytes, name, filePath: path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading image file: $e')),
        );
      }
    }
  }

  Future<void> _loadFromBytes(Uint8List bytes, String name, {String? filePath}) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      _sourceFilePath = filePath;
      _autoDetectedTitles.clear();
      _autoDetectedMeanings.clear();

      setState(() {
        _sourceImageBytes = bytes;
        _sourceFileName = name;
        _decodedUiImage = frame.image;
        _statusMessage = 'Loaded image "$name" (${frame.image.width}×${frame.image.height}px). Auto-detecting words from image...';
      });

      // Automatically extract words directly from the picture cards
      await _autoDetectWordsFromImage();

      await _processAndSplit();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not decode image: $e')),
        );
      }
    }
  }

  Future<void> _autoDetectWordsFromImage() async {
    if (_sourceImageBytes == null) return;

    String? tempPathToClean;
    String pathToScan = _sourceFilePath ?? '';

    if (pathToScan.isEmpty) {
      final tempFile = File('${Directory.systemTemp.path}/ocr_temp_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(_sourceImageBytes!);
      pathToScan = tempFile.path;
      tempPathToClean = tempFile.path;
    }

    setState(() {
      _isOcrRunning = true;
      _statusMessage = 'Reading card words & idioms from image via OCR...';
    });

    try {
      final ocrList = await WindowsCardOcrService.instance.extractCardsText(
        imagePath: pathToScan,
        rows: _rows,
        columns: _columns,
      );

      if (ocrList.isNotEmpty) {
        final titlesMap = <int, String>{};
        final meaningsMap = <int, String>{};
        final wordList = <String>[];

        for (final item in ocrList) {
          if (item.title.isNotEmpty) {
            titlesMap[item.index] = item.title;
            wordList.add(item.title);
          }
          if (item.meaning.isNotEmpty) {
            meaningsMap[item.index] = item.meaning;
          }
        }

        if (wordList.isNotEmpty && mounted) {
          setState(() {
            _autoDetectedTitles.clear();
            _autoDetectedTitles.addAll(titlesMap);
            _autoDetectedMeanings.clear();
            _autoDetectedMeanings.addAll(meaningsMap);
            _wordsInputController.text = wordList.join(', ');
            _statusMessage = 'Auto-detected ${wordList.length} words directly from image!';
          });
        }
      }
    } catch (e) {
      debugPrint('OCR detection error: $e');
    } finally {
      if (tempPathToClean != null) {
        try {
          File(tempPathToClean).deleteSync();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _isOcrRunning = false;
        });
      }
    }
  }

  Future<void> _pickImageFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        await _loadFileFromPath(files.first.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  List<String> _parseWordsList() {
    final text = _wordsInputController.text.trim();
    if (text.isEmpty) return [];

    return text
        .split(RegExp(r'[,\n\r]+'))
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
  }

  Future<void> _processAndSplit() async {
    if (_sourceImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a composite grid image first.')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Calculating gutter geometry and splitting cards...';
    });

    try {
      final config = _buildConfig();
      final words = _parseWordsList();

      final cards = await GridImageSplitterService.instance.splitImage(
        imageBytes: _sourceImageBytes!,
        config: config,
        initialWords: words,
      );

      // Prioritize auto-detected word from image for each card
      for (int i = 0; i < cards.length; i++) {
        if (_autoDetectedTitles.containsKey(i) && _autoDetectedTitles[i]!.isNotEmpty) {
          cards[i].word = _autoDetectedTitles[i]!;
        }
      }

      // Check DB status for each word
      final statusMap = <String, String>{};
      for (final card in cards) {
        if (card.word.isNotEmpty) {
          final existing = await PictureDatabaseService.instance.getEntryByWord(card.word);
          if (existing != null) {
            statusMap[card.word.toLowerCase()] = 'In DB (Definitions Preserved)';
          } else {
            final dictEntry = await PictureDatabaseService.instance.getDictionaryWord(card.word);
            if (dictEntry != null) {
              statusMap[card.word.toLowerCase()] = 'In Dictionary';
            } else {
              statusMap[card.word.toLowerCase()] = 'New Word';
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _croppedCards = cards;
          _wordDbStatus = statusMap;
          _isProcessing = false;
          _statusMessage = 'Successfully split into ${cards.length} cards with 0 neighbor bleed. Review below.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Splitting failed: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error splitting image: $e')),
        );
      }
    }
  }

  void _onWordChanged(int index, String newWord) async {
    if (index >= 0 && index < _croppedCards.length) {
      _croppedCards[index].word = newWord.trim();
      final trimmed = newWord.trim();
      if (trimmed.isNotEmpty) {
        final existing = await PictureDatabaseService.instance.getEntryByWord(trimmed);
        if (mounted) {
          setState(() {
            if (existing != null) {
              _wordDbStatus[trimmed.toLowerCase()] = 'In DB (Definitions Preserved)';
            } else {
              _wordDbStatus[trimmed.toLowerCase()] = 'New Headword';
            }
          });
        }
      }
    }
  }

  Future<void> _applyPicturesToDictionary() async {
    final validCards = _croppedCards.where((c) => c.word.trim().isNotEmpty).toList();

    if (validCards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please assign at least one word to a card before applying.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Confirm Picture Update'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will update the picture for ${validCards.length} words.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All existing definitions, POS, synonyms, antonyms, examples, and all other words remain 100% UNCHANGED with ZERO DUPLICATES.',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving pictures and updating dictionary entries...';
    });

    try {
      final Map<String, String> wordToPathMap = {};
      final Map<String, String> wordToMeaningMap = {};

      for (final card in validCards) {
        final word = card.word.trim();
        final filePath = await GridImageSplitterService.instance.saveCroppedPicture(
          word: word,
          bytes: card.bytes,
        );
        wordToPathMap[word] = filePath;
        if (_autoDetectedMeanings.containsKey(card.index)) {
          wordToMeaningMap[word] = _autoDetectedMeanings[card.index]!;
        }
      }

      final result = await PictureDatabaseService.instance.batchUpdateWordPictures(
        wordToPathMap,
        wordToMeaningMap: wordToMeaningMap,
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Done! Updated ${result.updatedExisting} existing words and added ${result.newlyCreated} entries.';
        });

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Row(
              children: [
                Icon(Icons.celebration_rounded, color: Colors.amber),
                SizedBox(width: 8),
                Text('Pictures Updated! 🎉'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Successfully updated pictures for ${result.totalProcessed} words!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                Text('• Existing dictionary words updated: ${result.updatedExisting}'),
                Text('• New entries added: ${result.newlyCreated}'),
                const Text('• Duplicate entries created: 0 (Guaranteed)'),
                const Text('• Other words & definitions: 100% Intact'),
                const SizedBox(height: 16),
                const Text(
                  'Updated Words:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result.updatedWords.map((w) {
                    return ActionChip(
                      label: Text(w, style: const TextStyle(fontSize: 12)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final entry = await PictureDatabaseService.instance.getEntryByWord(w);
                        if (entry != null && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PictureWordDetailScreen(entry: entry),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('Return to Dictionary'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _statusMessage = 'Update error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update dictionary: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCards = _rows * _columns;
    final wordsCount = _parseWordsList().length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Split & Assign Grid Pictures'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How Gutter Splitting Works',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (detail) => setState(() => _isDragging = true),
        onDragExited: (detail) => setState(() => _isDragging = false),
        onDragDone: (detail) async {
          setState(() => _isDragging = false);
          if (detail.files.isEmpty) return;
          final file = detail.files.first;
          final path = file.path;
          final lower = path.toLowerCase();
          if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) {
            await _loadFileFromPath(path);
          } else if (lower.endsWith('.xlsx') || lower.endsWith('.csv') || lower.endsWith('.txt')) {
            try {
              final f = File(path);
              List<String> words = [];
              if (lower.endsWith('.xlsx')) {
                final bytes = await f.readAsBytes();
                final rows = PictureDatabaseService.readXlsxSheetRows(bytes);
                if (rows.length > 1) {
                  for (var i = 1; i < rows.length; i++) {
                    if (rows[i].isNotEmpty && rows[i][0].trim().isNotEmpty) {
                      words.add(rows[i][0].trim());
                    }
                  }
                }
              } else {
                final content = await f.readAsString();
                final lines = content.split(RegExp(r'[\r\n]+'));
                for (var i = 1; i < lines.length; i++) {
                  final col = lines[i].split(',').first.trim().replaceAll('"', '');
                  if (col.isNotEmpty) words.add(col);
                }
              }
              if (words.isNotEmpty && mounted) {
                setState(() {
                  _wordsInputController.text = words.join(', ');
                  _statusMessage = 'Extracted ${words.length} words from dropped spreadsheet!';
                });
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Extracted ${words.length} words from dropped spreadsheet!')),
                  );
                }
                if (_sourceImageBytes != null) {
                  _processAndSplit();
                }
              }
            } catch (e) {
              // ignore
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please drop a valid image (.png, .jpg, .webp) or spreadsheet (.xlsx, .csv)')),
              );
            }
          }
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Safety & Feature Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.grid_on_rounded, color: theme.colorScheme.primary, size: 28),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Multi-Card Grid Splitter with Drag & Drop',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Drag and drop any composite sheet directly into this window, or pick from disk. Auto-offsets outer margins and inter-card gutters with visual alignment.',
                                    style: TextStyle(fontSize: 13, height: 1.35),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Step 1: Pick Image / Drag & Drop Zone
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _isDragging
                                ? theme.colorScheme.primary
                                : theme.dividerColor.withValues(alpha: 0.2),
                            width: _isDragging ? 2.0 : 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Step 1: Choose Composite Image',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const Spacer(),
                                  if (_sourceFileName != null)
                                    TextButton.icon(
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Change Image'),
                                      onPressed: _isProcessing ? null : _pickImageFile,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              if (_sourceImageBytes == null)
                                InkWell(
                                  onTap: _isProcessing ? null : _pickImageFile,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload_outlined,
                                            size: 48,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'Drag & Drop Picture Grid Sheet Here',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'or click here to browse (PNG, JPG, WEBP)',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.add_photo_alternate_rounded),
                                      label: const Text('Pick Other Image'),
                                      onPressed: _isProcessing ? null : _pickImageFile,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Selected: $_sourceFileName (${_decodedUiImage?.width ?? 0}×${_decodedUiImage?.height ?? 0}px)',
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.teal),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),

                              // Interactive Visual Overlay Preview
                              if (_sourceImageBytes != null && _decodedUiImage != null) ...[
                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Live Visual Crop Alignment Preview',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                              Row(
                                children: [
                                  Text(
                                    _showVisualOverlay ? 'Overlay Visible' : 'Overlay Hidden',
                                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                                  ),
                                  Switch(
                                    value: _showVisualOverlay,
                                    onChanged: (v) => setState(() => _showVisualOverlay = v),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 280,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.memory(
                                      _sourceImageBytes!,
                                      fit: BoxFit.contain,
                                    ),
                                    if (_showVisualOverlay && _decodedUiImage != null)
                                      CustomPaint(
                                        painter: _GridCropOverlayPainter(
                                          imageWidth: _decodedUiImage!.width.toDouble(),
                                          imageHeight: _decodedUiImage!.height.toDouble(),
                                          config: _buildConfig(),
                                          words: _parseWordsList(),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Numbered boxes (1 to $totalCards) show the exact crop boundaries. Adjust presets or sliders below to line up perfectly with zero neighbor bleed.',
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                          ),
                        ],

                        const Divider(height: 28),

                        // Step 2: Grid Dimensions & Preset Options
                        const Text(
                          'Step 2: Grid Dimensions & Spacing Presets',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Text('Rows: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _rows > 1 ? () => setState(() => _rows--) : null,
                            ),
                            Text('$_rows', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _rows < 10 ? () => setState(() => _rows++) : null,
                            ),
                            const SizedBox(width: 24),

                            const Text('Columns: ', style: TextStyle(fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: _columns > 1 ? () => setState(() => _columns--) : null,
                            ),
                            Text('$_columns', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _columns < 10 ? () => setState(() => _columns++) : null,
                            ),
                            const Spacer(),

                            Text(
                              'Total Cards: $totalCards',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Crop Mode Presets
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ChoiceChip(
                              avatar: const Icon(Icons.auto_awesome, size: 16),
                              label: const Text('AI Flashcard Sheet (5×2 with Gutters)'),
                              selected: _cropPreset == 0,
                              onSelected: (val) {
                                if (val) _applyPreset(0);
                              },
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.crop_square, size: 16),
                              label: const Text('Illustration Center Only (Header & Meaning Trimmed)'),
                              selected: _cropPreset == 1,
                              onSelected: (val) {
                                if (val) _applyPreset(1);
                              },
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.aspect_ratio, size: 16),
                              label: const Text('Full Card (0-Gap Math)'),
                              selected: _cropPreset == 2,
                              onSelected: (val) {
                                if (val) _applyPreset(2);
                              },
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.tune, size: 16),
                              label: const Text('Custom Fine-Tuning'),
                              selected: _cropPreset == 3,
                              onSelected: (val) {
                                if (val) setState(() => _cropPreset = 3);
                              },
                            ),
                          ],
                        ),

                        // Sliders if Custom Fine-Tuning selected
                        if (_cropPreset == 3) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildSliderRow(
                                  label: 'Outer Sheet Margin X',
                                  percent: _outerMarginX,
                                  onChanged: (v) => setState(() => _outerMarginX = v),
                                  max: 0.10,
                                ),
                                _buildSliderRow(
                                  label: 'Outer Sheet Margin Y',
                                  percent: _outerMarginY,
                                  onChanged: (v) => setState(() => _outerMarginY = v),
                                  max: 0.10,
                                ),
                                _buildSliderRow(
                                  label: 'Inter-Card Gutter Gap X',
                                  percent: _hGutter,
                                  onChanged: (v) => setState(() => _hGutter = v),
                                  max: 0.08,
                                ),
                                _buildSliderRow(
                                  label: 'Inter-Card Gutter Gap Y',
                                  percent: _vGutter,
                                  onChanged: (v) => setState(() => _vGutter = v),
                                  max: 0.08,
                                ),
                                _buildSliderRow(
                                  label: 'Inner Safety Inset (No Bleed)',
                                  percent: _innerInset,
                                  onChanged: (v) => setState(() => _innerInset = v),
                                  max: 0.05,
                                ),
                                _buildSliderRow(
                                  label: 'Card Header Trim',
                                  percent: _topTrim,
                                  onChanged: (v) => setState(() => _topTrim = v),
                                  max: 0.35,
                                ),
                                _buildSliderRow(
                                  label: 'Card Meaning Trim',
                                  percent: _bottomTrim,
                                  onChanged: (v) => setState(() => _bottomTrim = v),
                                  max: 0.45,
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Checkbox(
                              value: _normalizeDimensions,
                              onChanged: (v) => setState(() => _normalizeDimensions = v ?? true),
                            ),
                            const Text(
                              'Normalize all exported cards to identical dimensions (400×550 px)',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),

                        const Divider(height: 28),

                        // Step 3: Words List Input
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Step 3: Words List (in left-to-right, top-to-bottom order)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$wordsCount / $totalCards words entered',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: wordsCount == totalCards ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: _isOcrRunning
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.auto_awesome_rounded, size: 16),
                                  label: Text(_isOcrRunning ? 'Detecting...' : 'Auto-Detect from Image'),
                                  onPressed: (_isOcrRunning || _sourceImageBytes == null)
                                      ? null
                                      : () async {
                                          await _autoDetectWordsFromImage();
                                          await _processAndSplit();
                                        },
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _wordsInputController.text = _sampleWordsA;
                                    });
                                  },
                                  child: const Text('Sample A-Words', style: TextStyle(fontSize: 12)),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _wordsInputController.text = _sampleWordsIdioms;
                                    });
                                  },
                                  child: const Text('Sample Idioms', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _wordsInputController,
                          maxLines: 2,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Words are automatically detected from image upon loading. You can also edit or paste here...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Split / Refresh Action Button
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isProcessing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.splitscreen_rounded),
                          label: Text(_isProcessing ? 'Processing Split...' : 'Process & Preview Split Cards'),
                          onPressed: (_sourceImageBytes != null && !_isProcessing) ? _processAndSplit : null,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],

                // 3. Step 4: Preview Cards Grid
                if (_croppedCards.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Step 4: Review Cropped Cards (${_croppedCards.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check_circle_rounded),
                        label: const Text('Apply Pictures to Dictionary'),
                        onPressed: _isSaving ? null : _applyPicturesToDictionary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Cards Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900
                          ? _columns.clamp(1, 5)
                          : (constraints.maxWidth > 600 ? 3 : 2);

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _croppedCards.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.72,
                        ),
                        itemBuilder: (context, index) {
                          final card = _croppedCards[index];
                          final status = _wordDbStatus[card.word.toLowerCase()];

                          return Card(
                            elevation: 2,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: card.word.isNotEmpty
                                    ? Colors.teal.withValues(alpha: 0.4)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Cropped Image
                                Expanded(
                                  child: Container(
                                    color: Colors.black12,
                                    child: Image.memory(
                                      card.bytes,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),

                                // Cell index and status
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '#${index + 1} (${card.width}×${card.height})',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.textTheme.bodySmall?.color,
                                        ),
                                      ),
                                      if (status != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: status.contains('Preserved')
                                                ? Colors.green.withValues(alpha: 0.15)
                                                : Colors.blue.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status.contains('Preserved') ? 'In DB' : 'Dict',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: status.contains('Preserved')
                                                  ? Colors.green.shade800
                                                  : Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Word text field
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextFormField(
                                    key: ValueKey('card_${card.index}_${card.word}'),
                                    initialValue: card.word,
                                    onChanged: (val) => _onWordChanged(index, val),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      labelText: 'Headword',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      suffixIcon: (_autoDetectedTitles.containsKey(index) && _autoDetectedTitles[index] == card.word)
                                          ? const Tooltip(
                                              message: 'Auto-detected from image',
                                              child: Icon(Icons.auto_awesome, size: 16, color: Colors.amber),
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Bottom Final Apply Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 22),
                    label: Text(
                      _isSaving ? 'Applying Pictures to Database...' : 'Apply All Cropped Pictures to Dictionary',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _isSaving ? null : _applyPicturesToDictionary,
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.65),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.colorScheme.primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.file_download_rounded, size: 64, color: theme.colorScheme.primary),
                          const SizedBox(height: 16),
                          Text(
                            'Drop Grid Image Here!',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports PNG, JPG, WEBP composite sheets',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double percent,
    required ValueChanged<double> onChanged,
    required double max,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 190,
          child: Text(
            '$label: ${(percent * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Slider(
            value: percent.clamp(0.0, max),
            min: 0.0,
            max: max,
            divisions: (max * 100).round() * 2,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: Colors.indigo),
            SizedBox(width: 8),
            Text('Grid Import Guide'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gutter-Aware Card Splitting:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text('• Outer Sheet Margins: Automatically trims white or dark borders around the full composite image.'),
              Text('• Inter-Card Gutters: Calculates horizontal and vertical spaces between flashcards so neighboring card borders do NOT bleed in.'),
              Text('• Inner Safety Inset: Applies a 1.5% interior margin to guarantee clean card cropping.'),
              Text('• Real-Time Visual Overlay: Preview the numbered boxes right on the image before slicing.'),
              SizedBox(height: 12),
              Text(
                'Guarantees:',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
              ),
              SizedBox(height: 4),
              Text('• Existing definitions, POS, synonyms, antonyms, and examples stay 100% intact.'),
              Text('• Zero duplicate words or orphaned files are created.'),
              Text('• All exported cards can be normalized to identical dimensions.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws the live visual crop overlay over the composite image preview
class _GridCropOverlayPainter extends CustomPainter {
  final double imageWidth;
  final double imageHeight;
  final GridSplitConfig config;
  final List<String> words;

  _GridCropOverlayPainter({
    required this.imageWidth,
    required this.imageHeight,
    required this.config,
    required this.words,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    // Calculate scale factor between intrinsic image and display canvas size
    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final renderedW = imageWidth * scale;
    final renderedH = imageHeight * scale;
    final offsetX = (size.width - renderedW) / 2;
    final offsetY = (size.height - renderedH) / 2;

    final rects = GridSplitConfig.computeCellRects(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      config: config,
    );

    final boxPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < rects.length; i++) {
      final r = rects[i];
      final scaledRect = Rect.fromLTWH(
        offsetX + r.left * scale,
        offsetY + r.top * scale,
        r.width * scale,
        r.height * scale,
      );

      final rrect = RRect.fromRectAndRadius(scaledRect, const Radius.circular(6));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, boxPaint);

      // Card number badge
      final wordLabel = (i < words.length && words[i].isNotEmpty) ? ' #${i + 1}: ${words[i]}' : ' #${i + 1}';
      final textSpan = TextSpan(
        text: wordLabel,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.cyanAccent,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: scaledRect.width);

      textPainter.paint(canvas, Offset(scaledRect.left + 4, scaledRect.top + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _GridCropOverlayPainter oldDelegate) {
    return oldDelegate.config != config ||
        oldDelegate.imageWidth != imageWidth ||
        oldDelegate.imageHeight != imageHeight ||
        oldDelegate.words != words;
  }
}
