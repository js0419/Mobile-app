import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/resource_service.dart';

class ResourceDetailPage extends StatefulWidget {
  const ResourceDetailPage({super.key});

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  late Future<ResourceDto?> _future;
  bool _isFav = false;
  late int _resourceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resourceId = ModalRoute.of(context)!.settings.arguments as int;
    _future = _load();
  }

  Future<ResourceDto?> _load() async {
    final r = await ResourceService.fetchById(_resourceId);
    await ResourceService.recordView(_resourceId);
    final favs = await ResourceService.fetchFavoriteIds();
    setState(() {
      _isFav = favs.contains(_resourceId);
    });
    return r;
  }

  Future<void> _toggleFav() async {
    await ResourceService.toggleFavorite(_resourceId, !_isFav);
    final favs = await ResourceService.fetchFavoriteIds();
    setState(() {
      _isFav = favs.contains(_resourceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResourceDto?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return const Scaffold(body: Center(child: Text('Failed to load resource')));
        }
        final r = snap.data!;
        final c = r.content;
        return Scaffold(
          appBar: AppBar(
            title: Text(r.title),
            actions: [
              IconButton(
                icon: Icon(_isFav ? Icons.favorite : Icons.favorite_border,
                    color: _isFav ? Colors.red : null),
                onPressed: _toggleFav,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: Theme.of(context).textTheme.titleLarge),
                if (r.summary != null) ...[
                  const SizedBox(height: 8),
                  Text(r.summary!),
                ],
                const SizedBox(height: 16),
                _buildContent(r.contentType, c),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: r.tags.map((t) => Chip(label: Text(t))).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(String type, ResourceContent? c) {
    switch (type) {
      case 'video':
        if (c?.videoUrl == null) return const Text('No video link');
        return _linkTile('Watch video', c!.videoUrl!);
      case 'article':
        return Text(c?.articleBody ?? 'No article content');
      case 'counselling':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c?.contactName != null) Text('Counsellor: ${c!.contactName}'),
            if (c?.contactEmail != null) _linkTile('Email', 'mailto:${c!.contactEmail}'),
            if (c?.contactPhone != null) _linkTile('Call', 'tel:${c!.contactPhone}'),
            if (c?.officeLocation != null) Text('Location: ${c!.officeLocation}'),
            if (c?.officeHours != null) Text('Hours: ${c!.officeHours}'),
          ],
        );
      default:
        if (c?.externalLink != null) return _linkTile('Open link', c!.externalLink!);
        return const Text('No content');
    }
  }

  Widget _linkTile(String label, String url) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(decoration: TextDecoration.underline)),
        ],
      ),
    );
  }
}