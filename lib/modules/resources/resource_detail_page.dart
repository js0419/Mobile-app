import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/resource_service.dart';

class ResourceDetailPage extends StatefulWidget {
  const ResourceDetailPage({super.key});

  @override
  State<ResourceDetailPage> createState() => _ResourceDetailPageState();
}

class _ResourceDetailPageState extends State<ResourceDetailPage> {
  late Future<ResourceDto? > _future;
  bool _isFav = false;
  late int _resourceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resourceId = ModalRoute.of(context)!.settings.arguments as int;
    _future = _load();
  }

  Future<ResourceDto?> _load() async {
    try {
      final r = await ResourceService.fetchById(_resourceId);
      if (r != null) {
        await ResourceService.recordView(_resourceId);
      }
      final favs = await ResourceService.fetchFavoriteIds();
      if (mounted) {
        setState(() {
          _isFav = favs.contains(_resourceId);
        });
      }
      return r;
    } catch (e) {
      print('Error loading resource: $e');
      return null;
    }
  }

  Future<void> _toggleFav() async {
    try {
      await ResourceService.toggleFavorite(_resourceId, !_isFav);
      final favs = await ResourceService.fetchFavoriteIds();
      if (mounted) {
        setState(() {
          _isFav = favs.contains(_resourceId);
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFav ? 'Added to favorites' : 'Removed from favorites'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    return FutureBuilder<ResourceDto?>(
      future:  _future,
      builder: (context, snap) {
        if (snap. connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text('Error:  ${snap.error}'),
            ),
          );
        }
        if (snap.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Resource')),
            body: const Center(
              child: Text('Resource not found'),
            ),
          );
        }
        final r = snap.data!;
        final c = r.content;
        return Scaffold(
          appBar:  AppBar(
            title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: Icon(
                  _isFav ? Icons.favorite : Icons.favorite_border,
                  color:  _isFav ? Colors.red : Colors.white,
                ),
                onPressed: _toggleFav,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment. start,
              children: [
                // Title
                Text(
                  r.title,
                  style: Theme.of(context).textTheme.headlineSmall?. copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height:  12),

                // Category & Type Badge
                Row(
                  children: [
                    if (r.categoryName != null)
                      Chip(
                        label: Text(r.categoryName!),
                        backgroundColor: Colors.deepPurple[100],
                      ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(r.contentType),
                      backgroundColor: Colors.blue[100],
                      avatar: Icon(
                        _iconForType(r.contentType),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Summary
                if (r.summary != null)
                  Column(
                    crossAxisAlignment:  CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(r.summary!),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Content Section
                if (c != null)
                  Column(
                    crossAxisAlignment:  CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Content',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildContent(r. contentType, c),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Tags Section
                if (r.tags.isNotEmpty)
                  Column(
                    crossAxisAlignment:  CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Tags',
                        style: Theme.of(context).textTheme.titleMedium?. copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height:  8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: r. tags
                            .map((t) => Chip(
                          label: Text(t),
                          backgroundColor: Colors.grey[200],
                        ))
                            .toList(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(String type, ResourceContent c) {
    switch (type) {
      case 'video':
        return _buildVideoContent(c);
      case 'article':
        return _buildArticleContent(c);
      case 'counselling':
        return _buildCounsellingContent(c);
      default:
        return _buildExternalLinkContent(c);
    }
  }

  Widget _buildVideoContent(ResourceContent c) {
    if (c.videoUrl == null || c.videoUrl!.isEmpty) {
      return const Text('No video link available');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]! ),
      ),
      child: Column(
        children: [
          const Icon(Icons.play_circle_fill, size: 48, color: Colors.blue),
          const SizedBox(height: 12),
          ElevatedButton. icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Watch Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors. white,
            ),
            onPressed: () => _launchUrl(c.videoUrl!),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleContent(ResourceContent c) {
    if (c.articleBody == null || c.articleBody! .isEmpty) {
      return const Text('No article content available');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets. all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius:  BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Text(
        c.articleBody! ,
        style: const TextStyle(height: 1.6),
      ),
    );
  }

  Widget _buildCounsellingContent(ResourceContent c) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        if (c.contactName != null) ...[
    _buildInfoRow(Icons.person, 'Counsellor', c.contactName!),
    const SizedBox(height: 12),
    ],
    if (c.contactEmail != null) ...[
    _buildLinkRow(
    Icons.email,
    'Email',
    c.contactEmail!,
    'mailto:${c.contactEmail}',
    ),
    const SizedBox(height: 12),
    ],
    if (c.contactPhone != null) ...[
    _buildLinkRow(
    Icons.phone,
    'Phone',
    c.contactPhone!,
    'tel: ${c.contactPhone}',
    ),
    const SizedBox(height: 12),
    ],
    if (c.officeLocation != null) ...[
    _buildInfoRow(Icons.location_on, 'Location', c.officeLocation!),
    const SizedBox(height: 12),
    ],
    if (c.officeHours != null) ...[
    _buildInfoRow(Icons.schedule, 'Hours', c.officeHours!),
    ],
    ],
    );
  }

  Widget _buildExternalLinkContent(ResourceContent c) {
    if (c.externalLink == null || c. externalLink!.isEmpty) {
      return const Text('No external link available');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius:  BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]! ),
      ),
      child: Column(
        children: [
          const Icon(Icons.link, size: 48, color:  Colors.purple),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open Link'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            onPressed: () => _launchUrl(c. externalLink!),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors. grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkRow(
      IconData icon,
      String label,
      String value,
      String url,
      ) {
    return InkWell(
      onTap: () => _launchUrl(url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open link')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
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