import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class InterlinkService {
  static final InterlinkService instance = InterlinkService._init();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  InterlinkService._init();

  Future<void> initDeepLinks(void Function(String word) onWordReceived) async {
    // 1. Cold start: Check if launched from deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri, onWordReceived);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // 2. Warm start: Listen while app is running
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri, onWordReceived);
    }, onError: (err) {
      debugPrint('Deep link stream error: $err');
    });
  }

  void _handleUri(Uri uri, void Function(String word) onWordReceived) {
    debugPrint('Received deep link URI: $uri');
    String? term = uri.queryParameters['term'] ?? uri.queryParameters['word'];
    if (term == null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.isNotEmpty && last != 'word') {
        term = last;
      }
    }
    if (term != null && term.trim().isNotEmpty) {
      onWordReceived(term.trim());
    }
  }

  Future<void> openInAdvanceDictionary(BuildContext context, String word) async {
    final deepLink = Uri.parse('useadvancedict://word?term=${Uri.encodeComponent(word)}');
    final playStoreLink = Uri.parse('https://play.google.com/store/apps/details?id=com.useadvance.dictionary');

    try {
      if (await canLaunchUrl(deepLink)) {
        await launchUrl(deepLink, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    // Fallback dialog if companion app is not yet installed
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.indigo),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'USE Advance Dictionary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'View comprehensive grammar, Sindhi & Urdu meanings, and vocabulary notes for "$word" in our companion app.',
 style: const TextStyle(fontSize: 14, height: 1.4),
 ),
 const SizedBox(height: 16),
 Container(
 padding: const EdgeInsets.all(12),
 decoration: BoxDecoration(
 color: Colors.grey.withValues(alpha: 0.08),
 borderRadius: BorderRadius.circular(12),
 ),
 child: const Row(
 children: [
 Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
 SizedBox(width: 8),
 Expanded(
 child: Text(
 'Full Grammar Rules • Sindhi & Urdu • Voice Search',
 style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
 ),
 ),
 ],
 ),
 ),
 ],
 ),
 actions: [
 TextButton(
 onPressed: () => Navigator.pop(ctx),
 child: const Text('Not Now'),
 ),
 ElevatedButton.icon(
 style: ElevatedButton.styleFrom(
 backgroundColor: Colors.indigo,
 foregroundColor: Colors.white,
 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
 ),
 icon: const Icon(Icons.download_rounded, size: 18),
 label: const Text('Get Free App'),
 onPressed: () {
 Navigator.pop(ctx);
 launchUrl(playStoreLink, mode: LaunchMode.externalApplication);
 },
 ),
 ],
 ),
 );
 }
 }

 void dispose() {
 _sub?.cancel();
 }
}