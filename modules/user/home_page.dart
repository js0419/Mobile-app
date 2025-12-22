import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/user_service.dart';
import 'start_page.dart';
import 'profile_page.dart';

class HomePage extends StatelessWidget{
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
          child: Column(
            children: [
              Text("Hello"),
              ElevatedButton(
                onPressed: () async {
                  await UserService.logout();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StartPage()),
                  );
                },
                child: const Text('Logout'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
                child: const Text('Profile Page'),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.video_library),
                label: const Text('Access Resources'),
                onPressed: () {
                  Navigator.pushNamed(context, '/resources');
                },
              ),
            ],
          ),
        ),
    );
  }
}