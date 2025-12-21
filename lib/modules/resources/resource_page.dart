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

  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    _categories = await ResourceService.fetchCategories();
    _favoriteIds = await ResourceService.fetchFavoriteIds();
    _recent = await ResourceService.fetchRecent();
    _items = await ResourceService.fetchPublished(
      categoryId: _selectedCategoryId,
      search: _search,
      tag: _selectedTag,
    );
    setState(() {});
  }

  Future<void> _onFavoriteToggle(int id) async {
    final isFav = _favoriteIds.contains(id);
    await ResourceService.toggleFavorite(id, !isFav);
    final refreshed = await ResourceService.fetchFavoriteIds();
    setState(() {
      _favoriteIds = refreshed;
    });
  }

  List<String> _allTags() {
    final tags = <String>{};
    for (final r in _items) {
      tags.addAll(r.tags);
    }
    return tags.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resources'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search title, summary, or tags...',
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
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) async {
                _search = v.trim();
                await _load();
              },
            ),
          ),
        ),
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              children: [
                _categoryChips(),
                _tagChips(),
                _recentSection(),
                _listSection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _categoryChips() {
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
                _selectedCategoryId = c['category_id'] as int;
                await _load();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _tagChips() {
    final tags = _allTags();
    if (tags.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: [
          ChoiceChip(
            label: const Text('All tags'),
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
                _selectedTag = t;
                await _load();
              },
            ),
          )),
        ],
      ),
    );
  }

  Widget _recentSection() {
    if (_recent.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text('Recently viewed', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 160,
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
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/resource-detail', arguments: r.id);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 6),
                          Text(r.summary ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(r.categoryName ?? ''),
                              Icon(_iconForType(r.contentType), size: 18),
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
      ],
    );
  }

  Widget _listSection() {
    if (_items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No resources found')),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _items.length,
      itemBuilder: (context, i) {
        final r = _items[i];
        final isFav = _favoriteIds.contains(r.id);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(child: Icon(_iconForType(r.contentType))),
            title: Text(r.title),
            subtitle: Text(r.summary ?? ''),
            trailing: IconButton(
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.red : null),
              onPressed: () => _onFavoriteToggle(r.id),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/resource-detail', arguments: r.id);
            },
          ),
        );
      },
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
      default:
        return Icons.link;
    }
  }
}