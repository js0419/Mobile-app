import 'package:flutter/material.dart';
import 'package:tikwei_assignment/modules/admin/user_management.dart';
import '../services/user_service.dart';
import '../modules/user/start_page.dart';

class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async{
              await UserService.logout();
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