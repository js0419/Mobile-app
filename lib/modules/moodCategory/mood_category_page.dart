import 'package:flutter/material.dart';
import '/models/mood_category.dart';
import '/services/supabase_client.dart';
import '/core/admin_navigation.dart';

class MoodCategoryPage extends StatefulWidget {
  const MoodCategoryPage({super.key});

  @override
  State<MoodCategoryPage> createState() => _MoodCategoryPageState();
}

class _MoodCategoryPageState extends State<MoodCategoryPage> {
  bool _isLoading = true;
  List<MoodCategory> _moodCategory = [];
  List<MoodCategory> _filteredMoodCategory = [];
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final RegExp _onlyLetters = RegExp(r'^[A-Za-z ]+$');
  Map<String, bool> _statusFilter = {'Active': true, 'Inactive': true};
  String _selectedSort = 'A-Z';
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchMoodCategory();
    _searchController.addListener(_applyFilters);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.unfocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  //get mood category
  Future<void> _fetchMoodCategory() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await supabase.from('moodCategory').select();
      final moodCategory = (response as List)
          .map((item) => MoodCategory.fromJson(item))
          .toList();
      setState(() {
        _moodCategory = moodCategory;
      });
      _applyFilters();
    } catch (e) {
      print('Error fetching users: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to fetch users: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //add mood category
  Future<void> _addMoodCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }
    try {
      setState(() {
        _isLoading = true;
      });
      final response = await supabase.from('moodCategory').insert({
        'name': name,
      }).select();
      _nameController.clear();
      final newMoodCategory = MoodCategory.fromJson((response as List).first);
      setState(() {
        _moodCategory.add(newMoodCategory);
      });
      _applyFilters();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood Category added successfully!')),
      );
    } catch (e) {
      print('Error adding user: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add Mood Category: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //update mood category
  Future<void> _updateMoodCategory(String id) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final response = await supabase
        .from('moodCategory')
        .update({'name': name})
        .eq('moodCategoryId', id)
        .select();

    final updated = MoodCategory.fromJson((response as List).first);
    final index = _moodCategory.indexWhere((c) => c.moodCategoryId == id);

    setState(() {
      _moodCategory[index] = updated;
    });
    _applyFilters();
  }

  //change mood category status
  Future<void> _toggleMoodCategoryStatus(MoodCategory category) async {
    final newStatus = !category.status;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await supabase
          .from('moodCategory')
          .update({'status': newStatus})
          .eq('moodCategoryId', category.moodCategoryId)
          .select();
      if (response != null && (response as List).isNotEmpty) {
        final index = _moodCategory.indexWhere(
          (c) => c.moodCategoryId == category.moodCategoryId,
        );
        if (index != -1) {
          setState(() {
            _moodCategory[index] = MoodCategory.fromJson(response.first);
          });
          _applyFilters();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newStatus
                  ? 'Category activated successfully!'
                  : 'Category deactivated successfully!',
            ),
          ),
        );
      }
    } catch (e) {
      print('Error toggling category status: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to update category: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  //pop out the filter dialog
  void _showStatusFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempSort = _selectedSort;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter & Sort'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._statusFilter.keys.map((status) {
                    return CheckboxListTile(
                      title: Text(status),
                      value: _statusFilter[status],
                      onChanged: (value) {
                        setStateDialog(() {
                          _statusFilter[status] = value!;
                        });
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Sort by name: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: tempSort,
                        items: ['A-Z', 'Z-A'].map((option) {
                          return DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() {
                              tempSort = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _selectedSort = tempSort;
                    Navigator.pop(context);
                    _applyFilters();
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

  //apply filter + sorting
  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredMoodCategory = _moodCategory.where((category) {
        final matchesName = category.name.toLowerCase().contains(query);
        final matchesStatus =
            (category.status && _statusFilter['Active']!) ||
            (!category.status && _statusFilter['Inactive']!);
        return matchesName && matchesStatus;
      }).toList();

      _filteredMoodCategory.sort((a, b) {
        if (_selectedSort == 'A-Z') {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        } else {
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        }
      });
    });
  }

  //clear filter and search
  void _clearSearchAndFilters() {
    setState(() {
      _searchController.clear();
      _statusFilter = {'Active': true, 'Inactive': true};
      _applyFilters();
    });
  }

  //pop out add and modify dialog
  void _showMoodCategoryDialog({MoodCategory? category}) {
    _nameController.text = category?.name ?? '';
    String? duplicateError;
    final isEdit = category != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Mood Category' : 'Add Mood Category'),
              content: Form(
                key: _formKey,
                child: TextFormField(
                  controller: _nameController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    border: const OutlineInputBorder(),
                    suffixIcon: _nameController.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _nameController.clear();
                              setState(() {});
                            },
                          ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Category name is required';
                    }
                    if (!_onlyLetters.hasMatch(value.trim())) {
                      return 'Only letters are allowed';
                    }
                    if (value.trim().length > 50) {
                      return 'Category name cannot be more than 50 characters';
                    }
                    if (duplicateError != null) {
                      return duplicateError;
                    }
                    return null;
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    duplicateError = null;
                    final name = _nameController.text.trim();
                    if (_formKey.currentState!.validate()) {
                      final query = supabase
                          .from('moodCategory')
                          .select()
                          .eq('name', name);
                      if (isEdit) {
                        query.neq('moodCategoryId', category!.moodCategoryId);
                      }
                      final response = await query;

                      if ((response as List).isNotEmpty) {
                        setState(() {
                          duplicateError = 'Category name already exists';
                          _formKey.currentState!.validate();
                        });
                        return;
                      }
                      if (isEdit) {
                        await _updateMoodCategory(category!.moodCategoryId);
                      } else {
                        await _addMoodCategory();
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text(isEdit ? 'Update' : 'Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //each category records
  Widget _buildCategoryTile(MoodCategory category) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(
          Icons.category,
          color: category.status ? Colors.green : Colors.grey,
        ),
        title: Text(
          category.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: category.status ? Colors.black : Colors.grey,
          ),
        ),
        subtitle: Text(
          category.status ? 'Active' : 'Inactive',
          style: TextStyle(color: category.status ? Colors.green : Colors.red),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => _showMoodCategoryDialog(category: category),
            ),
            IconButton(
              icon: Icon(
                category.status ? Icons.toggle_on : Icons.toggle_off,
                size: 32,
                color: category.status ? Colors.green : Colors.grey,
              ),
              onPressed: () => _toggleMoodCategoryStatus(category),
            ),
          ],
        ),
      ),
    );
  }

  //main UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Categories'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMoodCategoryDialog(),
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
                      decoration: const InputDecoration(
                        labelText: 'Search by name',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => _applyFilters(),
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
                    : _filteredMoodCategory.isEmpty
                    ? const Center(
                        child: Text(
                          'No mood categories found',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchMoodCategory,
                        child: ListView.builder(
                          itemCount: _filteredMoodCategory.length,
                          itemBuilder: (context, index) {
                            final category = _filteredMoodCategory[index];
                            return _buildCategoryTile(category);
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
