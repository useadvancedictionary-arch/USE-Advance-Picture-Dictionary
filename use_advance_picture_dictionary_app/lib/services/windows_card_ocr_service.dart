import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class DetectedCardOcr {
  final int index;
  final int row;
  final int column;
  final String title;
  final String meaning;

  DetectedCardOcr({
    required this.index,
    required this.row,
    required this.column,
    required this.title,
    required this.meaning,
  });

  factory DetectedCardOcr.fromJson(Map<String, dynamic> json) {
    return DetectedCardOcr(
      index: json['index'] as int? ?? 0,
      row: json['row'] as int? ?? 0,
      column: json['column'] as int? ?? 0,
      title: (json['title'] as String? ?? '').trim(),
      meaning: (json['meaning'] as String? ?? '').trim(),
    );
  }
}

class WindowsCardOcrService {
  static final WindowsCardOcrService instance = WindowsCardOcrService._();
  WindowsCardOcrService._();

  /// Automatically extract card titles and meanings from the composite image
  /// using Windows native WinRT OCR.
  Future<List<DetectedCardOcr>> extractCardsText({
    required String imagePath,
    required int rows,
    required int columns,
  }) async {
    if (!Platform.isWindows) return [];

    try {
      // 1. Fast Native Binary Execution (sub-300ms)
      final exeCandidates = [
        p.join(p.dirname(Platform.resolvedExecutable), 'ocr_tool.exe'),
        p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', 'assets', 'bin', 'ocr_tool.exe'),
        p.join(Directory.current.path, 'assets', 'bin', 'ocr_tool.exe'),
        p.join(Directory.current.path, 'bin', 'ocr_tool.exe'),
        p.join(Directory.current.path, 'windows', 'runner', 'ocr_tool.exe'),
      ];

      String? exePath;
      for (final cand in exeCandidates) {
        if (File(cand).existsSync()) {
          exePath = cand;
          break;
        }
      }

      if (exePath != null) {
        final res = await Process.run(
          exePath,
          [imagePath, rows.toString(), columns.toString()],
        );
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final data = jsonDecode(res.stdout.toString().trim()) as Map<String, dynamic>;
          final list = (data['cards'] as List? ?? [])
              .map((e) => DetectedCardOcr.fromJson(e as Map<String, dynamic>))
              .toList();
          return list;
        }
      }

      // 2. Built-in PowerShell WinRT OCR Script Fallback
      final scriptCandidates = [
        p.join(p.dirname(Platform.resolvedExecutable), 'data', 'flutter_assets', 'assets', 'scripts', 'card_ocr.ps1'),
        p.join(Directory.current.path, 'assets', 'scripts', 'card_ocr.ps1'),
      ];

      String? scriptPath;
      for (final cand in scriptCandidates) {
        if (File(cand).existsSync()) {
          scriptPath = cand;
          break;
        }
      }

      if (scriptPath != null) {
        final res = await Process.run(
          'powershell',
          [
            '-NoProfile',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            scriptPath,
            '-ImagePath',
            imagePath,
            '-Columns',
            columns.toString(),
            '-Rows',
            rows.toString(),
          ],
        );
        if (res.exitCode == 0 && res.stdout.toString().trim().isNotEmpty) {
          final data = jsonDecode(res.stdout.toString().trim()) as Map<String, dynamic>;
          final list = (data['cards'] as List? ?? [])
              .map((e) => DetectedCardOcr.fromJson(e as Map<String, dynamic>))
              .toList();
          return list;
        }
      }
    } catch (e) {
      debugPrint('WindowsCardOcrService error: $e');
    }

    return [];
  }
}
