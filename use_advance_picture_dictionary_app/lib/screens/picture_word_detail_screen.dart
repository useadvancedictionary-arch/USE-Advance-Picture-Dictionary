import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/picture_word_entry.dart';
import '../services/interlink_service.dart';
import '../services/picture_database_service.dart';
import '../widgets/picture_card_image.dart';
import '../services/admin_auth_service.dart';
import 'picture_crop_editor_screen.dart';
import '../services/favorites_history_service.dart';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import '../services/firestore_sync_service.dart';
import '../services/cloud_image_service.dart';
import '../services/smart_auto_tagger.dart';
import '../services/card_asset_pack_service.dart';
import '../services/freemium_gatekeeper.dart';
import '../widgets/pro_paywall_sheet.dart';

class PictureWordDetailScreen extends StatefulWidget {
  final PictureWordEntry entry;
  final List<PictureWordEntry>? entriesList;
  final int? initialIndex;

  const PictureWordDetailScreen({
    super.key,
    required this.entry,
    this.entriesList,
    this.initialIndex,
  });

  @override
  State<PictureWordDetailScreen> createState() => _PictureWordDetailScreenState();
}

class _PictureWordDetailScreenState extends State<PictureWordDetailScreen> {
  late PictureWordEntry _currentEntry;
  List<PictureWordEntry>? _entriesList;
  int? _currentIndex;

  PictureWordEntry? _prevEntry;
  PictureWordEntry? _nextEntry;

  final FlutterTts _tts = FlutterTts();
  bool _isPlayingAudio = false;

  @override
  void initState() {
    super.initState();
    _currentEntry = widget.entry;
    _entriesList = widget.entriesList != null ? List.from(widget.entriesList!) : null;
    _currentIndex = widget.initialIndex;
    _initTts();
    FavoritesHistoryService.instance.recordHistory(widget.entry.word);
    _loadAdjacentEntries();

    // Verify word is unlocked; if locked, show paywall sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !FreemiumGatekeeper.isWordUnlocked(_currentEntry.word)) {
        ProPaywallSheet.show(context, triggeredWord: _currentEntry.word).then((bought) {
          if (bought != true && mounted && !FreemiumGatekeeper.isWordUnlocked(_currentEntry.word)) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  Future<void> _loadAdjacentEntries() async {
    

    PictureWordEntry? prev;
    PictureWordEntry? next;

    // 1. If we have a list of entries (e.g. from search, filter, or grid)
    if (_entriesList != null && _entriesList!.isNotEmpty) {
      if (_currentIndex == null ||
          _currentIndex! < 0 ||
          _currentIndex! >= _entriesList!.length ||
          _entriesList![_currentIndex!].word.toLowerCase() != _currentEntry.word.toLowerCase()) {
        _currentIndex = _entriesList!.indexWhere(
          (e) => e.word.toLowerCase() == _currentEntry.word.toLowerCase(),
        );
      }

      if (_currentIndex != null && _currentIndex! != -1) {
        if (_currentIndex! > 0) {
          prev = _entriesList![_currentIndex! - 1];
        }
        if (_currentIndex! < _entriesList!.length - 1) {
          next = _entriesList![_currentIndex! + 1];
        }
      }
    }

    // 2. Fallback to database alphabetical lookup if not in a list or at the boundary
    prev ??= await PictureDatabaseService.instance.getPreviousEntry(_currentEntry.word);
    next ??= await PictureDatabaseService.instance.getNextEntry(_currentEntry.word);

    if (mounted) {
      setState(() {
        _prevEntry = prev;
        _nextEntry = next;
        
      });
    }
  }

  void _goToPrevious() {
    if (_prevEntry != null) {
      _switchToEntry(_prevEntry!);
    }
  }

  void _goToNext() {
    if (_nextEntry != null) {
      _switchToEntry(_nextEntry!);
    }
  }

  void _switchToEntry(PictureWordEntry entry) {
    if (!FreemiumGatekeeper.isWordUnlocked(entry.word)) {
      ProPaywallSheet.show(context, triggeredWord: entry.word);
      return;
    }
    _tts.stop();
    setState(() {
      _currentEntry = entry;
      _isPlayingAudio = false;
      if (_entriesList != null) {
        final idx = _entriesList!.indexWhere(
          (e) => e.word.toLowerCase() == entry.word.toLowerCase(),
        );
        if (idx != -1) _currentIndex = idx;
      }
    });
    FavoritesHistoryService.instance.recordHistory(entry.word);
    _loadAdjacentEntries();
  }

  void _initTts() {
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
    _tts.setErrorHandler((_) {
      if (mounted) setState(() => _isPlayingAudio = false);
    });
  }

    bool _isReviewActionInProgress = false;
  String _reviewStatusMessage = '';

  Future<void> _keepPicture() async {
    final unlocked = await AdminAuthService.instance.ensureAdminUnlocked(context);
    if (!unlocked || !mounted) return;

    setState(() {
      _isReviewActionInProgress = true;
      _reviewStatusMessage = 'Saving and syncing picture to cloud...';
    });

    try {
      String finalUrl = _currentEntry.imageUrl;

      // 1. If it's an AI or ephemeral web image, download & upload to permanent Firebase Storage
      if (finalUrl.startsWith('http://') || finalUrl.startsWith('https://')) {
        if (!finalUrl.contains('firebasestorage.googleapis.com')) {
          final cloudUrl = await CloudImageService.instance.uploadNetworkImage(
            finalUrl,
            word: _currentEntry.word,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        }
      } else if (!finalUrl.startsWith('assets/')) {
        // Local file
        final localFile = File(finalUrl);
        if (await localFile.exists()) {
          final cloudUrl = await CloudImageService.instance.uploadLocalFile(
            localFile,
            word: _currentEntry.word,
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            finalUrl = cloudUrl;
          }
        }
      }

      final updatedEntry = _currentEntry.copyWith(
        imageUrl: finalUrl,
        thumbnailUrl: finalUrl,
      );

      // Save to local database
      await PictureDatabaseService.instance.insertOrUpdateEntry(updatedEntry);

      // Push to Firestore for all users
      await FirestoreSyncService.instance.pushPictureEntry(updatedEntry);

      if (mounted) {
        setState(() {
          _currentEntry = updatedEntry;
          _isReviewActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Picture for "${_currentEntry.word}" confirmed and synced to all users!'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReviewActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to sync picture: $e')),
        );
      }
    }
  }

  Future<void> _replacePicture() async {
    final unlocked = await AdminAuthService.instance.ensureAdminUnlocked(context);
    if (!unlocked || !mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                leading: Icon(Icons.swap_horiz_rounded, color: Colors.deepOrange),
                title: Text('Replace Picture', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                subtitle: Text('Choose how to replace this card picture for all users'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined, color: Colors.blueAccent),
                title: const Text('Pick Image from Device'),
                subtitle: const Text('Select a JPG or PNG picture from your files'),
                onTap: () async {
                  Navigator.pop(ctx);
                  _pickAndApplyImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.crop_rounded, color: Colors.teal),
                title: const Text('Crop / Edit Current Picture'),
                subtitle: const Text('Open crop & trim editor for this card'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openCropEditor();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndApplyImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result.isEmpty) return;

      final path = result.first.path;
      if (path == null) return;

      setState(() {
        _isReviewActionInProgress = true;
        _reviewStatusMessage = 'Uploading new picture to cloud...';
      });

      final file = File(path);
      final cloudUrl = await CloudImageService.instance.uploadLocalFile(
        file,
        word: _currentEntry.word,
      );

      final finalUrl = cloudUrl ?? path;
      final updatedEntry = _currentEntry.copyWith(
        imageUrl: finalUrl,
        thumbnailUrl: finalUrl,
      );

      await PictureDatabaseService.instance.insertOrUpdateEntry(updatedEntry);
      await FirestoreSyncService.instance.pushPictureEntry(updatedEntry);

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (mounted) {
        setState(() {
          _currentEntry = updatedEntry;
          _isReviewActionInProgress = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Replaced picture for "${_currentEntry.word}" and synced to all users!'),
            backgroundColor: Colors.teal.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isReviewActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to replace picture: $e')),
        );
      }
    }
  }

  void _regenerateAiPreview() {
    final newUrl = SmartAutoTagger.buildAiFlashcardUrl(
      word: _currentEntry.word,
      meaning: _currentEntry.englishMeaning,
      pos: _currentEntry.partOfSpeech,
      seed: Random().nextInt(999999),
    );
    setState(() {
      _currentEntry = _currentEntry.copyWith(
        imageUrl: newUrl,
        thumbnailUrl: newUrl,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Generated new AI preview for "${_currentEntry.word}". Tap "Keep Picture" if related!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAdminReviewCard(ThemeData theme) {
    if (!AdminAuthService.instance.isAdminUnlocked) {
      return const SizedBox.shrink();
    }
    final isCloud = _currentEntry.imageUrl.contains('firebasestorage.googleapis.com');
    final isAsset = _currentEntry.imageUrl.startsWith('assets/');
    final isAi = _currentEntry.imageUrl.contains('pollinations');

    final badgeColor = isCloud
        ? Colors.teal
        : isAsset
            ? const Color(0xFF2E3192)
            : isAi
                ? Colors.deepOrange
                : Colors.purple;

    final badgeLabel = isCloud
        ? 'Cloud Synced ✓'
        : isAsset
            ? 'Official Bundled ✓'
            : isAi
                ? 'AI Preview ⚡'
                : 'Custom Card';

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 18, color: badgeColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Picture Review & Multi-User Sync',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (_isReviewActionInProgress) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _reviewStatusMessage,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 15),
                  label: const Text('Keep Picture', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _keepPicture,
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepOrange,
                    side: const BorderSide(color: Colors.deepOrange),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                  label: const Text('Replace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _replacePicture,
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E3192),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 14),
                  label: const Text('Regenerate AI', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                  onPressed: _regenerateAiPreview,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCropEditor() async {
    final unlocked = await AdminAuthService.instance.ensureAdminUnlocked(context);
    if (!unlocked || !mounted) return;

    final updated = await Navigator.push<PictureWordEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => PictureCropEditorScreen(entry: _currentEntry),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _currentEntry = updated;
      });
    }
  }

  void _copyText() {
    final buffer = StringBuffer();
    buffer.writeln('${_currentEntry.word} (${_currentEntry.partOfSpeech})');
    if (_currentEntry.category.isNotEmpty && _currentEntry.category != 'General') {
      buffer.writeln('Category: ${_currentEntry.category}');
    }
    buffer.writeln('\nMeaning:');
    buffer.writeln(_currentEntry.englishMeaning);

    if (_currentEntry.exampleSentence != null && _currentEntry.exampleSentence!.isNotEmpty) {
      buffer.writeln('\nExample:');
      buffer.writeln('“${_currentEntry.exampleSentence}”');
    }

    if (_currentEntry.synonyms.isNotEmpty) {
      buffer.writeln('\nSynonyms: ${_currentEntry.synonyms.join(", ")}');
    }

    if (_currentEntry.antonyms.isNotEmpty) {
      buffer.writeln('Antonyms: ${_currentEntry.antonyms.join(", ")}');
    }

    buffer.writeln('\n— USE Advance Picture Dictionary');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Word & meaning for "${_currentEntry.word}" copied to clipboard!'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    }
  }

  Future<void> _copyPicture() async {
    try {
      String? localFilePath;
      final cleanUrl = _currentEntry.imageUrl.trim();

      if (cleanUrl.startsWith('assets/')) {
        final padBytes = await CardAssetPackService.instance.loadCardBytes(cleanUrl);
        final Uint8List bytes;
        if (padBytes != null) {
          bytes = padBytes;
        } else {
          final byteData = await rootBundle.load(cleanUrl);
          bytes = byteData.buffer.asUint8List();
        }
        final tempDir = await getTemporaryDirectory();
        final safeWord = _currentEntry.word.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
        final file = File('${tempDir.path}/${safeWord}_card.png');
        await file.writeAsBytes(bytes, flush: true);
        localFilePath = file.path;
      } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(cleanUrl));
          final response = await request.close();
          final bytes = await consolidateHttpClientResponseBytes(response);
          final tempDir = await getTemporaryDirectory();
          final safeWord = _currentEntry.word.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          final file = File('${tempDir.path}/${safeWord}_card.png');
          await file.writeAsBytes(bytes, flush: true);
          localFilePath = file.path;
        } finally {
          client.close();
        }
      } else {
        final cleanPath = cleanUrl.replaceFirst('file://', '');
        final file = File(cleanPath);
        if (await file.exists()) {
          localFilePath = file.path;
        }
      }

      if (localFilePath != null && File(localFilePath).existsSync()) {
        if (!kIsWeb && Platform.isWindows) {
          final absPath = File(localFilePath).absolute.path.replaceAll('/', '\\');
          try {
            await Process.run('powershell', [
              '-NoProfile',
              '-ExecutionPolicy',
              'Bypass',
              '-Command',
              '''
              Add-Type -AssemblyName System.Windows.Forms;
              Add-Type -AssemblyName System.Drawing;
              \$data = New-Object System.Windows.Forms.DataObject;
              \$img = [System.Drawing.Image]::FromFile('$absPath');
              \$data.SetImage(\$img);
              \$files = New-Object System.Collections.Specialized.StringCollection;
              [void]\$files.Add('$absPath');
              \$data.SetFileDropList(\$files);
              [System.Windows.Forms.Clipboard]::SetDataObject(\$data, \$true);
              ''',
            ]);
          } catch (e) {
            debugPrint('Windows PowerShell copy error: $e');
          }
        } else {
          // On non-Windows platforms, set clipboard text as fallback
          await Clipboard.setData(ClipboardData(text: localFilePath));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Picture of "${_currentEntry.word}" copied to clipboard! Paste with Ctrl+V.'),
              backgroundColor: Colors.teal.shade700,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Picture file could not be accessed.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy picture error: $e')),
        );
      }
    }
  }

  Future<void> _copyBoth() async {
    await _copyPicture();
    _copyText();
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
      _switchToEntry(entry);
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

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
        const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              _currentEntry.word,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // Previous (<) Word Button in AppBar
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                tooltip: _prevEntry != null
                    ? 'Previous: "${_prevEntry!.word}" (<)'
                    : 'Previous Word (<)',
                onPressed: _prevEntry != null ? _goToPrevious : null,
              ),
              // Next (>) Word Button in AppBar
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                tooltip: _nextEntry != null
                    ? 'Next: "${_nextEntry!.word}" (>)'
                    : 'Next Word (>)',
                onPressed: _nextEntry != null ? _goToNext : null,
              ),
              const SizedBox(width: 4),
              AnimatedBuilder(
                animation: FavoritesHistoryService.instance,
                builder: (context, _) {
                  final isFav = FavoritesHistoryService.instance.isFavorite(_currentEntry.word);
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFav ? Colors.redAccent : null,
                    ),
                    tooltip: isFav ? 'Remove from Favourites' : 'Add to Favourites',
                    onPressed: () async {
                      final nowFav = await FavoritesHistoryService.instance.toggleFavorite(_currentEntry.word);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            duration: const Duration(seconds: 1),
                            content: Text(
                              nowFav
                                  ? 'Added "${_currentEntry.word}" to Favourites ❤️'
                                  : 'Removed "${_currentEntry.word}" from Favourites',
                            ),
                          ),
                        );
                      }
                    },
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.copy_rounded),
                tooltip: 'Copy Text & Picture',
                onSelected: (val) {
                  if (val == 'text') _copyText();
                  if (val == 'picture') _copyPicture();
                  if (val == 'both') _copyBoth();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'text',
                    child: Row(
                      children: [
                        Icon(Icons.text_fields_rounded, size: 20, color: Color(0xFF0072FF)),
                        SizedBox(width: 10),
                        Text('Copy Definition & Text'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'picture',
                    child: Row(
                      children: [
                        Icon(Icons.image_outlined, size: 20, color: Colors.teal),
                        SizedBox(width: 10),
                        Text('Copy Picture (Image File)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'both',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy_rounded, size: 20, color: Colors.deepOrange),
                        SizedBox(width: 10),
                        Text('Copy Both (Text + Picture)'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isPlayingAudio ? Icons.volume_up : Icons.volume_up_outlined,
                  color: _isPlayingAudio ? theme.colorScheme.primary : null,
                ),
                tooltip: 'Listen Pronunciation',
                onPressed: _speakWord,
              ),
              if (AdminAuthService.instance.isAdminUnlocked)
                IconButton(
                  icon: const Icon(Icons.crop_rounded),
                  tooltip: 'Admin: Edit / Crop Picture',
                  onPressed: _openCropEditor,
                ),
              IconButton(
                icon: const Icon(Icons.fullscreen),
                tooltip: 'View Full Picture',
                onPressed: _openFullScreenViewer,
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: theme.dividerColor.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Previous Word Button (<)
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _prevEntry != null ? _goToPrevious : null,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _prevEntry != null ? '< ${_prevEntry!.word}' : '< Previous',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          if (_prevEntry != null && !FreemiumGatekeeper.isWordUnlocked(_prevEntry!.word)) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFFFB703)),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Next Word Button (>)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _nextEntry != null ? _goToNext : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _nextEntry != null ? '${_nextEntry!.word} >' : 'Next >',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                          if (_nextEntry != null && !FreemiumGatekeeper.isWordUnlocked(_nextEntry!.word)) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.lock_rounded, size: 12, color: Color(0xFFFFB703)),
                          ],
                          const SizedBox(width: 5),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity != null) {
                if (details.primaryVelocity! > 200) {
                  // Swipe Right -> Previous Word (<)
                  _goToPrevious();
                } else if (details.primaryVelocity! < -200) {
                  // Swipe Left -> Next Word (>)
                  _goToNext();
                }
              }
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 800;

                if (isWide) {
                  final bottomPad = MediaQuery.of(context).padding.bottom;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: HD Picture card
                      Expanded(
                        flex: 5,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildImageCard(isWide),
                              _buildAdminReviewCard(theme),
                            ],
                          ),
                        ),
                      ),
                      // Vertical divider
                      const VerticalDivider(width: 1),
                      // Right column: Word details
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
                          child: _buildDetailsContent(theme, posColor),
                        ),
                      ),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      16 + MediaQuery.of(context).padding.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildImageCard(isWide),
                        _buildAdminReviewCard(theme),
                        const SizedBox(height: 20),
                        _buildDetailsContent(theme, posColor),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
        ),
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
          // Copy Picture badge on top-right
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: _copyPicture,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.68),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, color: Colors.white, size: 13),
                    SizedBox(width: 5),
                    Text('Copy Picture', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
          // Admin Edit / Crop badge on bottom-left (only visible if admin is unlocked)
          if (AdminAuthService.instance.isAdminUnlocked)
            Positioned(
              left: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: _openCropEditor,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF041530).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.7), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.crop_rounded, color: Color(0xFF00E5FF), size: 15),
                      SizedBox(width: 5),
                      Text(
                        'Edit / Crop',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
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
            const SizedBox(width: 4),
            AnimatedBuilder(
              animation: FavoritesHistoryService.instance,
              builder: (context, _) {
                final isFav = FavoritesHistoryService.instance.isFavorite(_currentEntry.word);
                return IconButton(
                  icon: Icon(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFav ? Colors.redAccent : Colors.grey,
                  ),
                  tooltip: isFav ? 'Remove from Favourites' : 'Add to Favourites',
                  onPressed: () async {
                    final nowFav = await FavoritesHistoryService.instance.toggleFavorite(_currentEntry.word);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          duration: const Duration(seconds: 1),
                          content: Text(
                            nowFav
                                ? 'Added "${_currentEntry.word}" to Favourites ❤️'
                                : 'Removed "${_currentEntry.word}" from Favourites',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
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
                    const Expanded(
                      child: Text(
                        'English Meaning',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      tooltip: 'Copy Word & Meaning',
                      onPressed: _copyText,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _currentEntry.englishMeaning,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                if (_currentEntry.exampleSentence != null && _currentEntry.exampleSentence!.isNotEmpty) ...[
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

