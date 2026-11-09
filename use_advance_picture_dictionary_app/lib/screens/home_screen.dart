import 'package:flutter/material.dart';
import '../widgets/picture_card_image.dart';
import '../models/picture_word_entry.dart';
import '../services/picture_database_service.dart';
import '../services/interlink_service.dart';
import 'picture_word_detail_screen.dart';
import 'picture_quiz_screen.dart';
import 'settings_screen.dart';
import '../services/favorites_history_service.dart';
import '../services/firestore_sync_service.dart';
import 'favorites_screen.dart';
import 'history_screen.dart';
import '../services/billing_service.dart';
import '../services/freemium_gatekeeper.dart';
import '../widgets/pro_paywall_sheet.dart';
import '../widgets/banner_ad_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<PictureWordEntry> _entries = [];
  List<String> _categories = ['All'];
  String _selectedCategory = 'All';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupDeepLinks();
    FavoritesHistoryService.instance.init();
    _syncWithCloudInBackground();
  }

  void _syncWithCloudInBackground() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        final result = await FirestoreSyncService.instance.syncPictureEntriesToLocal();
        if (result.success && (result.addedOrUpdated > 0 || result.deleted > 0) && mounted) {
          debugPrint('Silent cloud sync applied: ${result.message}');
          if (_searchController.text.trim().isEmpty) {
            _loadData();
          }
        }
      } catch (e) {
        debugPrint('Silent background sync check: $e');
      }
    });
  }

  void _setupDeepLinks() {
    try {
      InterlinkService.instance.initDeepLinks((word) async {
        if (!mounted) return;
        final trimmed = word.trim();
        if (trimmed.isEmpty) return;

        setState(() {
          _searchController.text = trimmed;
          _isLoading = true;
        });

        // 1. Try local DB or on-demand generation from dictionary
        var entry = await PictureDatabaseService.instance.getEntryByWord(trimmed);
        entry ??= await PictureDatabaseService.instance.fetchOrGenerateEntry(trimmed);

        if (!mounted) return;

        final results = await PictureDatabaseService.instance.searchEntries(trimmed);
        setState(() {
          _entries = results.isNotEmpty ? results : (entry != null ? [entry] : []);
          _isLoading = false;
        });

        if (!mounted) return;
        if (entry != null) {
          final targetEntry = entry;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PictureWordDetailScreen(entry: targetEntry)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Showing results for: "$trimmed"')),
          );
        }
      });
    } catch (e) {
      debugPrint('Deep link setup error: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final allEntries = await PictureDatabaseService.instance.getAllEntries();
      final categories = await PictureDatabaseService.instance.getAllCategories();
      if (mounted) {
        setState(() {
          // Do not overwrite search results if user has already typed a query or received deep link
          if (_searchController.text.trim().isEmpty) {
            _entries = allEntries;
          }
          _categories = ['All', ...categories];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onCategorySelected(String category) async {
    _searchController.clear();
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
    });

    List<PictureWordEntry> results;
    if (category == 'All') {
      results = await PictureDatabaseService.instance.getAllEntries();
    } else {
      results = await PictureDatabaseService.instance.getEntriesByCategory(category);
    }

    if (mounted) {
      setState(() {
        _entries = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _onSearchChanged(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _onCategorySelected(_selectedCategory);
      return;
    }
    setState(() => _isLoading = true);
    final results = await PictureDatabaseService.instance.searchEntries(trimmed);
    if (mounted) {
      setState(() {
        _entries = results;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (result == true) {
      _searchController.clear();
      _selectedCategory = 'All';
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image_search_rounded, color: theme.colorScheme.primary, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = MediaQuery.of(context).size.width < 500;
                  return Text(
                    isNarrow ? 'USE Picture Dict' : 'USE Advance Picture Dictionary',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isNarrow ? 15 : 18,
                    ),
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          AnimatedBuilder(
            animation: BillingService.instance,
            builder: (context, _) {
              if (BillingService.instance.isProUnlocked) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB703),
                    foregroundColor: const Color(0xFF0D1B2A),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.workspace_premium_rounded, size: 15),
                  label: const Text('PRO', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  onPressed: () => ProPaywallSheet.show(context),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Favourites',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.favorite_rounded, color: Colors.redAccent),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritesScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Visual Vocabulary Quiz',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PictureQuizScreen()),
              );
            },
          ),
          if (MediaQuery.of(context).size.width >= 550) ...[
            IconButton(
              tooltip: 'Search & View History',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.history_rounded),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            IconButton(
              tooltip: 'Open Companion App (USE Advance Dictionary)',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () {
                InterlinkService.instance.openInAdvanceDictionary(context, 'dictionary');
              },
            ),
            IconButton(
              tooltip: 'Settings',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.settings_rounded),
              onPressed: () => _openSettings(),
            ),
          ] else ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'More options',
              onSelected: (value) async {
                if (value == 'history') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                } else if (value == 'companion') {
                  InterlinkService.instance.openInAdvanceDictionary(context, 'dictionary');
                } else if (value == 'settings') {
                  _openSettings();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Search History'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'companion',
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Companion App'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Settings'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: const BannerAdWidget(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [
                    Color(0xFF0F172A),
                    Color(0xFF0B192C),
                    Color(0xFF091424),
                  ]
                : const [
                    Color(0xFFF0F7FF),
                    Color(0xFFE8F4FD),
                    Color(0xFFF3F8FC),
                  ],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
            children: [
              // 1. Search Box
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search word, meaning, or topic...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
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

              // 2. Category Filter Chips - Modern Transparent Outline Style
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _onCategorySelected(cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF00E5FF).withValues(alpha: 0.22) : const Color(0xFF2E3192).withValues(alpha: 0.12))
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.white.withValues(alpha: 0.45)),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF2E3192))
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.28)
                                      : const Color(0xFF00C6FF).withValues(alpha: 0.38)),
                              width: isSelected ? 1.6 : 1.1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF00C6FF).withValues(alpha: 0.22),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected) ...[
                                Icon(
                                  Icons.check_rounded,
                                  size: 15,
                                  color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF2E3192),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Text(
                                cat,
                                style: TextStyle(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF2E3192))
                                      : (isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : const Color(0xFF1E293B)),
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 13,
                                  letterSpacing: 0.15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              // 3. Grid of Words with Pictures
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _entries.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchController.text.isNotEmpty
                                        ? 'No picture found for "${_searchController.text}"'
                                        : 'No picture words in this category',
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Check the companion app for full definitions, grammar rules, and Sindhi/Urdu translations.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_searchController.text.isNotEmpty) ...[
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      icon: const Icon(Icons.add_photo_alternate_rounded),
                                      label: Text('Generate Picture Card for "${_searchController.text}"'),
                                      onPressed: () async {
                                        final query = _searchController.text;
                                        setState(() => _isLoading = true);
                                        final entry = await PictureDatabaseService.instance.fetchOrGenerateEntry(query);
                                        if (!mounted) return;
                                        if (entry != null) {
                                          final targetEntry = entry;
                                          final results = await PictureDatabaseService.instance.searchEntries(query);
                                          if (!context.mounted) return;
                                          setState(() {
                                            _entries = results.isNotEmpty ? results : [targetEntry];
                                            _isLoading = false;
                                          });
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => PictureWordDetailScreen(entry: targetEntry)),
                                          );
                                        } else {
                                          if (!context.mounted) return;
                                          setState(() => _isLoading = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Could not find definition for "$query"')),
                                          );
                                        }
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2E3192),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.menu_book),
                                    label: Text('Search "${_searchController.text}" in USE Advance Dictionary'),
                                    onPressed: () {
                                      InterlinkService.instance.openInAdvanceDictionary(
                                        context,
                                        _searchController.text.isNotEmpty ? _searchController.text : 'home',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              int crossAxisCount = 2;
                              if (constraints.maxWidth > 900) {
                                crossAxisCount = 4;
                              } else if (constraints.maxWidth > 600) {
                                crossAxisCount = 3;
                              }

                              return GridView.builder(
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  16,
                                  16,
                                  16 + MediaQuery.of(context).padding.bottom,
                                ),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  final entry = _entries[index];
                                  return _buildWordCard(context, entry, index);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildWordCard(BuildContext context, PictureWordEntry entry, [int? index]) {
    final theme = Theme.of(context);
    final posInitial = entry.partOfSpeech.isNotEmpty
        ? entry.partOfSpeech.substring(0, 1).toUpperCase()
        : '?';

    final isUnlocked = FreemiumGatekeeper.isWordUnlocked(index);

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          if (!isUnlocked) {
            ProPaywallSheet.show(context, triggeredWord: entry.word);
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PictureWordDetailScreen(entry: entry, entriesList: _entries, initialIndex: index),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                    child: Hero(
                      tag: 'word_img_${entry.word}',
                      child: PictureCardImage(
                        imageUrl: entry.thumbnailUrl ?? entry.imageUrl,
                        word: entry.word,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // Lock overlay for words beyond the free limit
                  if (!isUnlocked)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.45),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1B2A).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFFFB703), width: 1.2),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_rounded, size: 14, color: Color(0xFFFFB703)),
                                SizedBox(width: 4),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    color: Color(0xFFFFB703),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Favourite Heart Toggle on top-right of image card
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedBuilder(
                      animation: FavoritesHistoryService.instance,
                      builder: (context, _) {
                        final isFav = FavoritesHistoryService.instance.isFavorite(entry.word);
                        return Material(
                          color: Colors.black.withValues(alpha: 0.42),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              FavoritesHistoryService.instance.toggleFavorite(entry.word);
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 18,
                                color: isFav ? Colors.redAccent : Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.word,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            posInitial,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        entry.englishMeaning,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




