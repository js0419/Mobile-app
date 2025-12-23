import 'package:flutter/material.dart';
import '/models/mood_records.dart';
import '/services/supabase_client.dart';
import 'track_tab.dart';
import 'history_tab.dart';
import 'insights_tab.dart';

class MoodRecordsPage extends StatefulWidget {
  const MoodRecordsPage({super.key});

  @override
  State<MoodRecordsPage> createState() => _MoodRecordsPage();
}

class _MoodRecordsPage extends State<MoodRecordsPage> {

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.green.shade200,
          title: const Text('Mood Records'),
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade200, Colors.green.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorColor: Colors.transparent,
                labelColor: Colors.black87,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                ),
                tabs: const [
                  Tab(text: 'Track'),
                  Tab(text: 'History'),
                  Tab(text: 'Insights'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  TrackTab(),
                  HistoryTab(),
                  InsightsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}