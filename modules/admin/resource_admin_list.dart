import 'package:flutter/material.dart';
import '../../services/resource_service.dart';
import '../../core/admin_navigation.dart';

class ResourceAdminListPage extends StatefulWidget {
  const ResourceAdminListPage({super.key});

  @override
  State<ResourceAdminListPage> createState() => _ResourceAdminListPageState();
}

class _ResourceAdminListPageState extends State<ResourceAdminListPage> {
  late Future<void> _future;
  List<ResourceDto> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await ResourceService.fetchAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Load failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    _future = _load();
    await _future;
  }

  Future<void> _togglePublish(ResourceDto r, bool val) async {
    // optimistic update
    setState(() {
      final idx = _items.indexWhere((x) => x.id == r.id);
      if (idx != -1) {
        _items[idx] = ResourceDto(
          id: r.id,
          title: r.title,
          contentType: r.contentType,
          isPublished: val,
          summary: r.summary,
          tags: r.tags,
          categoryName: r.categoryName,
          categoryId: r.categoryId,
          content: r.content,
        );
      }
    });

    try {
      await ResourceService.setPublish(r.id, val);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
      // revert on failure
      setState(() {
        final idx = _items.indexWhere((x) => x.id == r.id);
        if (idx != -1) {
          _items[idx] = ResourceDto(
            id: r.id,
            title: r.title,
            contentType: r.contentType,
            isPublished: r.isPublished,
            summary: r.summary,
            tags: r.tags,
            categoryName: r.categoryName,
            categoryId: r.categoryId,
            content: r.content,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Resources')),
      drawer: const AdminDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final changed = await Navigator.pushNamed(context, '/admin/resources/edit');
          if (changed == true) await _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (_loading || snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_items.isEmpty) return const Center(child: Text('No resources yet'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final r = _items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: Text('${r.categoryName ?? ''} • ${r.contentType}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: r.isPublished,
                          onChanged: (val) => _togglePublish(r, val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () async {
                            final changed = await Navigator.pushNamed(
                              context,
                              '/admin/resources/edit',
                              arguments: r,
                            );
                            if (changed == true) await _refresh();
                          },
                        ),
                        // Delete intentionally removed
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}