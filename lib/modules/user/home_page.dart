import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tikwei_assignment/modules/moodRecords/mood_records_page.dart';
import '../../services/user_service.dart';
import 'start_page.dart';
import 'profile_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Color get _primaryGreen => Colors.green.shade600;
  Color get _lightGreen => Colors.green.shade50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('IKUN Home'),
        backgroundColor: _primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        color: _lightGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Track your mood, explore resources, and stay on top of your wellbeing.',
                      style: TextStyle(
                        color: Colors.green.shade900.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _HomeActionButton(
              icon: Icons.sentiment_satisfied_alt,
              label: 'Mood Records',
              color: _primaryGreen,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MoodRecordsPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            _HomeActionButton(
              icon: Icons.person,
              label: 'Profile',
              color: Colors.green.shade500,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfilePage()),
                );
              },
            ),
            const SizedBox(height: 12),
            _HomeActionButton(
              icon: Icons.video_library,
              label: 'Resources',
              color: Colors.green.shade400,
              onTap: () {
                Navigator.pushNamed(context, '/resources');
              },
            ),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade400,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                await UserService.logout();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StartPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HomeActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}