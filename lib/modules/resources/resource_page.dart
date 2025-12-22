import 'package:flutter/material.dart';
import '../../services/resource_service.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  int? _selectedCategoryId;
  String _search = '';
  String? _selectedTag;
  List<ResourceDto> _items = [];
  List<ResourceDto> _recent = [];
  List<Map<String, dynamic>> _categories = [];
  Set<int> _favoriteIds = {};
  late Future<void> _loadFuture;
  bool _isLoading = false;

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final categories = await ResourceService.fetchCategories();
      final favoriteIds = await ResourceService.fetchFavoriteIds();
      final recent = await ResourceService.fetchRecent();
      final items = await ResourceService.fetchPublished(
        categoryId: _selectedCategoryId,
        search: _search,
        tag: _selectedTag,
      );

      if (mounted) {
        setState(() {
          _categories = categories;
          _favoriteIds = favoriteIds;
          _recent = recent;
          _items = items;
        });
      }
    } catch (e) {
      print('Error loading resources: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading resources: $e')),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _onFavoriteToggle(int id) async {
    final isFav = _favoriteIds.contains(id);
    await ResourceService.toggleFavorite(id, !isFav);
    final refreshed = await ResourceService.fetchFavoriteIds();
    if (mounted) {
      setState(() {
        _favoriteIds = refreshed;
      });
    }
  }

  List<String> _allTags() {
    final tags = <String>{};
    for (final r in _items) {
      tags.addAll(r.tags);
    }
    return tags.toList()..sort();
  }

  void _clearFilters() async {
    _selectedCategoryId = null;
    _selectedTag = null;
    _searchController.clear();
    _search = '';
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite),
            onPressed: () {
              Navigator.pushNamed(context, '/favorites');
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Error loading resources'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _loadFuture = _load();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // ensure scroll
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchBar(),
                  _buildCategoryChips(),
                  _buildTagChips(),
                  if (_selectedCategoryId != null ||
                      _selectedTag != null ||
                      _search.isNotEmpty)
                    _buildClearFiltersButton(),
                  _buildRecentSection(),
                  _buildListSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search resources...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _search.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () async {
              _searchController.clear();
              _search = '';
              await _load();
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        onChanged: (v) {
          _search = v.trim();
        },
        onSubmitted: (v) async {
          _search = v.trim();
          await _load();
        },
      ),
    );
  }

  Widget _buildCategoryChips() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: _selectedCategoryId == null,
            onSelected: (_) async {
              _selectedCategoryId = null;
              await _load();
            },
          ),
          ..._categories.map((c) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(c['name'] ?? ''),
              selected: _selectedCategoryId == c['category_id'],
              onSelected: (_) async {
                setState(() {
                  _selectedCategoryId = c['category_id'] as int;
                });
                await _load();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildTagChips() {
    final tags = _allTags();
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          ChoiceChip(
            label: const Text('All Tags'),
            selected: _selectedTag == null,
            onSelected: (_) async {
              _selectedTag = null;
              await _load();
            },
          ),
          ...tags.map((t) => Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(t),
              selected: _selectedTag?.toLowerCase() == t.toLowerCase(),
              onSelected: (_) async {
                setState(() {
                  _selectedTag = t;
                });
                await _load();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildClearFiltersButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.clear_all),
        label: const Text('Clear Filters'),
        onPressed: _clearFilters,
      ),
    );
  }

  Widget _buildRecentSection() {
    if (_recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            'Recently Viewed',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _recent.length,
            itemBuilder: (context, i) {
              final r = _recent[i];
              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                child: Card(
                  elevation: 4,
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/resource-detail',
                        arguments: r.id,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            r.summary ?? 'No description',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                r.categoryName ?? 'Uncategorized',
                                style: const TextStyle(fontSize: 11),
                              ),
                              Icon(
                                _iconForType(r.contentType),
                                size: 16,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildListSection() {
    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No resources found',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (_search.isNotEmpty ||
                  _selectedTag != null ||
                  _selectedCategoryId != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: ElevatedButton(
                    onPressed: _clearFilters,
                    child: const Text('Clear Filters'),
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final r = _items[i];
        final isFav = _favoriteIds.contains(r.id);
        return _buildResourceCard(r, isFav);
      },
    );
  }

  Widget _buildResourceCard(ResourceDto r, bool isFav) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/resource-detail',
            arguments: r.id,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : null,
                    ),
                    onPressed: () => _onFavoriteToggle(r.id),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                r.summary ?? 'No description',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (r.categoryName != null)
                    Chip(
                      label: Text(
                        r.categoryName!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: Colors.deepPurple[100],
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      labelPadding: EdgeInsets.zero,
                    ),
                  const SizedBox(width: 8),
                  Chip(
                    label: Text(
                      r.contentType,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: Colors.blue[100],
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    labelPadding: EdgeInsets.zero,
                    avatar: Icon(
                      _iconForType(r.contentType),
                      size: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (r.tags.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: r.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String t) {
    switch (t) {
      case 'video':
        return Icons.play_circle_fill;
      case 'article':
        return Icons.article;
      case 'counselling':
        return Icons.support_agent;
      case 'external':
        return Icons.link;
      default:
        return Icons.description;
    }
  }
}