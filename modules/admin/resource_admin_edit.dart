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
  final Set<String> _selectedTags = {}; // article, exercise, music
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

  bool _loading = true;
  bool _saving = false;

  static const List<String> _tagOptions = ['article', 'exercise', 'music'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      editing = ModalRoute.of(context)!.settings.arguments as ResourceDto?;
      _initForm();
    });
  }

  Future<void> _initForm() async {
    try {
      _categories = await ResourceService.fetchCategories();
      if (editing != null) {
        _categoryId = editing!.categoryId;
        _title = editing!.title;
        _summary = editing!.summary;
        _contentType = editing!.contentType;
        _selectedTags
          ..clear()
          ..addAll(editing!.tags.where((t) => _tagOptions.contains(t)));
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearContentFieldsForType(String type) {
    setState(() {
      switch (type) {
        case 'video':
          _articleBody = null;
          _externalLink = null;
          _contactName = _contactEmail = _contactPhone = _officeLocation = _officeHours = null;
          break;
        case 'article':
          _videoUrl = null;
          _externalLink = null;
          _contactName = _contactEmail = _contactPhone = _officeLocation = _officeHours = null;
          break;
        case 'counselling':
          _videoUrl = null;
          _articleBody = null;
          _externalLink = null;
          break;
        case 'link':
        default:
          _videoUrl = null;
          _articleBody = null;
          _contactName = _contactEmail = _contactPhone = _officeLocation = _officeHours = null;
          break;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _saving = true);
    try {
      // Clear irrelevant fields before sending
      String? videoUrl = _videoUrl;
      String? articleBody = _articleBody;
      String? externalLink = _externalLink;
      String? contactName = _contactName;
      String? contactEmail = _contactEmail;
      String? contactPhone = _contactPhone;
      String? officeLocation = _officeLocation;
      String? officeHours = _officeHours;

      switch (_contentType) {
        case 'video':
          articleBody = null;
          externalLink = null;
          contactName = contactEmail = contactPhone = officeLocation = officeHours = null;
          break;
        case 'article':
          videoUrl = null;
          externalLink = null;
          contactName = contactEmail = contactPhone = officeLocation = officeHours = null;
          break;
        case 'counselling':
          videoUrl = null;
          articleBody = null;
          externalLink = null;
          break;
        case 'link':
        default:
          videoUrl = null;
          articleBody = null;
          contactName = contactEmail = contactPhone = officeLocation = officeHours = null;
          break;
      }

      final content = ResourceContent(
        videoUrl: videoUrl,
        articleBody: articleBody,
        externalLink: externalLink,
        contactName: contactName,
        contactEmail: contactEmail,
        contactPhone: contactPhone,
        officeLocation: officeLocation,
        officeHours: officeHours,
      );

      await ResourceService.upsertResource(
        resourceId: editing?.id,
        categoryId: _categoryId!,
        title: _title,
        summary: _summary,
        contentType: _contentType,
        tags: _selectedTags.toList(),
        isPublished: _isPublished,
        content: content,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final savingIndicator = _saving
        ? const Padding(
      padding: EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    )
        : const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? 'Create Resource' : 'Edit Resource'),
        actions: [
          savingIndicator,
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saving ? null : _save,
          )
        ],
      ),
      body: _loading
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
                validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                onChanged: (v) {
                  final next = v ?? 'video';
                  _contentType = next;
                  _clearContentFieldsForType(next);
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tags',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Wrap(
                spacing: 8,
                children: _tagOptions.map((tag) {
                  final selected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: selected,
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
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
                onPressed: _saving ? null : _save,
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
          validator: (v) =>
          (_contentType == 'video' && (v == null || v.trim().isEmpty))
              ? 'Video URL required'
              : null,
        );
      case 'article':
        return TextFormField(
          initialValue: _articleBody,
          decoration: const InputDecoration(labelText: 'Article Body'),
          maxLines: 6,
          onSaved: (v) => _articleBody = v?.trim(),
          validator: (v) =>
          (_contentType == 'article' && (v == null || v.trim().isEmpty))
              ? 'Article body required'
              : null,
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
          validator: (v) =>
          (_contentType == 'link' && (v == null || v.trim().isEmpty))
              ? 'External link required'
              : null,
        );
    }
  }
}