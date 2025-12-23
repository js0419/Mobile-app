import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart';
import '/models/mood_records.dart';
import '/models/mood_types.dart';
import '/services/supabase_client.dart';

class InsightsTab extends StatefulWidget {
  const InsightsTab({super.key});

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  List<MoodRecord> _records = [];
  List<MoodType> _moodTypes = [];
  bool _loading = true;
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<MoodRecord>> _recordsByDay = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<int?> _getCurrentUserId() async {
    try {
      final email = supabase.auth.currentUser?.email;
      if (email == null) return null;

      final response = await supabase
          .from('user')
          .select('user_id')
          .eq('user_email', email)
          .maybeSingle();

      return response?['user_id'] as int?;
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);

    final currentUserId = await _getCurrentUserId();
    if (currentUserId == null) {
      setState(() => _loading = false);
      return;
    }

    final recordsRes = await supabase
        .from('moodRecords')
        .select()
        .eq('user_id', currentUserId)
        .order('created_at', ascending: true);

    final moodRes = await supabase.from('moodTypes').select();

    final records = (recordsRes as List)
        .map((e) => MoodRecord.fromJson(e))
        .toList();

    final moods = (moodRes as List).map((e) => MoodType.fromJson(e)).toList();

    final Map<DateTime, List<MoodRecord>> mapByDay = {};
    for (var r in records) {
      final day = DateTime(r.createdAt!.year, r.createdAt!.month, r.createdAt!.day);
      mapByDay.putIfAbsent(day, () => []);
      mapByDay[day]!.add(r);
    }

    setState(() {
      _records = records;
      _moodTypes = moods;
      _recordsByDay = mapByDay;
      _loading = false;
    });
  }

  MoodType? _getMood(int? id) {
    try {
      return _moodTypes.firstWhere((m) => m.moodTypesId == id);
    } catch (_) {
      return null;
    }
  }

  void _showDayDetails(DateTime day) {
    final records = _recordsByDay[day] ?? [];
    if (records.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Mood Details (${day.day}/${day.month}/${day.year})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: records.length,
            itemBuilder: (_, idx) {
              final r = records[idx];
              final mood = _getMood(r.moodTypesId);
              return ListTile(
                leading: mood?.picture != null
                    ? Image.network(mood!.picture!, width: 32, height: 32)
                    : const Icon(Icons.mood),
                title: Text(mood?.name ?? 'Mood'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (r.description != null) Text(r.description!),
                    if (r.location != null) Text('📍 ${r.location}'),
                    if (r.weather != null) Text('☁️ ${r.weather}'),
                    if (r.temperature != null) Text('🌡️ ${r.temperature}'),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Map<int, double> _averageScaleByDay(DateTime month) {
    final Map<int, List<int>> dayScales = {};

    for (var r in _records) {
      if (r.createdAt!.year != month.year || r.createdAt!.month != month.month)
        continue;
      final scale = _getMood(r.moodTypesId)?.scale;
      if (scale == null) continue;

      final day = r.createdAt!.day;
      dayScales.putIfAbsent(day, () => []);
      dayScales[day]!.add(scale);
    }

    final Map<int, double> avgScale = {};
    for (var i = 1; i <= 31; i++) {
      final scales = dayScales[i];
      if (scales != null && scales.isNotEmpty) {
        avgScale[i] = scales.reduce((a, b) => a + b) / scales.length;
      }
    }
    return avgScale;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_records.isEmpty)
      return const Center(child: Text('No mood records yet'));

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TableCalendar(
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2023, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  headerStyle: const HeaderStyle(
                    titleCentered: true,
                    formatButtonVisible: false,
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    _focusedDay = focusedDay;
                    _showDayDetails(selectedDay);
                  },
                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) {
                      final records =
                          _recordsByDay[DateTime(
                            day.year,
                            day.month,
                            day.day,
                          )] ??
                          [];
                      if (records.isNotEmpty) {
                        return Center(
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white,
                            child:
                                records.first.moodTypesId != null &&
                                    _getMood(
                                          records.first.moodTypesId,
                                        )?.picture !=
                                        null
                                ? Image.network(
                                    _getMood(
                                      records.first.moodTypesId,
                                    )!.picture!,
                                    width: 24,
                                    height: 24,
                                  )
                                : const Icon(Icons.mood),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: Container(
              height: 200,
              width:
                  MediaQuery.of(context).size.width -
                  32,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 31 * 25.0,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LineChart(
                      LineChartData(
                        minX: 1,
                        maxX: 31,
                        minY: 1,
                        maxY: 5,
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 1,
                          verticalInterval: 1,
                          drawHorizontalLine: true,
                          drawVerticalLine: false,
                        ),
                        titlesData: FlTitlesData(
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) =>
                                  Text(value.toInt().toString()),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 2,
                              getTitlesWidget: (value, meta) {
                                final day = value.toInt();
                                if (day < 1 || day > 31)
                                  return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    day.toString(),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: const Border(
                            left: BorderSide(color: Colors.black),
                            bottom: BorderSide(color: Colors.black),
                            top: BorderSide(color: Colors.transparent),
                            right: BorderSide(color: Colors.transparent),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _averageScaleByDay(_focusedDay).entries
                                .where((e) => e.value > 0)
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: false,
                            color: Colors.blueAccent,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
