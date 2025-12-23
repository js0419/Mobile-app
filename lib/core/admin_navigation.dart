import 'package:flutter/material.dart';
import 'package:tikwei_assignment/modules/admin/user_management.dart';
import '../modules/moodCategory/mood_category_page.dart';
import '../modules/moodTypes/mood_types_page.dart';
import '../services/user_service.dart';
import '../modules/user/start_page.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  void _go(BuildContext context, String route) {
    Navigator.pushReplacementNamed(context, route);
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
            children: const [
              Icon(Icons.logout, color: Colors.purple),
              SizedBox(width: 8),
              Text('Confirm Logout'),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    }
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.green,
            ),
            child: Row(
              children: const [
                Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 40),
                SizedBox(width: 12),
                Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () {
              Navigator.pushReplacementNamed(context, '/admin-dashboard');
            },
          ),
          ListTile(
            leading: const Icon(Icons.library_books),
            title: const Text('Manage Resources'),
            subtitle: const Text('List, add, edit, publish/unpublish'),
            onTap: () => _go(context, '/admin/resources'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('User'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (BuildContext context) => const UserManagementPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Mood Category'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (BuildContext context) => const MoodCategoryPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mood),
            title: const Text('Mood Type'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (BuildContext context) => const MoodTypePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirmed = await showConfirmDialog(
                context: context,
                title: 'Confirm Logout',
                message: 'Are you sure you want to log out?',
              );
              if (confirmed != true) return;
              await UserService.logout();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (BuildContext context) => const StartPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}