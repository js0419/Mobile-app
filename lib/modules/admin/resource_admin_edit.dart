import 'package:flutter/material.dart';
import '../../services/resource_service.dart';

class ResourceAdminEditPage extends StatefulWidget {
  const ResourceAdminEditPage({super.key});

  @override
  State<ResourceAdminEditPage> createState() => _ResourceAdminEditPageState();
}

class _ResourceAdminEditPageState extends State<ResourceAdminEditPage> {
  final _formKey = GlobalKey<FormState>();
  ResourceDto? editing;
  List<Map<String, dynamic>> _categories = [];
  int? _categoryId;
  String _title = '';
  String? _summary;
  String _contentType = 'video';
  String? _tags;
  bool _isPublished = false;

  // Content fields
  String? _videoUrl;
  String? _articleBody;
  String? _externalLink;
  String? _contactName;
  String? _contactEmail;
  String? _contactPhone;
  String? _officeLocation;
  String? _officeHours;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editing = ModalRoute.of(context)!.settings.arguments as ResourceDto?;
      _initForm();
    });
  }

  Future<void> _initForm() async {
    _categories = await ResourceService.fetchCategories();
    if (editing != null) {
      _categoryId = editing!.categoryId;
      _title = editing!.title;
      _summary = editing!.summary;
      _contentType = editing!.contentType;
      _tags = editing!.tags.join(', ');
      _isPublished = editing!.isPublished;

      final c = editing!.content;
      _videoUrl = c?.videoUrl;
      _articleBody = c?.articleBody;
      _externalLink = c?.externalLink;
      _contactName = c?.contactName;
      _contactEmail = c?.contactEmail;
      _contactPhone = c?.contactPhone;
      _officeLocation = c?.officeLocation;
      _officeHours = c?.officeHours;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final content = ResourceContent(
      videoUrl: _videoUrl,
      articleBody: _articleBody,
      externalLink: _externalLink,
      contactName: _contactName,
      contactEmail: _contactEmail,
      contactPhone: _contactPhone,
      officeLocation: _officeLocation,
      officeHours: _officeHours,
    );

    await ResourceService.upsertResource(
      resourceId: editing?.id,
      categoryId: _categoryId!,
      title: _title,
      summary: _summary,
      contentType: _contentType,
      tags: _tags?.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
      isPublished: _isPublished,
      content: content,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? 'Create Resource' : 'Edit Resource'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
          )
        ],
      ),
      body: _categories.isEmpty && editing == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem<int>(
                  value: c['category_id'] as int,
                  child: Text(c['name'] ?? ''),
                ))
                    .toList(),
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Select category' : null,
              ),
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
                onSaved: (v) => _title = v?.trim() ?? '',
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                initialValue: _summary,
                decoration: const InputDecoration(labelText: 'Summary'),
                onSaved: (v) => _summary = v?.trim(),
                maxLines: 2,
              ),
              DropdownButtonFormField<String>(
                value: _contentType,
                decoration: const InputDecoration(labelText: 'Content Type'),
                items: const [
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'article', child: Text('Article')),
                  DropdownMenuItem(value: 'counselling', child: Text('Counselling')),
                  DropdownMenuItem(value: 'link', child: Text('External Link')),
                ],
                onChanged: (v) => setState(() => _contentType = v ?? 'video'),
              ),
              TextFormField(
                initialValue: _tags,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)'),
                onSaved: (v) => _tags = v?.trim(),
              ),
              SwitchListTile(
                title: const Text('Published'),
                value: _isPublished,
                onChanged: (v) => setState(() => _isPublished = v),
              ),
              const SizedBox(height: 12),
              _buildContentFields(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentFields() {
    switch (_contentType) {
      case 'video':
        return TextFormField(
          initialValue: _videoUrl,
          decoration: const InputDecoration(labelText: 'Video URL'),
          onSaved: (v) => _videoUrl = v?.trim(),
        );
      case 'article':
        return TextFormField(
          initialValue: _articleBody,
          decoration: const InputDecoration(labelText: 'Article Body'),
          maxLines: 6,
          onSaved: (v) => _articleBody = v?.trim(),
        );
      case 'counselling':
        return Column(
          children: [
            TextFormField(
              initialValue: _contactName,
              decoration: const InputDecoration(labelText: 'Contact Name'),
              onSaved: (v) => _contactName = v?.trim(),
            ),
            TextFormField(
              initialValue: _contactEmail,
              decoration: const InputDecoration(labelText: 'Contact Email'),
              onSaved: (v) => _contactEmail = v?.trim(),
            ),
            TextFormField(
              initialValue: _contactPhone,
              decoration: const InputDecoration(labelText: 'Contact Phone'),
              onSaved: (v) => _contactPhone = v?.trim(),
            ),
            TextFormField(
              initialValue: _officeLocation,
              decoration: const InputDecoration(labelText: 'Office Location'),
              onSaved: (v) => _officeLocation = v?.trim(),
            ),
            TextFormField(
              initialValue: _officeHours,
              decoration: const InputDecoration(labelText: 'Office Hours'),
              onSaved: (v) => _officeHours = v?.trim(),
            ),
          ],
        );
      default: // link
        return TextFormField(
          initialValue: _externalLink,
          decoration: const InputDecoration(labelText: 'External Link'),
          onSaved: (v) => _externalLink = v?.trim(),
        );
    }
  }
}