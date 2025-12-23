import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '/models/mood_records.dart';
import '/models/mood_types.dart';
import '/services/supabase_client.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;

class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<MoodRecord> _records = [];
  List<MoodType> _moodTypes = [];
  bool _loading = true;
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  int? _filterMoodId;
  bool _sortNewestFirst = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<int?> _getCurrentUserId() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return null;

    final response = await supabase
        .from('user')
        .select('user_id')
        .eq('user_email', email)
        .single();

    return response['user_id'] as int?;
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
        .order('created_at', ascending: false);

    final moodRes = await supabase
        .from('moodTypes')
        .select();

    setState(() {
      _records = (recordsRes as List)
          .map((e) => MoodRecord.fromJson(e))
          .toList();
      _moodTypes = (moodRes as List).map((e) => MoodType.fromJson(e)).toList();
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

  String _formatDateTime(DateTime dt) {
    return "${dt.day}/${dt.month}/${dt.year} • "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  List<MoodRecord> get _filteredRecords {
    List<MoodRecord> list = [..._records];

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((r) {
        final moodName = _getMood(r.moodTypesId)?.name?.toLowerCase() ?? '';
        return moodName.contains(q) ||
            (r.description?.toLowerCase().contains(q) ?? false) ||
            (r.location?.toLowerCase().contains(q) ?? false) ||
            (r.weather?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_filterMoodId != null) {
      list = list.where((r) => r.moodTypesId == _filterMoodId).toList();
    }

    list.sort(
      (a, b) => _sortNewestFirst
          ? b.createdAt!.compareTo(a.createdAt!)
          : a.createdAt!.compareTo(b.createdAt!),
    );

    return list;
  }

  void _editRecord(MoodRecord record) {
    int? selectedMood = record.moodTypesId;
    final noteController = TextEditingController(text: record.description);
    File? newPhoto;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Edit Mood Record'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: selectedMood,
                  decoration: const InputDecoration(
                    labelText: 'Mood',
                    border: OutlineInputBorder(),
                  ),
                  items: _moodTypes.map((m) {
                    return DropdownMenuItem(
                      value: m.moodTypesId,
                      child: Text(m.name ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) => setStateDialog(() => selectedMood = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text('Change Photo'),
                  onPressed: () async {
                    final picked = await _picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        newPhoto = File(picked.path);
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (newPhoto != null)
                  Image.file(newPhoto!, height: 120)
                else if (record.picture != null)
                  Image.network(record.picture!, height: 120),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String? photoUrl = record.picture;

                if (newPhoto != null) {
                  final fileName =
                      'dailyphoto_${DateTime.now().millisecondsSinceEpoch}.png';
                  await supabase.storage
                      .from('mood-images')
                      .upload(fileName, newPhoto!);
                  photoUrl = supabase.storage
                      .from('mood-images')
                      .getPublicUrl(fileName);
                }

                await supabase
                    .from('moodRecords')
                    .update({
                      'moodTypesId': selectedMood,
                      'description': noteController.text.trim(),
                      'picture': photoUrl,
                    })
                    .eq('moodRecordsId', record.moodRecordsId!);

                Navigator.pop(context);
                _fetchData();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRecord(MoodRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await supabase
        .from('moodRecords')
        .delete()
        .eq('moodRecordsId', record.moodRecordsId!);

    _fetchData();
  }

  Future<pw.ImageProvider?> _loadPdfImage(String? url) async {
    if (url == null) return null;
    final response = await http.get(Uri.parse(url));
    return pw.MemoryImage(response.bodyBytes);
  }

  pw.Widget _pdfMetaRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 90,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Future<void> _exportHistoryAsPdf() async {
    final pdf = pw.Document();

    final imageCache = <int, pw.ImageProvider?>{};

    for (final record in _records) {
      imageCache[record.moodRecordsId!] = await _loadPdfImage(record.picture);
    }

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return _records.map((record) {
            final mood = _getMood(record.moodTypesId);
            final image = imageCache[record.moodRecordsId!];

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    mood?.name ?? 'Mood',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 6),

                  if (image != null)
                    pw.Center(child: pw.Image(image, height: 110)),

                  pw.SizedBox(height: 6),

                  if (record.description != null &&
                      record.description!.isNotEmpty)
                    pw.Text(
                      record.description!,
                      style: const pw.TextStyle(fontSize: 10),
                    ),

                  pw.SizedBox(height: 6),

                  _pdfMetaRow('Date', _formatDateTime(record.createdAt!)),

                  if (record.location != null)
                    _pdfMetaRow('Location', record.location!),

                  if (record.weather != null)
                    _pdfMetaRow('Weather', record.weather!),

                  if (record.temperature != null)
                    _pdfMetaRow('Temperature', record.temperature!),
                ],
              ),
            );
          }).toList();
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_records.isEmpty) {
      return const Center(child: Text('No mood history yet'));
    }

    final records = _filteredRecords;

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: records.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildFilterBar();
          final record = records[index - 1];
          final mood = _getMood(record.moodTypesId);
          return _buildRecordCard(record, mood);
        },
      ),
    );
  }

  Widget _buildRecordCard(MoodRecord record, MoodType? mood) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: record.picture != null
                ? () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.network(record.picture!),
                        ),
                      ),
                    );
                  }
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: record.picture != null
                  ? Image.network(
                      record.picture!,
                      width: 90,
                      height: 110,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 90,
                      height: 110,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text(
                        'No picture\nuploaded',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        mood?.name ?? 'Mood',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _editRecord(record);
                        if (value == 'delete') _deleteRecord(record);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (record.description != null &&
                    record.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      record.description!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _meta(
                      Icons.access_time,
                      _formatDateTime(record.createdAt!),
                    ),
                    if (record.location != null)
                      _meta(Icons.location_on, record.location!),
                    if (record.weather != null)
                      _meta(Icons.cloud, record.weather!),
                    if (record.temperature != null)
                      _meta(Icons.thermostat, record.temperature!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search mood, note, location...',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              controller: TextEditingController(text: _searchQuery),
            ),
          ),

          const SizedBox(width: 8),

          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.clear),
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _filterMoodId = null;
                _sortNewestFirst = true;
              });
            },
          ),

          const SizedBox(width: 4),

          IconButton(
            tooltip: 'Filter & Sort',
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _searchFocusNode.unfocus();
              _showFilterDialog();
            },
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    String _selectedSort = _sortNewestFirst ? 'Newest First' : 'Oldest First';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Filter & Sort History'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mood',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: _filterMoodId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Select Mood',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All moods'),
                        ),
                        ..._moodTypes.map((m) {
                          return DropdownMenuItem<int?>(
                            value: m.moodTypesId,
                            child: Text(m.name ?? ''),
                          );
                        }),
                      ],
                      onChanged: (val) => setStateDialog(() {
                        _filterMoodId = val;
                      }),
                    ),
                    const Divider(height: 24),
                    const Text(
                      'Sort By',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedSort,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                          value: 'Newest First',
                          child: Text('Newest First'),
                        ),
                        DropdownMenuItem(
                          value: 'Oldest First',
                          child: Text('Oldest First'),
                        ),
                      ],
                      onChanged: (val) => setStateDialog(() {
                        _selectedSort = val!;
                      }),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filterMoodId = null;
                    });
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _sortNewestFirst = _selectedSort == 'Newest First';
                    });
                    FocusScope.of(context).unfocus();
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _exportHistoryAsPdf,
        tooltip: 'Export PDF',
        child: const Icon(Icons.picture_as_pdf),
      ),
    );
  }
}
