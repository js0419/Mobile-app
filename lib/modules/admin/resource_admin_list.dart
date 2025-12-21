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

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<void> _load() async {
    _items = await ResourceService.fetchAll();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Resources')),
      drawer: const AdminDrawer(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/admin/resources/edit');
          _future = _load();
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_items.isEmpty) return const Center(child: Text('No resources yet'));
          return ListView.builder(
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
                        onChanged: (val) async {
                          await ResourceService.setPublish(r.id, val);
                          _future = _load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          await Navigator.pushNamed(
                            context,
                            '/admin/resources/edit',
                            arguments: r,
                          );
                          _future = _load();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await ResourceService.softDelete(r.id);
                          _future = _load();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}