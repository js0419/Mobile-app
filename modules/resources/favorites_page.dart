import 'package:flutter/material.dart';
import '../../services/resource_service.dart';

class FavoritesPage extends StatefulWidget { // <-- renamed
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<void> _loadFuture;
  List<ResourceDto> _items = [];
  Set<int> _favoriteIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final favs = await ResourceService.fetchFavoriteResources();
      final favIds = favs.map((e) => e.id).toSet();
      if (mounted) {
        setState(() {
          _items = favs;
          _favoriteIds = favIds;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading favorites: $e')),
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  Future<void> _onFavoriteToggle(int id) async {
    final isFav = _favoriteIds.contains(id);
    try {
      await ResourceService.toggleFavorite(id, !isFav);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_items.isEmpty) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No favorites yet')),
                  SizedBox(height: 120),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                final isFav = _favoriteIds.contains(r.id);
                return _buildResourceCard(r, isFav);
              },
            ),
          );
        },
      ),
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