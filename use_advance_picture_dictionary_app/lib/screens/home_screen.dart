import 'package:flutter/material.dart';
import '../widgets/picture_card_image.dart';
import '../models/picture_word_entry.dart';
import '../services/picture_database_service.dart';
import '../services/interlink_service.dart';
import 'picture_word_detail_screen.dart';
import 'picture_quiz_screen.dart';
import 'bulk_import_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image_search_rounded, color: theme.colorScheme.primary, size: 24),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'USE Advance Picture Dictionary',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Visual Vocabulary Quiz',
            icon: const Icon(Icons.quiz_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PictureQuizScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Import Excel / CSV Vocabulary',
            icon: const Icon(Icons.file_upload_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkImportScreen()),
              );
              if (result == true) {
                _searchController.clear();
                _selectedCategory = 'All';
                await _loadData();
              }
            },
          ),
          IconButton(
            tooltip: 'Open Companion App (USE Advance Dictionary)',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () {
              InterlinkService.instance.openInAdvanceDictionary(context, 'dictionary');
            },
          ),
        ],
      ),
      body: Center(
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

              // 2. Category Filter Chips
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = cat == _selectedCategory;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: theme.colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                      onSelected: (_) => _onCategorySelected(cat),
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
                                padding: const EdgeInsets.all(16),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: _entries.length,
                                itemBuilder: (context, index) {
                                  final entry = _entries[index];
                                  return _buildWordCard(context, entry);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(BuildContext context, PictureWordEntry entry) {
    final theme = Theme.of(context);
    final posInitial = entry.partOfSpeech.isNotEmpty
        ? entry.partOfSpeech.substring(0, 1).toUpperCase()
        : '?';

    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PictureWordDetailScreen(entry: entry),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
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
