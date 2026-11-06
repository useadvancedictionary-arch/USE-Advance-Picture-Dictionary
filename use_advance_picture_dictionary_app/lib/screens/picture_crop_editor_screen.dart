import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/picture_word_entry.dart';
import '../services/picture_database_service.dart';
import '../services/firestore_sync_service.dart';
import '../services/cloud_image_service.dart';

class PictureCropEditorScreen extends StatefulWidget {
  final PictureWordEntry entry;

  const PictureCropEditorScreen({super.key, required this.entry});

  @override
  State<PictureCropEditorScreen> createState() => _PictureCropEditorScreenState();
}

class _PictureCropEditorScreenState extends State<PictureCropEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  ui.Image? _decodedImage;

  // Trim percentages (0.0 = 0%, 0.40 = 40% cut)
  double _trimLeft = 0.0;
  double _trimRight = 0.0;
  double _trimTop = 0.0;
  double _trimBottom = 0.0;

  bool _showLiveCardPreview = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage([Uint8List? directBytes]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Uint8List bytes;
      if (directBytes != null) {
        bytes = directBytes;
      } else {
        bytes = await _fetchBytesForUrl(widget.entry.imageUrl);
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final img = frame.image;

      if (!mounted) return;
      setState(() {
        _decodedImage = img;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load picture: $e';
        _isLoading = false;
      });
    }
  }

  Future<Uint8List> _fetchBytesForUrl(String url) async {
    final clean = url.trim();

    // 1. Asset
    if (clean.startsWith('assets/')) {
      final byteData = await rootBundle.load(clean);
      return byteData.buffer.asUint8List();
    }

    // 2. Local File
    if (!kIsWeb &&
        (clean.startsWith('/') ||
            clean.contains(':\\') ||
            clean.contains(':/') ||
            clean.startsWith('file://') ||
            RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(clean))) {
      final filePath = clean.replaceFirst('file://', '');
      final file = File(filePath);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    }

    // 3. Remote URL
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(clean));
        final response = await request.close();
        if (response.statusCode == 200) {
          return await consolidateHttpClientResponseBytes(response);
        } else {
          throw Exception('HTTP error ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    }

    throw Exception('Unsupported or missing image path: $url');
  }

  Future<void> _pickNewImageFromDevice() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp', 'bmp'],
      );

      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          setState(() {
            _trimLeft = 0.0;
            _trimRight = 0.0;
            _trimTop = 0.0;
            _trimBottom = 0.0;
          });
          await _loadImage(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Loaded replacement picture from device.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick picture: $e')),
        );
      }
    }
  }

  void _resetTrims() {
    setState(() {
      _trimLeft = 0.0;
      _trimRight = 0.0;
      _trimTop = 0.0;
      _trimBottom = 0.0;
    });
  }

  void _applyPresetTrim({
    double? left,
    double? right,
    double? top,
    double? bottom,
    double? all,
  }) {
    setState(() {
      if (all != null) {
        _trimLeft = all.clamp(0.0, 0.45);
        _trimRight = all.clamp(0.0, 0.45);
        _trimTop = all.clamp(0.0, 0.45);
        _trimBottom = all.clamp(0.0, 0.45);
      } else {
        if (left != null) _trimLeft = left.clamp(0.0, 0.45);
        if (right != null) _trimRight = right.clamp(0.0, 0.45);
        if (top != null) _trimTop = top.clamp(0.0, 0.45);
        if (bottom != null) _trimBottom = bottom.clamp(0.0, 0.45);
      }
    });
  }

  Future<void> _saveAndApplyCrop() async {
    if (_decodedImage == null) return;
    setState(() => _isSaving = true);

    try {
      final img = _decodedImage!;
      final srcW = img.width.toDouble();
      final srcH = img.height.toDouble();

      final cropLeft = (srcW * _trimLeft).clamp(0.0, srcW - 10.0);
      final cropTop = (srcH * _trimTop).clamp(0.0, srcH - 10.0);
      final cropW = (srcW - cropLeft - (srcW * _trimRight)).clamp(10.0, srcW - cropLeft);
      final cropH = (srcH - cropTop - (srcH * _trimBottom)).clamp(10.0, srcH - cropTop);

      final srcRect = Rect.fromLTWH(cropLeft, cropTop, cropW, cropH);
      final dstRect = Rect.fromLTWH(0, 0, cropW, cropH);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dstRect);

      canvas.drawImageRect(
        img,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final outImage = await picture.toImage(cropW.round(), cropH.round());
      final byteData = await outImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode cropped image to PNG');
      }

      final pngBytes = byteData.buffer.asUint8List();

      // Save to application directory
      final appDir = await getApplicationDocumentsDirectory();
      final customCardsDir = Directory(
        p.join(appDir.path, 'USE_Advance_Picture_Dictionary', 'custom_cards'),
      );
      if (!customCardsDir.existsSync()) {
        await customCardsDir.create(recursive: true);
      }

      final safeName = widget.entry.word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(customCardsDir.path, '${safeName}_card_$timestamp.png');

      final file = File(filePath);
      await file.writeAsBytes(pngBytes, flush: true);

      // Invalidate Flutter image cache so the newly cropped image renders immediately
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      // Update database entry
      final updatedEntry = widget.entry.copyWith(
        imageUrl: filePath,
        thumbnailUrl: filePath,
      );
      await PictureDatabaseService.instance.updateEntry(updatedEntry);

      // Upload cropped image to Firebase Cloud Storage & Firestore in background for all users
      () async {
        try {
          final cloudUrl = await CloudImageService.instance.uploadImageBytes(
            pngBytes,
            word: widget.entry.word,
            format: 'png',
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            final cloudEntry = updatedEntry.copyWith(
              imageUrl: cloudUrl,
              thumbnailUrl: cloudUrl,
            );
            await FirestoreSyncService.instance.pushPictureEntry(cloudEntry);
            debugPrint('Cropped image synced to cloud for ${widget.entry.word}: $cloudUrl');
          } else {
            await FirestoreSyncService.instance.pushPictureEntry(updatedEntry);
          }
        } catch (e) {
          debugPrint('Error syncing cropped image to cloud: $e');
        }
      }();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully cropped and updated picture for "${widget.entry.word}"!'),
          backgroundColor: Colors.teal.shade700,
        ),
      );

      Navigator.pop(context, updatedEntry);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save cropped image: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit & Crop: ${widget.entry.word}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_decodedImage != null)
              Text(
                'Original: ${_decodedImage!.width} × ${_decodedImage!.height} px • Cropped: ${_computeCroppedSize()}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pick New Picture File',
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: _isLoading || _isSaving ? null : _pickNewImageFromDevice,
          ),
          IconButton(
            tooltip: 'Reset All Trims',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading || _isSaving ? null : _resetTrims,
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF041530),
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF041530)),
                    )
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(_isSaving ? 'Saving...' : 'Save & Apply', style: const TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _isLoading || _isSaving ? null : _saveAndApplyCrop,
            ),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  String _computeCroppedSize() {
    if (_decodedImage == null) return '';
    final srcW = _decodedImage!.width.toDouble();
    final srcH = _decodedImage!.height.toDouble();
    final outW = (srcW * (1.0 - _trimLeft - _trimRight)).round();
    final outH = (srcH * (1.0 - _trimTop - _trimBottom)).round();
    return '$outW × $outH px';
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 14),
            Text('Loading picture for cropping...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image_rounded, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Pick Image from Device to Replace'),
                onPressed: _pickNewImageFromDevice,
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Crop Canvas / Preview
              Expanded(
                flex: 6,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: _buildCanvasArea(theme),
                ),
              ),
              // Right: Trim Controls
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
                  child: _buildControlsArea(theme),
                ),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              // Upper: Crop Canvas Area (fixed height or aspect ratio)
              Expanded(
                flex: 5,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.9),
                  child: _buildCanvasArea(theme),
                ),
              ),
              // Lower: Trim Controls (scrollable)
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                  child: _buildControlsArea(theme),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildCanvasArea(ThemeData theme) {
    if (_decodedImage == null) return const SizedBox.shrink();

    final srcW = _decodedImage!.width.toDouble();
    final srcH = _decodedImage!.height.toDouble();

    return Column(
      children: [
        // Top Toolbar inside canvas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _showLiveCardPreview ? '👁️ Live Card Preview' : '✂️ Interactive Crop Frame',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.crop_rounded, size: 16),
                    label: Text('Crop View', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.preview_rounded, size: 16),
                    label: Text('Clean Preview', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_showLiveCardPreview},
                onSelectionChanged: (set) => setState(() => _showLiveCardPreview = set.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? const Color(0xFF00E5FF) : Colors.white10,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Visual Display
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _showLiveCardPreview
                  ? _buildLiveCleanPreview(srcW, srcH)
                  : _buildInteractiveCropFrame(srcW, srcH),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveCropFrame(double srcW, double srcH) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Compute scaled dimensions that fit within available box while preserving aspect ratio
        final containerW = constraints.maxWidth;
        final containerH = constraints.maxHeight;

        final imgAspect = srcW / srcH;
        final boxAspect = containerW / containerH;

        double renderW, renderH;
        if (boxAspect > imgAspect) {
          renderH = containerH;
          renderW = renderH * imgAspect;
        } else {
          renderW = containerW;
          renderH = renderW / imgAspect;
        }

        // Active crop dimensions in render pixels
        final leftOffset = renderW * _trimLeft;
        final rightOffset = renderW * _trimRight;
        final topOffset = renderH * _trimTop;
        final bottomOffset = renderH * _trimBottom;

        return SizedBox(
          width: renderW,
          height: renderH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Raw Source Image
              RawImage(
                image: _decodedImage,
                fit: BoxFit.fill,
              ),

              // 2. Dark Shaded Masks for trimmed-out edges
              // Top mask
              if (topOffset > 0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: topOffset,
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),
              // Bottom mask
              if (bottomOffset > 0)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: bottomOffset,
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),
              // Left mask
              if (leftOffset > 0)
                Positioned(
                  top: topOffset,
                  bottom: bottomOffset,
                  left: 0,
                  width: leftOffset,
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),
              // Right mask
              if (rightOffset > 0)
                Positioned(
                  top: topOffset,
                  bottom: bottomOffset,
                  right: 0,
                  width: rightOffset,
                  child: Container(color: Colors.black.withValues(alpha: 0.65)),
                ),

              // 3. Highlighted Crop Area Border
              Positioned(
                left: leftOffset,
                right: rightOffset,
                top: topOffset,
                bottom: bottomOffset,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF00E5FF), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                        spreadRadius: 1,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Grid rule-of-thirds lines (subtle)
                      Column(
                        children: [
                          const Spacer(),
                          Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
                          const Spacer(),
                          Divider(color: Colors.white.withValues(alpha: 0.35), height: 1),
                          const Spacer(),
                        ],
                      ),
                      Row(
                        children: [
                          const Spacer(),
                          VerticalDivider(color: Colors.white.withValues(alpha: 0.35), width: 1),
                          const Spacer(),
                          VerticalDivider(color: Colors.white.withValues(alpha: 0.35), width: 1),
                          const Spacer(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Interactive Drag Handles on Edges
              // Left Handle
              Positioned(
                left: (leftOffset - 15).clamp(0.0, renderW - 30.0),
                top: topOffset + (renderH - topOffset - bottomOffset) / 2 - 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final delta = details.primaryDelta! / renderW;
                      _trimLeft = (_trimLeft + delta).clamp(0.0, 0.45);
                    });
                  },
                  child: _buildHandleBadge(Icons.drag_indicator, Colors.tealAccent),
                ),
              ),

              // Right Handle
              Positioned(
                right: (rightOffset - 15).clamp(0.0, renderW - 30.0),
                top: topOffset + (renderH - topOffset - bottomOffset) / 2 - 20,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final delta = -details.primaryDelta! / renderW;
                      _trimRight = (_trimRight + delta).clamp(0.0, 0.45);
                    });
                  },
                  child: _buildHandleBadge(Icons.drag_indicator, Colors.tealAccent),
                ),
              ),

              // Top Handle
              Positioned(
                left: leftOffset + (renderW - leftOffset - rightOffset) / 2 - 20,
                top: (topOffset - 15).clamp(0.0, renderH - 30.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      final delta = details.primaryDelta! / renderH;
                      _trimTop = (_trimTop + delta).clamp(0.0, 0.45);
                    });
                  },
                  child: _buildHandleBadge(Icons.drag_indicator, Colors.amberAccent, isVertical: true),
                ),
              ),

              // Bottom Handle
              Positioned(
                left: leftOffset + (renderW - leftOffset - rightOffset) / 2 - 20,
                bottom: (bottomOffset - 15).clamp(0.0, renderH - 30.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    setState(() {
                      final delta = -details.primaryDelta! / renderH;
                      _trimBottom = (_trimBottom + delta).clamp(0.0, 0.45);
                    });
                  },
                  child: _buildHandleBadge(Icons.drag_indicator, Colors.amberAccent, isVertical: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandleBadge(IconData icon, Color color, {bool isVertical = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF041530),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
      ),
      child: Center(
        child: RotatedBox(
          quarterTurns: isVertical ? 1 : 0,
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildLiveCleanPreview(double srcW, double srcH) {
    final cropLeft = srcW * _trimLeft;
    final cropTop = srcH * _trimTop;
    final cropW = (srcW - cropLeft - (srcW * _trimRight)).clamp(10.0, srcW);
    final cropH = (srcH - cropTop - (srcH * _trimBottom)).clamp(10.0, srcH);

    return AspectRatio(
      aspectRatio: cropW / cropH,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: CustomPaint(
            painter: _CroppedImagePainter(
              image: _decodedImage!,
              srcRect: Rect.fromLTWH(cropLeft, cropTop, cropW, cropH),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlsArea(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick Notice Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0072FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0072FF).withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0072FF), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Adjust the trims below to remove extra neighbor border strips or crop precisely.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 1. Quick Presets
        const Text(
          'Quick Trimming Presets:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.border_clear_rounded, size: 16, color: Colors.teal),
              label: const Text('Clean Border Bleed (-2% All)'),
              onPressed: () => _applyPresetTrim(all: 0.02),
            ),
            ActionChip(
              avatar: const Icon(Icons.border_clear_rounded, size: 16, color: Colors.teal),
              label: const Text('Clean Border Bleed (-4% All)'),
              onPressed: () => _applyPresetTrim(all: 0.04),
            ),
            ActionChip(
              avatar: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.deepOrange),
              label: const Text('Cut Left Strip (+5%)'),
              onPressed: () => _applyPresetTrim(left: (_trimLeft + 0.05).clamp(0.0, 0.45)),
            ),
            ActionChip(
              avatar: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.deepOrange),
              label: const Text('Cut Right Strip (+5%)'),
              onPressed: () => _applyPresetTrim(right: (_trimRight + 0.05).clamp(0.0, 0.45)),
            ),
            ActionChip(
              avatar: const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.indigo),
              label: const Text('Cut Top Sliver (+5%)'),
              onPressed: () => _applyPresetTrim(top: (_trimTop + 0.05).clamp(0.0, 0.45)),
            ),
            ActionChip(
              avatar: const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.indigo),
              label: const Text('Cut Bottom Sliver (+5%)'),
              onPressed: () => _applyPresetTrim(bottom: (_trimBottom + 0.05).clamp(0.0, 0.45)),
            ),
            ActionChip(
              avatar: const Icon(Icons.refresh_rounded, size: 16, color: Colors.grey),
              label: const Text('Reset to 0%'),
              onPressed: _resetTrims,
            ),
          ],
        ),
        const Divider(height: 28),

        // 2. Individual Trim Sliders
        const Text(
          'Precision Trim Controls:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 12),

        // Left Trim
        _buildTrimSliderRow(
          label: 'Left Edge Trim',
          icon: Icons.border_left_rounded,
          color: Colors.teal,
          value: _trimLeft,
          onChanged: (val) => setState(() => _trimLeft = val),
        ),
        const SizedBox(height: 10),

        // Right Trim
        _buildTrimSliderRow(
          label: 'Right Edge Trim',
          icon: Icons.border_right_rounded,
          color: Colors.teal,
          value: _trimRight,
          onChanged: (val) => setState(() => _trimRight = val),
        ),
        const SizedBox(height: 10),

        // Top Trim
        _buildTrimSliderRow(
          label: 'Top Edge Trim',
          icon: Icons.border_top_rounded,
          color: Colors.deepOrange,
          value: _trimTop,
          onChanged: (val) => setState(() => _trimTop = val),
        ),
        const SizedBox(height: 10),

        // Bottom Trim
        _buildTrimSliderRow(
          label: 'Bottom Edge Trim',
          icon: Icons.border_bottom_rounded,
          color: Colors.deepOrange,
          value: _trimBottom,
          onChanged: (val) => setState(() => _trimBottom = val),
        ),
        const Divider(height: 28),

        // 3. Uniform All-Sides Trim Slider
        Row(
          children: [
            const Icon(Icons.crop_free_rounded, size: 20, color: Color(0xFF2E3192)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Uniform All-Sides Inset (Equal 4 Borders)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
            Text(
              '${((_trimLeft + _trimRight + _trimTop + _trimBottom) / 4 * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E3192)),
            ),
          ],
        ),
        Slider(
          value: ((_trimLeft + _trimRight + _trimTop + _trimBottom) / 4).clamp(0.0, 0.40),
          min: 0.0,
          max: 0.40,
          divisions: 80,
          activeColor: const Color(0xFF2E3192),
          onChanged: (val) => _applyPresetTrim(all: val),
        ),
        const SizedBox(height: 14),

        // 4. Replace with File from Device button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Replace With New Picture From Device'),
          onPressed: _pickNewImageFromDevice,
        ),
        const SizedBox(height: 14),

        // 5. Save Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E3192),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_rounded),
          label: Text(
            _isSaving ? 'Applying Crop...' : 'Save & Update Picture for "${widget.entry.word}"',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          onPressed: _isSaving ? null : _saveAndApplyCrop,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTrimSliderRow({
    required String label,
    required IconData icon,
    required Color color,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    final percentStr = (value * 100).toStringAsFixed(1);
    int px = 0;
    if (_decodedImage != null) {
      if (label.contains('Left') || label.contains('Right')) {
        px = (_decodedImage!.width * value).round();
      } else {
        px = (_decodedImage!.height * value).round();
      }
    }

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$percentStr% (${px}px)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                // Step down button (-1%)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  color: color,
                  tooltip: 'Decrease 1%',
                  onPressed: () => onChanged((value - 0.01).clamp(0.0, 0.45)),
                ),
                Expanded(
                  child: Slider(
                    value: value.clamp(0.0, 0.45),
                    min: 0.0,
                    max: 0.45,
                    divisions: 90,
                    activeColor: color,
                    onChanged: onChanged,
                  ),
                ),
                // Step up button (+1%)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: color,
                  tooltip: 'Increase 1%',
                  onPressed: () => onChanged((value + 0.01).clamp(0.0, 0.45)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CroppedImagePainter extends CustomPainter {
  final ui.Image image;
  final Rect srcRect;

  _CroppedImagePainter({required this.image, required this.srcRect});

  @override
  void paint(Canvas canvas, Size size) {
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(
      image,
      srcRect,
      dstRect,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _CroppedImagePainter oldDelegate) {
    return oldDelegate.image != image || oldDelegate.srcRect != srcRect;
  }
}

