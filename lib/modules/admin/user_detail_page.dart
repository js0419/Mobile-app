import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/user_service.dart';
import '../../models/user_model.dart';
import 'package:intl/intl.dart';


class UserDetailPage extends StatefulWidget {
  final int userId;

  const UserDetailPage({
    super.key,
    required this.userId,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  UserModel? user;
  bool _isLoading = true;

  Widget _infoRow(
      String label,
      String value, {
        Color? valueColor,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1);

  @override
  void initState() {
    super.initState();
    _fetchUserDetail();
  }

  Future<void> _fetchUserDetail() async {
    try {
      final data = await UserService.getUserById(widget.userId);

      setState(() {
        user = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user detail: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('User Detail'),
        backgroundColor: const Color(0xFF2F3640),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : user == null
          ? const Center(child: Text('User not found'))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.green.shade100,
                      backgroundImage: user!.icon != null
                          ? (user!.icon!.startsWith('assets/')
                          ? AssetImage(user!.icon!)
                          : FileImage(File(user!.icon!)) as ImageProvider)
                          : const AssetImage('assets/images/defaultIcon.png'),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user!.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user!.email,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('User ID', user!.id.toString()),
                  _divider(),
                  _infoRow('Email', user!.email),
                  _divider(),
                  _infoRow('Gender', user!.gender ?? 'Not specified'),
                  _divider(),
                  _infoRow(
                    'Status',
                    user!.status ? 'Active' : 'Blocked',
                    valueColor: user!.status
                        ? Colors.green
                        : Colors.red,
                  ),
                  _divider(),
                  _infoRow('Role', user!.type),
                  _divider(),
                  _infoRow(
                    'Created At',
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(user!.createdAt.toLocal()),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}