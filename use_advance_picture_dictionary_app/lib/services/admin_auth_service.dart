import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AdminAuthService {
  static final AdminAuthService instance = AdminAuthService._();
  AdminAuthService._();

  static const String defaultPassword = 'Ateeque74';
  String _adminPassword = defaultPassword;
  bool _isAdminUnlocked = false;
  bool _initialized = false;

  bool get isAdminUnlocked => _isAdminUnlocked;
  String get adminPassword => _adminPassword;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/.admin_auth_key');
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (saved.isNotEmpty) {
          _adminPassword = saved;
        }
      }
    } catch (e) {
      debugPrint('AdminAuthService init error: $e');
    }
  }

  bool checkPassword(String input) {
    return input.trim() == _adminPassword;
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    await init();
    if (currentPassword.trim() != _adminPassword) {
      return false;
    }
    if (newPassword.trim().isEmpty) {
      return false;
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/.admin_auth_key');
      await file.writeAsString(newPassword.trim(), flush: true);
      _adminPassword = newPassword.trim();
      return true;
    } catch (e) {
      debugPrint('Error saving new admin password: $e');
      return false;
    }
  }

  void lock() {
    _isAdminUnlocked = false;
  }

  void unlock() {
    _isAdminUnlocked = true;
  }

  /// Verifies admin access. If already unlocked in this session, returns true immediately.
  /// Otherwise, presents an elegant password dialog.
  Future<bool> ensureAdminUnlocked(BuildContext context) async {
    await init();
    if (_isAdminUnlocked) return true;

    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E3192).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF2E3192), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Admin Access', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter admin password to access restricted administrative functions:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    obscureText: obscure,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: errorText,
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                    ),
                    onSubmitted: (_) {
                      if (checkPassword(controller.text)) {
                        _isAdminUnlocked = true;
                        Navigator.pop(ctx, true);
                      } else {
                        setDialogState(() => errorText = 'Incorrect password');
                      }
                    },
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
                    backgroundColor: const Color(0xFF2E3192),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (checkPassword(controller.text)) {
                      _isAdminUnlocked = true;
                      Navigator.pop(ctx, true);
                    } else {
                      setDialogState(() => errorText = 'Incorrect password');
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            );
          },
        );
      },
    );

    return result == true;
  }
}

