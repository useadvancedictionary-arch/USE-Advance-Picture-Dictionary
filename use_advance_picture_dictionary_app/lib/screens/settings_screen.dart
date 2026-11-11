import 'package:flutter/material.dart';
import 'dart:io';
import '../services/firestore_sync_service.dart';
import '../services/cloud_image_service.dart';
import '../models/picture_word_entry.dart';
import '../services/picture_database_service.dart';
import '../widgets/picture_card_image.dart';
import 'about_info_accordion_screen.dart';
import '../services/admin_auth_service.dart';
import 'picture_crop_editor_screen.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import 'bulk_import_screen.dart';
import 'grid_picture_import_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool get _isAdminUnlocked => AdminAuthService.instance.isAdminUnlocked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + MediaQuery.of(context).padding.bottom),
            children: [
              // ── Admin Panel Section ──
              _buildSectionHeader(
                theme,
                icon: Icons.admin_panel_settings_rounded,
                title: 'Admin Panel',
                subtitle: _isAdminUnlocked ? 'Authenticated' : 'Password protected',
                color: const Color(0xFF2E3192),
              ),
              const SizedBox(height: 12),
              if (!_isAdminUnlocked)
                _buildAdminLockCard(theme)
              else
                _buildAdminPanel(theme),

              const SizedBox(height: 32),

              // ── My Vocabulary Section ──
              _buildSectionHeader(
                theme,
                icon: Icons.bookmarks_rounded,
                title: 'My Saved Vocabulary',
                subtitle: 'Favourites & search history',
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                theme,
                icon: Icons.favorite_rounded,
                iconColor: Colors.redAccent,
                title: 'Favourites',
                subtitle: 'Saved words and picture flashcards',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildSettingsTile(
                theme,
                icon: Icons.history_rounded,
                iconColor: Colors.blueAccent,
                title: 'Search & View History',
                subtitle: 'Recently explored words in the dictionary',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
              ),
              const SizedBox(height: 32),

              // ── About, Help & Policies Section ──
              _buildSectionHeader(
                theme,
                icon: Icons.info_outline_rounded,
                title: 'About, Help & Policies',
                subtitle: 'App information and legal',
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _buildSettingsTile(
                theme,
                icon: Icons.info_outline_rounded,
                iconColor: Colors.indigo,
                title: 'About, Help & Policies',
                subtitle: 'App info, how to use, privacy policy, terms of use',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutInfoAccordionScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Header ──
  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Settings Tile ──
  Widget _buildSettingsTile(
    ThemeData theme, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6)),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        onTap: onTap,
      ),
    );
  }

  // ── Admin Lock Card (password entry) ──
  Widget _buildAdminLockCard(ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF2E3192).withValues(alpha: 0.15),
                    const Color(0xFF1BFFFF).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Admin Access Required',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter the admin password to manage words, pictures, and dictionary entries.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E3192),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.vpn_key_rounded, size: 18),
                label: const Text('Unlock Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showPasswordDialog(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Password Dialog ──
  void _showPasswordDialog() {
    final controller = TextEditingController();
    bool obscure = true;
    String? errorText;

    showDialog(
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
                  const Text('Admin Login', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      if (AdminAuthService.instance.checkPassword(controller.text)) {
                        Navigator.pop(ctx);
                        setState(() => AdminAuthService.instance.unlock());
                      } else {
                        setDialogState(() => errorText = 'Incorrect password');
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3192),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (AdminAuthService.instance.checkPassword(controller.text)) {
                      Navigator.pop(ctx);
                      setState(() => AdminAuthService.instance.unlock());
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
  }

  // ── Admin Panel (unlocked) ──
  Widget _buildAdminPanel(ThemeData theme) {
    return Column(
      children: [
        // Lock button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.lock_rounded, size: 16),
            label: const Text('Lock Admin Panel', style: TextStyle(fontSize: 12)),
            onPressed: () => setState(() => AdminAuthService.instance.lock()),
          ),
        ),
        _buildSettingsTile(
          theme,
          icon: Icons.grid_on_rounded,
          iconColor: Colors.teal,
          title: 'Split & Assign Grid Pictures',
          subtitle: 'Multi-card composite grid splitter with drag & drop',
          onTap: () => _navigateToGridSplitter(),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          theme,
          icon: Icons.file_upload_outlined,
          iconColor: Colors.purple,
          title: 'Import Excel / CSV Vocabulary',
          subtitle: 'Bulk vocabulary spreadsheet import with drag & drop',
          onTap: () => _navigateToBulkImport(),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          theme,
          icon: Icons.add_photo_alternate_rounded,
          iconColor: Colors.green,
          title: 'Add New Word / Picture',
          subtitle: 'Create a new picture dictionary entry manually',
          onTap: () => _navigateToAddWord(),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          theme,
          icon: Icons.edit_rounded,
          iconColor: Colors.orange,
          title: 'Edit / Delete Word & Picture',
          subtitle: 'Search and modify or remove existing entries',
          onTap: () => _navigateToManageWords(),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          theme,
          icon: Icons.cloud_sync_rounded,
          iconColor: Colors.blueAccent,
          title: 'Cloud Sync & Multi-User Propagation',
          subtitle: 'Sync words and pictures across all user devices',
          onTap: () => _showCloudSyncDialog(),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          theme,
          icon: Icons.password_rounded,
          iconColor: const Color(0xFF2E3192),
          title: 'Change Admin Password',
          subtitle: 'Update the security password for this Admin Panel',
          onTap: () => _showChangePasswordDialog(),
        ),
      ],
    );
  }

  void _showCloudSyncDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        bool isSyncing = false;
        String status = '';
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              title: const Row(
                children: [
                  Icon(Icons.cloud_sync_rounded, color: Colors.blueAccent),
                  SizedBox(width: 10),
                  Text('Cloud Multi-User Sync', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Synchronize edits, deleted words, and uploaded pictures with Firebase Cloud so all users receive the changes.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                  if (status.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: status.contains('failed') || status.contains('Failed')
                            ? Colors.red
                            : status.contains('not uploaded') || status.contains('missing')
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                      ),
                    ),
                  ],
                  if (isSyncing) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
              actions: [
                if (!isSyncing) ...[
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Close'),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Full Resync'),
                    onPressed: () async {
                      setDialogState(() {
                        isSyncing = true;
                        status = 'Performing full sync with cloud...';
                      });
                      final res = await FirestoreSyncService.instance.syncPictureEntriesToLocal(
                        forceFullSync: true,
                        onProgress: (count, word) {
                          setDialogState(() {
                            status = 'Syncing $count pictures: "$word"...';
                          });
                        },
                      );
                      setDialogState(() {
                        isSyncing = false;
                        status = res.message;
                      });
                    },
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3192),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.cloud_download_rounded, size: 16),
                    label: const Text('Sync Updates'),
                    onPressed: () async {
                      setDialogState(() {
                        isSyncing = true;
                        status = 'Checking cloud for updates...';
                      });
                      final res = await FirestoreSyncService.instance.syncPictureEntriesToLocal(
                        onProgress: (count, word) {
                          setDialogState(() {
                            status = 'Syncing $count pictures: "$word"...';
                          });
                        },
                      );
                      setDialogState(() {
                        isSyncing = false;
                        status = res.message;
                      });
                    },
                  ),
                ],
                if (!isSyncing)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.cloud_upload_rounded, size: 16),
                    label: const Text('Upload Pending Images'),
                    onPressed: () async {
                      setDialogState(() {
                        isSyncing = true;
                        status = 'Scanning for locally stored images...';
                      });
                      final res = await FirestoreSyncService.instance.uploadPendingLocalImages(
                        onProgress: (done, total, word) {
                          setDialogState(() {
                            status = 'Uploading $done of $total: "$word"...';
                          });
                        },
                      );
                      setDialogState(() {
                        isSyncing = false;
                        status = res.message;
                      });
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _navigateToGridSplitter() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GridPictureImportScreen()),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _navigateToBulkImport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BulkImportScreen()),
    ).then((result) {
      if (result == true && mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? currentError;
    String? newError;
    String? confirmError;
    bool isSaving = false;

    showDialog(
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
                    child: const Icon(Icons.password_rounded, color: Color(0xFF2E3192), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        errorText: currentError,
                        prefixIcon: const Icon(Icons.lock_open_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        errorText: newError,
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        errorText: confirmError,
                        prefixIcon: const Icon(Icons.check_circle_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E3192),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: isSaving ? null : () async {
                    setDialogState(() {
                      currentError = null;
                      newError = null;
                      confirmError = null;
                    });

                    if (!AdminAuthService.instance.checkPassword(currentCtrl.text)) {
                      setDialogState(() => currentError = 'Current password is incorrect');
                      return;
                    }

                    if (newCtrl.text.trim().length < 4) {
                      setDialogState(() => newError = 'Password must be at least 4 characters');
                      return;
                    }

                    if (newCtrl.text != confirmCtrl.text) {
                      setDialogState(() => confirmError = 'Passwords do not match');
                      return;
                    }

                    setDialogState(() => isSaving = true);
                    final success = await AdminAuthService.instance.changePassword(
                      currentCtrl.text,
                      newCtrl.text,
                    );

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: success ? Colors.green.shade700 : Colors.redAccent,
                          content: Text(
                            success
                                ? 'Admin password successfully changed! 🔒'
                                : 'Failed to change admin password.',
                          ),
                        ),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // ── Navigate to Add Word ──
  void _navigateToAddWord() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AddEditWordScreen()),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Word added successfully!')),
        );
      }
    });
  }

  // ── Navigate to Manage Words ──
  void _navigateToManageWords() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ManageWordsScreen()),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Add / Edit Word Screen
// ════════════════════════════════════════════════════════════════════════════════
class _AddEditWordScreen extends StatefulWidget {
  final PictureWordEntry? existingEntry;

  const _AddEditWordScreen({this.existingEntry});

  @override
  State<_AddEditWordScreen> createState() => _AddEditWordScreenState();
}

class _AddEditWordScreenState extends State<_AddEditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _posController;
  late TextEditingController _meaningController;
  late TextEditingController _synonymsController;
  late TextEditingController _antonymsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _categoryController;
  late TextEditingController _exampleController;
  bool _isSaving = false;
  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEntry;
    _wordController = TextEditingController(text: e?.word ?? '');
    _posController = TextEditingController(text: e?.partOfSpeech ?? 'Noun');
    _meaningController = TextEditingController(text: e?.englishMeaning ?? '');
    _synonymsController = TextEditingController(text: e?.synonyms.join(', ') ?? '');
    _antonymsController = TextEditingController(text: e?.antonyms.join(', ') ?? '');
    _imageUrlController = TextEditingController(text: e?.imageUrl ?? '');
    _categoryController = TextEditingController(text: e?.category ?? 'General');
    _exampleController = TextEditingController(text: e?.exampleSentence ?? '');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _posController.dispose();
    _meaningController.dispose();
    _synonymsController.dispose();
    _antonymsController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final synonyms = _synonymsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final antonyms = _antonymsController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      String imgUrl = _imageUrlController.text.trim();
      if (imgUrl.isEmpty) {
        imgUrl = widget.existingEntry?.imageUrl ?? '';
      }

      // If this is a local image file, upload to Firebase Storage so other users can see it
      if (imgUrl.isNotEmpty && !imgUrl.startsWith('http') && !imgUrl.startsWith('assets/')) {
        final localFile = File(imgUrl);
        if (await localFile.exists()) {
          final cloudUrl = await CloudImageService.instance.uploadLocalFile(
            localFile,
            word: _wordController.text.trim(),
          );
          if (cloudUrl != null && cloudUrl.isNotEmpty) {
            imgUrl = cloudUrl;
          }
        }
      }

      final entry = PictureWordEntry(
        id: widget.existingEntry?.id,
        word: _wordController.text.trim(),
        partOfSpeech: _posController.text.trim(),
        englishMeaning: _meaningController.text.trim(),
        synonyms: synonyms,
        antonyms: antonyms,
        imageUrl: imgUrl,
        thumbnailUrl: imgUrl,
        category: _categoryController.text.trim().isEmpty ? 'General' : _categoryController.text.trim(),
        exampleSentence: _exampleController.text.trim().isEmpty ? null : _exampleController.text.trim(),
      );

      if (_isEditing) {
        await PictureDatabaseService.instance.updateEntry(entry);
      } else {
        await PictureDatabaseService.instance.insertEntry(entry);
      }

      // Sync word & picture to Firebase Firestore for ALL users
      FirestoreSyncService.instance.pushPictureEntry(entry);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
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
        title: Text(
          _isEditing ? 'Edit Word' : 'Add New Word',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton.icon(
              icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
              label: Text(_isEditing ? 'Save' : 'Add'),
              onPressed: _save,
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              children: [
                // Image Preview
                if (_imageUrlController.text.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: PictureCardImage(
                        imageUrl: _imageUrlController.text,
                        word: _wordController.text,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0072FF),
                      side: const BorderSide(color: Color(0xFF0072FF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.crop_rounded, size: 18),
                    label: const Text('Crop / Trim Extra Borders of This Picture'),
                    onPressed: () async {
                      final tempEntry = PictureWordEntry(
                        id: widget.existingEntry?.id,
                        word: _wordController.text.trim().isEmpty ? 'Card' : _wordController.text.trim(),
                        partOfSpeech: _posController.text,
                        englishMeaning: _meaningController.text,
                        synonyms: const [],
                        antonyms: const [],
                        imageUrl: _imageUrlController.text,
                        category: _categoryController.text,
                      );
                      final updated = await Navigator.push<PictureWordEntry>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PictureCropEditorScreen(entry: tempEntry),
                        ),
                      );
                      if (updated != null && mounted) {
                        setState(() {
                          _imageUrlController.text = updated.imageUrl;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Word
                _buildTextField(
                  controller: _wordController,
                  label: 'Word *',
                  icon: Icons.abc_rounded,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Part of Speech
                _buildDropdownField(theme),
                const SizedBox(height: 14),

                // English Meaning
                _buildTextField(
                  controller: _meaningController,
                  label: 'English Meaning *',
                  icon: Icons.lightbulb_outline,
                  maxLines: 3,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 14),

                // Category
                _buildTextField(
                  controller: _categoryController,
                  label: 'Category',
                  icon: Icons.folder_outlined,
                ),
                const SizedBox(height: 14),

                // Image URL
                _buildTextField(
                  controller: _imageUrlController,
                  label: 'Image URL (leave empty for auto-generated)',
                  icon: Icons.image_outlined,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),

                // Synonyms
                _buildTextField(
                  controller: _synonymsController,
                  label: 'Synonyms (comma separated)',
                  icon: Icons.sync_alt,
                ),
                const SizedBox(height: 14),

                // Antonyms
                _buildTextField(
                  controller: _antonymsController,
                  label: 'Antonyms (comma separated)',
                  icon: Icons.swap_horiz_rounded,
                ),
                const SizedBox(height: 14),

                // Example Sentence
                _buildTextField(
                  controller: _exampleController,
                  label: 'Example Sentence',
                  icon: Icons.format_quote_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E3192),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(_isEditing ? Icons.save_rounded : Icons.add_rounded),
                    label: Text(
                      _isEditing ? 'Save Changes' : 'Add Word',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
    );
  }

  Widget _buildDropdownField(ThemeData theme) {
    final parts = ['Noun', 'Verb', 'Adjective', 'Adverb', 'Phrase', 'Preposition', 'Conjunction', 'Interjection', 'Pronoun'];

    return DropdownButtonFormField<String>(
      initialValue: parts.contains(_posController.text) ? _posController.text : null,
      decoration: InputDecoration(
        labelText: 'Part of Speech',
        prefixIcon: const Icon(Icons.label_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
      ),
      items: parts.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
      onChanged: (v) {
        if (v != null) _posController.text = v;
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// Manage Words Screen (Search → Edit / Delete)
// ════════════════════════════════════════════════════════════════════════════════
class _ManageWordsScreen extends StatefulWidget {
  const _ManageWordsScreen();

  @override
  State<_ManageWordsScreen> createState() => _ManageWordsScreenState();
}

class _ManageWordsScreenState extends State<_ManageWordsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PictureWordEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final entries = await PictureDatabaseService.instance.getAllEntries();
      if (mounted) {
        setState(() {
          _entries = entries;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _loadAll();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await PictureDatabaseService.instance.searchEntries(trimmed);
      if (mounted) {
        setState(() {
          _entries = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEntry(PictureWordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Delete Word?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14),
                children: [
                  const TextSpan(text: 'Are you sure you want to delete '),
                  TextSpan(
                    text: '"${entry.word}"',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: '? This action cannot be undone.'),
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
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && entry.id != null) {
      await PictureDatabaseService.instance.deleteEntry(entry.id!);
      // Sync deletion across all users
      FirestoreSyncService.instance.deletePictureEntry(entry.word);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${entry.word}" deleted and synced to all users')),
        );
        _search(_searchController.text);
      }
    }
  }

  Future<void> _cropEntryPicture(PictureWordEntry entry) async {
    final updated = await Navigator.push<PictureWordEntry>(
      context,
      MaterialPageRoute(
        builder: (_) => PictureCropEditorScreen(entry: entry),
      ),
    );
    if (updated != null && mounted) {
      if (_searchController.text.trim().isEmpty) {
        _loadAll();
      } else {
        _search(_searchController.text);
      }
    }
  }

  void _editEntry(PictureWordEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _AddEditWordScreen(existingEntry: entry)),
    ).then((result) {
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${entry.word}" updated successfully')),
        );
        _search(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Manage Words',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Chip(
              avatar: const Icon(Icons.library_books_rounded, size: 16),
              label: Text('${_entries.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
              side: BorderSide.none,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search word to edit or delete...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadAll();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Entries List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'No entries found',
                                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.of(context).padding.bottom),
                            itemCount: _entries.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final entry = _entries[index];
                              return _buildEntryCard(theme, entry);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(ThemeData theme, PictureWordEntry entry) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _editEntry(entry),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: PictureCardImage(
                    imageUrl: entry.thumbnailUrl ?? entry.imageUrl,
                    word: entry.word,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Word Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.word,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.partOfSpeech,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            entry.category,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.englishMeaning,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(Icons.crop_rounded, size: 20),
                color: Colors.teal.shade700,
                tooltip: 'Crop / Edit Picture',
                onPressed: () => _cropEntryPicture(entry),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                color: Colors.orange.shade700,
                tooltip: 'Edit',
                onPressed: () => _editEntry(entry),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red.shade600,
                tooltip: 'Delete',
                onPressed: () => _deleteEntry(entry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


