import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/user_service.dart';
import 'edit_profile_page.dart';
import 'start_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;

  String? name;
  String? email;
  String? iconPath;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

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

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      final response = await supabase
          .from('user')
          .select()
          .eq('user_email', user.email!)
          .single();

      setState(() {
        name = response['user_name'];
        email = response['user_email'];
        iconPath = response['user_icon'];
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _logout() async {
    await UserService.logout();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StartPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8FFD7), Color(0xFF93DA97)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: SafeArea(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.arrow_back, size: 30),
                              ),
                              const SizedBox(width: 45),
                              const Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.green.shade100,
                            backgroundImage: iconPath != null
                                ? FileImage(File(iconPath!))
                                : const AssetImage('assets/images/defaultIcon.png')
                            as ImageProvider,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            name ?? 'User',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email ?? '',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 30),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const EditProfilePage()),
                                );
                              },
                              child: const Text('Edit Profile'),
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Divider(),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.lock),
                            title: const Text('Change Password'),
                            onTap: () {

                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.notifications),
                            title: const Text('Notification Settings'),
                            onTap: () {

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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}