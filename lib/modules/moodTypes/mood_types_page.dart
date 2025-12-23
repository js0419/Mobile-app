import 'dart:io';
import 'package:flutter/material.dart';
import '/models/mood_types.dart';
import '/models/mood_category.dart';
import '/services/supabase_client.dart';
import 'package:image_picker/image_picker.dart';
import '/core/admin_navigation.dart';

class MoodTypePage extends StatefulWidget {
  const MoodTypePage({super.key});

  @override
  State<MoodTypePage> createState() => _MoodTypePageState();
}

class _MoodTypePageState extends State<MoodTypePage> {
  List<MoodType> _moodTypes = [];
  List<MoodType> _filteredMoodTypes = [];
  List<MoodCategory> _categories = [];
  int? _selectedScale;
  bool _isLoading = true;
  final RegExp _onlyLetters = RegExp(r'^[A-Za-z ]+$');
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  int? _selectedCategoryId;
  File? _image;
  final picker = ImagePicker();
  final FocusNode _searchFocusNode = FocusNode();
  Map<String, bool> _statusFilter = {'Active': true, 'Inactive': true};
  int? _filterCategoryId;
  String _sortField = 'Name';
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchMoodTypes();
    _searchController.addListener(_applyFilters);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  //get mood types
  Future<void> _fetchMoodTypes() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await supabase.from('moodTypes').select();
      final types = (response as List)
          .map((e) => MoodType.fromJson(e))
          .toList();
      setState(() {
        _moodTypes = types;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching mood types: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch mood types: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //get categories for dropdown
  Future<void> _fetchCategories() async {
    try {
      final response = await supabase.from('moodCategory').select();
      final cats = (response as List)
          .map((e) => MoodCategory.fromJson(e))
          .toList();
      setState(() {
        _categories = cats;
      });
    } catch (e) {
      print('Error fetching categories: $e');
    }
  }

  Future<void> _addMoodType() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploadMoodImage(_image!);
      }

      final response = await supabase.from('moodTypes').insert({
        'name': name,
        'moodCategoryId': _selectedCategoryId,
        'picture': imageUrl,
        'status': true,
        'scale': _selectedScale,
      }).select();

      final newType = MoodType.fromJson((response as List).first);

      setState(() {
        _moodTypes.add(newType);
        _image = null;
      });

      _applyFilters();
      _nameController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood type added successfully!')),
      );
    } catch (e) {
      debugPrint('Error adding mood type: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateMoodType(MoodType type) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      setState(() => _isLoading = true);

      String? imageUrl = type.picture;
      if (_image != null) {
        imageUrl = await _uploadMoodImage(_image!);
      }

      final response = await supabase
          .from('moodTypes')
          .update({
            'name': name,
            'moodCategoryId': _selectedCategoryId,
            'picture': imageUrl,
            'scale': _selectedScale,
          })
          .eq('moodTypesId', type.moodTypesId)
          .select();

      final updated = MoodType.fromJson((response as List).first);

      final index = _moodTypes.indexWhere(
        (t) => t.moodTypesId == type.moodTypesId,
      );

      setState(() {
        _moodTypes[index] = updated;
        _image = null;
      });

      _applyFilters();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStatus(MoodType type) async {
    try {
      setState(() => _isLoading = true);
      final response = await supabase
          .from('moodTypes')
          .update({'status': !(type.status ?? true)})
          .eq('moodTypesId', type.moodTypesId)
          .select();
      final updated = MoodType.fromJson((response as List).first);
      final index = _moodTypes.indexWhere(
        (t) => t.moodTypesId == type.moodTypesId,
      );
      setState(() => _moodTypes[index] = updated);
      _applyFilters();
    } catch (e) {
      print('Error toggling status: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showStatusFilterDialog() {
    String _selectedSort = _sortField == 'Name'
        ? (_isAscending ? 'Name A-Z' : 'Name Z-A')
        : (_isAscending ? 'Scale Low-High' : 'Scale High-Low');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter & Sort Mood Types'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._statusFilter.keys.map((status) {
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(status),
                        value: _statusFilter[status],
                        onChanged: (val) {
                          setStateDialog(() {
                            _statusFilter[status] = val!;
                          });
                        },
                      );
                    }).toList(),
                    const Divider(height: 24),

                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: _filterCategoryId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Select Category',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ..._categories.map((cat) {
                          return DropdownMenuItem<int?>(
                            value: int.tryParse(cat.moodCategoryId),
                            child: Text(cat.name),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setStateDialog(() {
                          _filterCategoryId = val;
                        });
                      },
                    ),
                    const Divider(height: 24),

                    const Text(
                      'Sort By',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Name A-Z',
                          child: Text('Name A-Z'),
                        ),
                        DropdownMenuItem(
                          value: 'Name Z-A',
                          child: Text('Name Z-A'),
                        ),
                        DropdownMenuItem(
                          value: 'Scale Low-High',
                          child: Text('Scale Low-High'),
                        ),
                        DropdownMenuItem(
                          value: 'Scale High-Low',
                          child: Text('Scale High-Low'),
                        ),
                      ],
                      onChanged: (val) {
                        setStateDialog(() {
                          _selectedSort = val!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _statusFilter = {'Active': true, 'Inactive': true};
                      _filterCategoryId = null;
                    });
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () {
                    switch (_selectedSort) {
                      case 'Name A-Z':
                        _sortField = 'Name';
                        _isAscending = true;
                        break;
                      case 'Name Z-A':
                        _sortField = 'Name';
                        _isAscending = false;
                        break;
                      case 'Scale Low-High':
                        _sortField = 'Scale';
                        _isAscending = true;
                        break;
                      case 'Scale High-Low':
                        _sortField = 'Scale';
                        _isAscending = false;
                        break;
                    }
                    _applyFilters();
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    List<MoodType> filtered = _moodTypes.where((type) {
      final matchesName = type.name?.toLowerCase().contains(query) ?? false;
      final matchesStatus =
          (type.status == true && _statusFilter['Active']!) ||
          (type.status == false && _statusFilter['Inactive']!);
      final matchesCategory =
          _filterCategoryId == null || type.moodCategoryId == _filterCategoryId;
      return matchesName && matchesStatus && matchesCategory;
    }).toList();

    filtered.sort((a, b) {
      int compare = 0;
      if (_sortField == 'Name') {
        compare = (a.name ?? '').toLowerCase().compareTo(
          (b.name ?? '').toLowerCase(),
        );
      } else if (_sortField == 'Scale') {
        compare = (a.scale ?? 0).compareTo(b.scale ?? 0);
      }
      return _isAscending ? compare : -compare;
    });

    setState(() {
      _filteredMoodTypes = filtered;
    });
  }

  void _clearSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = {'Active': true, 'Inactive': true};
      _filterCategoryId = null;
      _applyFilters();
    });
  }

  Future<void> _pickMoodImage(StateSetter setStateDialog) async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setStateDialog(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadMoodImage(File image) async {
    try {
      final fileName = 'mood_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('mood-images').upload(fileName, image);

      final imageUrl = supabase.storage
          .from('mood-images')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      debugPrint('Image upload error: $e');
      return null;
    }
  }

  void _showAddEditDialog({MoodType? type}) {
    _nameController.text = type?.name ?? '';
    _selectedScale = type?.scale ?? 3;
    _selectedCategoryId = type?.moodCategoryId;
    _image = null;
    String? duplicateError;
    bool _showScaleError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(type == null ? 'Add Mood Type' : 'Edit Mood Type'),
              content: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: _categories.map((cat) {
                          return DropdownMenuItem(
                            value: int.tryParse(cat.moodCategoryId),
                            child: Text(cat.name),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setStateDialog(() => _selectedCategoryId = val),
                        validator: (val) =>
                            val == null ? 'Please select a category' : null,
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _nameController,
                        maxLength: 50,
                        decoration: InputDecoration(
                          labelText: 'Mood Type Name',
                          border: const OutlineInputBorder(),
                          suffixIcon: _nameController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _nameController.clear();
                                    setStateDialog(() {});
                                  },
                                ),
                        ),

                        onChanged: (_) => setStateDialog(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Name is required';
                          }
                          if (!_onlyLetters.hasMatch(value.trim())) {
                            return 'Only letters are allowed';
                          }
                          if (value.trim().length > 50) {
                            return 'Cannot exceed 50 characters';
                          }
                          if (duplicateError != null) return duplicateError;
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood Scale (1-5)',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Slider(
                            value: (_selectedScale ?? 3).toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: (_selectedScale ?? 3).toString(),
                            onChanged: (val) {
                              setStateDialog(() {
                                _selectedScale = val.round();
                                _showScaleError = false;
                              });
                            },
                          ),
                          if (_showScaleError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Please select a scale',
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Mood Image',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 6),

                      OutlinedButton.icon(
                        onPressed: () => _pickMoodImage(setStateDialog),
                        icon: const Icon(Icons.upload),
                        label: const Text('Choose Image'),
                      ),

                      const SizedBox(height: 8),

                      if (_image != null)
                        Image.file(
                          _image!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      else if (type?.picture != null)
                        Image.network(
                          type!.picture!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _image = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: () async {
                    duplicateError = null;

                    final name = _nameController.text.trim();

                    final isDuplicate = await _isDuplicateName(
                      name,
                      excludeId: type?.moodTypesId,
                    );

                    if (isDuplicate) {
                      setState(() {
                        duplicateError = 'Mood type name already exists';
                      });

                      _formKey.currentState!.validate();
                      return;
                    }

                    if (_formKey.currentState!.validate()) {
                      if (type == null) {
                        await _addMoodType();
                      } else {
                        await _updateMoodType(type);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(type == null ? 'Submit' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _isDuplicateName(String name, {int? excludeId}) async {
    final query = supabase
        .from('moodTypes')
        .select('moodTypesId')
        .ilike('name', name);

    final response = excludeId == null
        ? await query
        : await query.neq('moodTypesId', excludeId);

    return (response as List).isNotEmpty;
  }

  Widget _buildTypeTile(MoodType type) {
    final categoryName = _categories
        .firstWhere(
          (c) => int.tryParse(c.moodCategoryId) == type.moodCategoryId,
          orElse: () =>
              MoodCategory(moodCategoryId: '0', name: 'Unknown', status: true),
        )
        .name;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: type.picture != null
              ? NetworkImage(type.picture!)
              : null,
          child: type.picture == null ? const Icon(Icons.mood) : null,
        ),
        title: Text(
          type.name ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: type.status == true ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(categoryName, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Scale: ${type.scale ?? '-'}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showAddEditDialog(type: type),
            ),
            IconButton(
              icon: Icon(
                type.status == true ? Icons.toggle_on : Icons.toggle_off,
                size: 32,
                color: type.status == true ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleStatus(type),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Types'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      drawer: const AdminDrawer(),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: const InputDecoration(
                        labelText: 'Search by name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showStatusFilterDialog,
                    icon: const Icon(Icons.filter_list),
                    tooltip: 'Filter',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _clearSearchAndFilters,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredMoodTypes.isEmpty
                    ? const Center(child: Text('No mood types found'))
                    : RefreshIndicator(
                        onRefresh: _fetchMoodTypes,
                        child: ListView.builder(
                          itemCount: _filteredMoodTypes.length,
                          itemBuilder: (context, index) {
                            final type = _filteredMoodTypes[index];
                            return _buildTypeTile(type);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
