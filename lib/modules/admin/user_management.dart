import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tikwei_assignment/modules/admin/user_detail_page.dart';
import '../../core/admin_navigation.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final supabase = Supabase.instance.client;

  List<UserModel> _users = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;

  final _searchCtrl = TextEditingController();

  int _currentPage = 1;
  final int _rowsPerPage = 5;

  bool _sortAsc = true;
  String _sortField = 'name';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await UserService.fetchAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load users: $e')),
      );
    }
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _currentPage = 1;
      _filteredUsers = _users.where((user) {
        final name = (user.name ?? '').toLowerCase();
        final email = user.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    });
  }

  void _sortUsers(String field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }

      _filteredUsers.sort((a, b) {
        final aValue = field == 'name'
            ? (a.name ?? '').toLowerCase()
            : a.email.toLowerCase();
        final bValue = field == 'name'
            ? (b.name ?? '').toLowerCase()
            : b.email.toLowerCase();
        return _sortAsc
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      });
    });
  }

  List<UserModel> get _pagedUsers {
    final start = (_currentPage - 1) * _rowsPerPage;
    final end = start + _rowsPerPage;
    return _filteredUsers.sublist(
      start,
      end > _filteredUsers.length ? _filteredUsers.length : end,
    );
  }

  Widget _paginationControls() {
    final totalPages = (_filteredUsers.length / _rowsPerPage).ceil();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Page $_currentPage of $totalPages'),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Future<bool?> showConfirmDialog({
      required BuildContext context,
      required String title,
      required String message,
    }) {
      return showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: const Color(0xFF93DA97),
      ),
      drawer: const AdminDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 32,
                  headingRowHeight: 50,
                  dataRowHeight: 56,
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFF93DA97),
                  ),
                  columns: [
                    const DataColumn(
                      label: Text('No',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    DataColumn(
                      label: InkWell(
                        onTap: () => _sortUsers('name'),
                        child: Row(
                          children: [
                            const Text('Name',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Icon(
                              _sortField == 'name'
                                  ? (_sortAsc
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataColumn(
                      label: InkWell(
                        onTap: () => _sortUsers('email'),
                        child: Row(
                          children: [
                            const Text('Email',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Icon(
                              _sortField == 'email'
                                  ? (_sortAsc
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const DataColumn(
                      label: Text('Gender',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const DataColumn(
                      label: Text('Status',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const DataColumn(
                      label: Text('Action',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  rows: List.generate(_pagedUsers.length, (index) {
                    final user = _pagedUsers[index];
                    final isActive = user.status;
                    return DataRow(
                      cells: [
                        DataCell(Text(
                            '${index + 1 + (_currentPage - 1) * _rowsPerPage}')),
                        DataCell(Text(user.name ?? '-')),
                        DataCell(Text(user.email)),
                        DataCell(Text(user.gender ?? '-')),
                        DataCell(Text(isActive ? 'Active' : 'Blocked')),
                        DataCell(Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isActive
                                    ? Icons.block
                                    : Icons.check_circle,
                                color: isActive
                                    ? Colors.red
                                    : Colors.green,
                              ),
                              onPressed: () async {
                                final confirmed =
                                await showConfirmDialog(
                                  context: context,
                                  title: isActive
                                      ? 'Block User'
                                      : 'Activate User',
                                  message: user.email,
                                );
                                if (confirmed != true) return;
                                await UserService.updateUserStatus(
                                  email: user.email,
                                  newStatus: !isActive,
                                );
                                _fetchUsers();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserDetailPage(
                                      userId: user.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        )),
                      ],
                    );
                  }),
                ),
              ),
            ),
            _paginationControls(),
          ],
        ),
      ),
    );
  }
}
