import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Configuration for splitting a composite grid image into individual cards
class GridSplitConfig {
  final int rows;
  final int columns;

  /// Outer sheet margin / padding (0.0 to 0.10)
  final double outerMarginXPercent; // e.g. 0.02 (2% left and right edge of entire sheet)
  final double outerMarginYPercent; // e.g. 0.02 (2% top and bottom edge of entire sheet)

  /// Inter-card gap / gutter spacing (0.0 to 0.10)
  final double horizontalGutterPercent; // e.g. 0.018 (gap between card columns)
  final double verticalGutterPercent; // e.g. 0.022 (gap between card rows)

  /// Inner card safety inset (0.0 to 0.05) to eliminate neighbor border bleed
  final double innerInsetPercent; // e.g. 0.015 (1.5% trimmed inside the card border)

  /// Per-card vertical trims for illustration isolation
  final double topCardTrimPercent; // e.g. 0.16 to crop title header
  final double bottomCardTrimPercent; // e.g. 0.28 to crop definition footer

  /// Whether to normalize all cropped cards to identical target dimensions
  final bool normalizeDimensions;
  final int targetWidth;
  final int targetHeight;

  const GridSplitConfig({
    this.rows = 2,
    this.columns = 5,
    this.outerMarginXPercent = 0.02,
    this.outerMarginYPercent = 0.02,
    this.horizontalGutterPercent = 0.018,
    this.verticalGutterPercent = 0.022,
    this.innerInsetPercent = 0.015,
    this.topCardTrimPercent = 0.0,
    this.bottomCardTrimPercent = 0.0,
    this.normalizeDimensions = true,
    this.targetWidth = 400,
    this.targetHeight = 550,
  });

  GridSplitConfig copyWith({
    int? rows,
    int? columns,
    double? outerMarginXPercent,
    double? outerMarginYPercent,
    double? horizontalGutterPercent,
    double? verticalGutterPercent,
    double? innerInsetPercent,
    double? topCardTrimPercent,
    double? bottomCardTrimPercent,
    bool? normalizeDimensions,
    int? targetWidth,
    int? targetHeight,
  }) {
    return GridSplitConfig(
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      outerMarginXPercent: outerMarginXPercent ?? this.outerMarginXPercent,
      outerMarginYPercent: outerMarginYPercent ?? this.outerMarginYPercent,
      horizontalGutterPercent: horizontalGutterPercent ?? this.horizontalGutterPercent,
      verticalGutterPercent: verticalGutterPercent ?? this.verticalGutterPercent,
      innerInsetPercent: innerInsetPercent ?? this.innerInsetPercent,
      topCardTrimPercent: topCardTrimPercent ?? this.topCardTrimPercent,
      bottomCardTrimPercent: bottomCardTrimPercent ?? this.bottomCardTrimPercent,
      normalizeDimensions: normalizeDimensions ?? this.normalizeDimensions,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
    );
  }

  /// Calculates the crop rectangles for each cell in the composite image.
  /// Shared between UI live overlay painter and the actual image splitter.
  static List<Rect> computeCellRects({
    required double imageWidth,
    required double imageHeight,
    required GridSplitConfig config,
  }) {
    final cols = config.columns.clamp(1, 20);
    final rows = config.rows.clamp(1, 20);

    final leftPad = imageWidth * config.outerMarginXPercent;
    final rightPad = imageWidth * config.outerMarginXPercent;
    final topPad = imageHeight * config.outerMarginYPercent;
    final bottomPad = imageHeight * config.outerMarginYPercent;

    final totalHGutter = (cols - 1) * (imageWidth * config.horizontalGutterPercent);
    final availableWidth = (imageWidth - leftPad - rightPad - totalHGutter).clamp(10.0, imageWidth);
    final cellWidth = availableWidth / cols;
    final hGutter = imageWidth * config.horizontalGutterPercent;

    final totalVGutter = (rows - 1) * (imageHeight * config.verticalGutterPercent);
    final availableHeight = (imageHeight - topPad - bottomPad - totalVGutter).clamp(10.0, imageHeight);
    final cellHeight = availableHeight / rows;
    final vGutter = imageHeight * config.verticalGutterPercent;

    final List<Rect> rects = [];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rawLeft = leftPad + c * (cellWidth + hGutter);
        final rawTop = topPad + r * (cellHeight + vGutter);

        // Safety inset inside each cell boundary to prevent neighbor card bleed
        final insetX = cellWidth * config.innerInsetPercent;
        final insetY = cellHeight * config.innerInsetPercent;

        // Card header/footer trims
        final topTrim = cellHeight * config.topCardTrimPercent;
        final bottomTrim = cellHeight * config.bottomCardTrimPercent;

        final cropLeft = (rawLeft + insetX).clamp(0.0, imageWidth - 1);
        final cropTop = (rawTop + insetY + topTrim).clamp(0.0, imageHeight - 1);
        final cropW = (cellWidth - 2 * insetX).clamp(10.0, imageWidth - cropLeft);
        final cropH = (cellHeight - 2 * insetY - topTrim - bottomTrim).clamp(10.0, imageHeight - cropTop);

        rects.add(Rect.fromLTWH(cropLeft, cropTop, cropW, cropH));
      }
    }

    return rects;
  }
}

/// Represents one cropped card resulting from a grid split
class CroppedCard {
  final int index;
  final int row;
  final int col;
  final Uint8List bytes;
  final int width;
  final int height;
  String word;

  CroppedCard({
    required this.index,
    required this.row,
    required this.col,
    required this.bytes,
    required this.width,
    required this.height,
    this.word = '',
  });
}

/// Service that performs hardware-accelerated grid image splitting and storage
class GridImageSplitterService {
  static final GridImageSplitterService instance = GridImageSplitterService._init();
  GridImageSplitterService._init();

  /// Splits an image in memory into grid cells based on the given configuration
  Future<List<CroppedCard>> splitImage({
    required Uint8List imageBytes,
    required GridSplitConfig config,
    List<String>? initialWords,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final sourceImage = frame.image;

    final srcWidth = sourceImage.width.toDouble();
    final srcHeight = sourceImage.height.toDouble();

    final cols = config.columns.clamp(1, 20);
    final rects = GridSplitConfig.computeCellRects(
      imageWidth: srcWidth,
      imageHeight: srcHeight,
      config: config,
    );

    final List<CroppedCard> cards = [];

    for (int i = 0; i < rects.length; i++) {
      final srcRect = rects[i];
      final r = i ~/ cols;
      final c = i % cols;

      final int outW = config.normalizeDimensions ? config.targetWidth : srcRect.width.round();
      final int outH = config.normalizeDimensions ? config.targetHeight : srcRect.height.round();
      final dstRect = Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, dstRect);

      canvas.drawImageRect(
        sourceImage,
        srcRect,
        dstRect,
        Paint()..filterQuality = FilterQuality.high,
      );

      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(outW, outH);
      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final word = (initialWords != null && i < initialWords.length)
            ? initialWords[i].trim()
            : '';

        cards.add(CroppedCard(
          index: i,
          row: r,
          col: c,
          bytes: byteData.buffer.asUint8List(),
          width: outW,
          height: outH,
          word: word,
        ));
      }
    }

    return cards;
  }

  /// Saves a cropped picture to disk with a deterministic name to avoid duplication
  Future<String> saveCroppedPicture({
    required String word,
    required Uint8List bytes,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();
    final customCardsDir = Directory(
      p.join(appDir.path, 'USE_Advance_Picture_Dictionary', 'custom_cards'),
    );

    if (!customCardsDir.existsSync()) {
      await customCardsDir.create(recursive: true);
    }

    // Deterministic sanitize: "Abandon" -> "abandon_card.png"
    // This strictly overwrites previous custom picture for this word, avoiding orphaned duplicates
    final safeName = word.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    final filePath = p.join(customCardsDir.path, '${safeName}_card.png');
    final file = File(filePath);
    await file.writeAsBytes(bytes, flush: true);

    return filePath;
  }
}
