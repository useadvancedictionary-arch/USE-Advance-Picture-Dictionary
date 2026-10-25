import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../services/picture_database_service.dart';
import 'grid_picture_import_screen.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  final TextEditingController _csvController = TextEditingController();
  bool _isImporting = false;
  bool _isDragging = false;
  String? _statusMessage;
  Uint8List? _loadedXlsxBytes;

  static const String _templateCsv = '''Word,Part,English Meaning,Synonym,Antonym,Picture / Image Link,Category,Examples
Helicopter,Noun,An aircraft with horizontally rotating blades capable of vertical flight,"chopper, whirlybird",airplane,Google Images,Vehicles & Transport,The rescue helicopter landed safely atop the hospital roof.
Submarine,Noun,A vessel capable of operating underwater,"sub, underwater craft",surface ship,Google Images,Vehicles & Transport,The submarine navigated silently beneath the Arctic sea ice.
Koala,Noun,A tree-dwelling Australian marsupial with thick grey fur and round ears,marsupial,carnivore,Google Images,Animals & Birds,The koala slept peacefully on the branch of a eucalyptus tree.''';

  Future<void> _loadFileFromPath(String filePath) async {
    try {
      final fileName = filePath.split(RegExp(r'[/\\]')).last.toLowerCase();
      final file = File(filePath);

      if (fileName.endsWith('.xlsx')) {
        // Native Excel (.xlsx) handling
        final bytes = await file.readAsBytes();
        final rows = PictureDatabaseService.readXlsxSheetRows(bytes);

        // Convert rows to display preview in text area
        final previewBuffer = StringBuffer();
        for (final row in rows) {
          previewBuffer.writeln(row.map((c) {
            if (c.contains(',') || c.contains('\n') || c.contains('"')) {
              return '"${c.replaceAll('"', '""')}"';
            }
            return c;
          }).join(','));
        }

        if (mounted) {
          setState(() {
            _loadedXlsxBytes = bytes;
            _csvController.text = previewBuffer.toString();
            _statusMessage = 'Loaded Excel spreadsheet "$fileName" (${rows.length} rows)';
          });
        }
      } else if (fileName.endsWith('.csv') || fileName.endsWith('.txt')) {
        // CSV / TXT text handling
        final content = await file.readAsString();
        if (mounted) {
          setState(() {
            _loadedXlsxBytes = null;
            _csvController.text = content;
            _statusMessage = 'Loaded "$fileName"';
          });
        }
      } else if (fileName.endsWith('.png') || fileName.endsWith('.jpg') || fileName.endsWith('.jpeg') || fileName.endsWith('.webp')) {
        // Image was dropped on BulkImportScreen - open Grid Picture Splitter with it!
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GridPictureImportScreen(initialImagePath: filePath),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please drop an Excel (.xlsx), CSV (.csv), or image (.png, .jpg) file.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading dropped file: $e')),
        );
      }
    }
  }

  Future<void> _pickAndLoadFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'txt'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        await _loadFileFromPath(files.first.path!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reading file: $e')),
        );
      }
    }
  }

  Future<void> _runImport() async {
    final text = _csvController.text.trim();
    if (text.isEmpty && _loadedXlsxBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick an Excel (.xlsx) / CSV file or paste rows first.')),
      );
      return;
    }

    setState(() {
      _isImporting = true;
      _statusMessage = 'Importing entries...';
    });

    try {
      int total = 0;
      if (_loadedXlsxBytes != null) {
        total = await PictureDatabaseService.instance.importFromXlsx(_loadedXlsxBytes!);
      } else {
        total = await PictureDatabaseService.instance.importFromCsv(text);
      }

      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'Successfully imported $total entries!';
        });
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('Import Successful! 🎉'),
            content: Text('Successfully imported $total picture vocabulary entries into the dictionary.'),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'Import failed: $e';
        });
      }
    }
  }

  void _loadSampleTemplate() {
    setState(() {
      _loadedXlsxBytes = null;
      _csvController.text = _templateCsv;
      _statusMessage = 'Sample template loaded. Tap "Start Import" to test!';
    });
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Import Vocabulary'),
        actions: [
          IconButton(
            tooltip: 'Split Picture Grid Images',
            icon: const Icon(Icons.grid_on_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GridPictureImportScreen()),
              );
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Template'),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _templateCsv));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template copied to clipboard')),
              );
            },
          ),
        ],
      ),
      body: DropTarget(
        onDragEntered: (detail) => setState(() => _isDragging = true),
        onDragExited: (detail) => setState(() => _isDragging = false),
        onDragDone: (detail) async {
          setState(() => _isDragging = false);
          if (detail.files.isEmpty) return;
          await _loadFileFromPath(detail.files.first.path);
        },
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quick shortcut to Grid Picture Splitter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.teal.shade700, Colors.teal.shade500],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Have a Composite Picture Grid (e.g. 10 cards in 1 image)?',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Drag & drop it directly here or open splitter to auto-crop pictures with zero duplicates.',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.teal.shade900,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const GridPictureImportScreen()),
                                );
                              },
                              child: const Text('Open Splitter', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Header instruction card
                      Card(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: _isDragging ? theme.colorScheme.primary : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.table_chart_rounded, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Import from Microsoft Excel (.xlsx) or CSV (with Drag & Drop)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Drag & drop your native Excel (.xlsx), CSV (.csv) file, or picture sheet anywhere into this window.\nHeaders recognized: Word, Part, English Meaning, Synonym, Antonym, Picture / Image Link, Category, Examples.',
                                style: TextStyle(fontSize: 13, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Action buttons: Pick File & Load Sample
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.file_open_rounded),
                              label: const Text('Pick / Drop Excel (.xlsx) or CSV File'),
                              onPressed: _isImporting ? null : _pickAndLoadFile,
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Load Sample'),
                            onPressed: _isImporting ? null : _loadSampleTemplate,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Text Area for preview/paste
                      Expanded(
                        child: TextField(
                          controller: _csvController,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Excel preview, drag & drop file, or paste rows here...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                            fillColor: theme.colorScheme.surface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_statusMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _statusMessage!.contains('failed') ? Colors.red : Colors.green.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Import Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: _isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.cloud_upload_rounded),
                        label: Text(
                          _isImporting ? 'Importing Data...' : 'Start Import into Dictionary',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        onPressed: _isImporting ? null : _runImport,
                      ),
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
                            'Drop File Here!',
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Supports Excel (.xlsx), CSV (.csv), or Image sheets (.png, .jpg)',
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
}
