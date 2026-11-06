import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class InterlinkService {
  static final InterlinkService instance = InterlinkService._init();
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  static const MethodChannel _androidChannel =
      MethodChannel('com.useadvance.picture_dict/interlink');

  InterlinkService._init();

  Future<void> initDeepLinks(void Function(String word) onWordReceived) async {
    if (_initialized) return;
    _initialized = true;

    // 1. Web: Check query parameters from URL
    if (kIsWeb) {
      try {
        final queryParams = Uri.base.queryParameters;
        final term = queryParams['word'] ?? queryParams['term'];
        if (term != null && term.trim().isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onWordReceived(term.trim());
          });
        }
      } catch (e) {
        debugPrint('Error getting web URL parameters: $e');
      }
      return;
    }

    // 2. Cold start: Check if launched from deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleUri(initialUri, onWordReceived);
        });
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // 3. Warm start: Listen while app is running
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
    final encoded = Uri.encodeComponent(word);
    final fallbackWebUrl =
        Uri.parse('https://use-advance-dictionary.netlify.app/?word=$encoded');

    // 1. Web Platform: Directly switch to the companion web page
    if (kIsWeb) {
      try {
        await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Error launching web URL: $e');
      }
      return;
    }

    final deepLink = Uri.parse('useadvancedict://word?term=$encoded');

    // 2. Try standard custom URL scheme launch across all platforms
    try {
      if (await canLaunchUrl(deepLink)) {
        final launched =
            await launchUrl(deepLink, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (e) {
      debugPrint('Error checking/launching deep link: $e');
    }

    // 3. Android Platform Specific Fallback:
    // If the companion app was installed from Google Play before the deep link scheme was registered,
    // launch via direct package intent.
    if (Platform.isAndroid) {
      try {
        final launched = await _androidChannel.invokeMethod<bool>(
          'launchAndroidCompanion',
          {
            'word': word,
            'package': 'com.useadvance.dictionary',
          },
        );
        if (launched == true) return;
      } catch (e) {
        debugPrint('Android method channel launch error: $e');
      }
    }

    // 4. Windows Platform Specific Fallback:
    // Auto-register protocol in HKCU if USE Advance Dictionary Microsoft Store/Desktop app is installed.
    if (Platform.isWindows) {
      try {
        final registered = await _autoRegisterWindowsProtocol();
        if (registered) {
          if (await canLaunchUrl(deepLink)) {
            final launched =
                await launchUrl(deepLink, mode: LaunchMode.externalApplication);
            if (launched) return;
          }
        }
      } catch (e) {
        debugPrint('Windows protocol registration fallback error: $e');
      }
    }

    // 5. If companion app is truly not detected, show the store install dialog
    // with an option to also open the Web Dictionary immediately!
    if (!context.mounted) return;

    if (Platform.isWindows) {
      _showStoreInstallDialog(
        context: context,
        word: word,
        platformName: 'Desktop / Windows PC',
        storeName: 'Microsoft Store',
        storeIcon: Icons.desktop_windows_rounded,
        primaryStoreUri:
            Uri.parse('ms-windows-store://pdp/?productid=9NLV4X4CVLSM'),
        fallbackStoreUri:
            Uri.parse('https://apps.microsoft.com/detail/9NLV4X4CVLSM'),
        webFallbackUri: fallbackWebUrl,
      );
    } else if (Platform.isAndroid) {
      _showStoreInstallDialog(
        context: context,
        word: word,
        platformName: 'Android',
        storeName: 'Google Play Store',
        storeIcon: Icons.shop_rounded,
        primaryStoreUri:
            Uri.parse('market://details?id=com.useadvance.dictionary'),
        fallbackStoreUri: Uri.parse(
            'https://play.google.com/store/apps/details?id=com.useadvance.dictionary'),
        webFallbackUri: fallbackWebUrl,
      );
    } else if (Platform.isIOS || Platform.isMacOS) {
      _showStoreInstallDialog(
        context: context,
        word: word,
        platformName: 'Apple Device',
        storeName: 'Apple App Store',
        storeIcon: Icons.apple_rounded,
        primaryStoreUri: Uri.parse(
            'itms-apps://itunes.apple.com/search?term=USE+Advance+Dictionary'),
        fallbackStoreUri:
            Uri.parse('https://apps.apple.com/search?term=USE+Advance+Dictionary'),
        webFallbackUri: fallbackWebUrl,
      );
    } else {
      await launchUrl(fallbackWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<bool> _autoRegisterWindowsProtocol() async {
    if (!Platform.isWindows) return false;
    try {
      const psScript = r'''
$pkg = Get-AppxPackage | Where-Object { $_.Name -like "*AdvanceDictionary*" }
if ($pkg) {
  $exePath = "$($pkg.InstallLocation)\use_advanced_dictionary_app.exe"
  if (Test-Path $exePath) {
    New-Item -Path "Registry::HKEY_CURRENT_USER\Software\Classes\useadvancedict" -Force | Out-Null
    Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Classes\useadvancedict" -Name "(Default)" -Value "URL:USE Advance Dictionary Protocol" -Force
    Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Classes\useadvancedict" -Name "URL Protocol" -Value "" -Force
    New-Item -Path "Registry::HKEY_CURRENT_USER\Software\Classes\useadvancedict\shell\open\command" -Force | Out-Null
    Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Software\Classes\useadvancedict\shell\open\command" -Name "(Default)" -Value "`"$exePath`" `"%1`"" -Force
    exit 0
  }
}
exit 1
''';
      final res = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
      );
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  void _showStoreInstallDialog({
    required BuildContext context,
    required String word,
    required String platformName,
    required String storeName,
    required IconData storeIcon,
    required Uri primaryStoreUri,
    required Uri fallbackStoreUri,
    required Uri webFallbackUri,
  }) {
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
              'USE Advance Dictionary is not detected on your $platformName.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Install it to view complete Sindhi & Urdu meanings, grammar, pronunciation, and vocabulary notes for "$word".',
              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
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
                      'Trilingual Meanings • Grammar Rules • Voice Search',
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
            child: const Text('Cancel'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.language_rounded, size: 18),
            label: const Text('Open Web Version'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await launchUrl(webFallbackUri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(storeIcon, size: 18),
            label: Text('Install via $storeName'),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                if (await canLaunchUrl(primaryStoreUri)) {
                  await launchUrl(primaryStoreUri, mode: LaunchMode.externalApplication);
                  return;
                }
              } catch (_) {}
              // Fallback to web store page
              try {
                await launchUrl(fallbackStoreUri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
