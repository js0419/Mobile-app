import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../modules/user/start_page.dart';
import '../../modules/user/home_page.dart';
import '../../modules/admin/admin_home.dart';
import '../modules/moodRecords/mood_records_page.dart';
import '../services/user_service.dart';
import '../modules/admin/user_management.dart';
import 'block_page.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session == null) {
          return const StartPage();
        }

        return FutureBuilder<String>(
          future: _loadUserAndRoute(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return Scaffold(
                body: Center(child: Text('Error: ${snapshot.error}')),
              );
            }

            final result = snapshot.data!;

            if (result == 'blocked') {
              return const BlockPage();
            }

            if (result == 'staff') {
              return const UserManagementPage();
            }

            if (result == 'user') {
              return const HomePage();
            }

            return const StartPage();
          },
        );
      },
    );
  }

  Future<String> _loadUserAndRoute() async {
    final auth = Supabase.instance.client.auth;

    final user = auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('User not ready');
    }

    await UserService.handlePostLogin();

    final data = await Supabase.instance.client
        .from('user')
        .select('user_type, user_status')
        .eq('user_email', user.email!)
        .single();

    if (data['user_status'] == false) {
      return 'blocked';
    }

    return data['user_type'] as String;
  }
}