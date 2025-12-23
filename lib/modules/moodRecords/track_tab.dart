import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import '/models/mood_types.dart';
import '/services/supabase_client.dart';
import '/models/forecast.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TrackTab extends StatefulWidget {
  const TrackTab({super.key});

  @override
  State<TrackTab> createState() => _TrackTabState();
}

class _TrackTabState extends State<TrackTab> {
  List<MoodType> _moodTypes = [];
  int? _selectedMoodTypeId;
  bool _isLoading = true;
  bool _detectingLocation = false;
  String? _locationError;
  final TextEditingController noteController = TextEditingController();
  String? _selectedStateId;
  String? _selectedState;
  Future<List<Forecast>>? forecastData;
  File? _dailyPhoto;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchMoodTypes();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  void _clearForm() {
    setState(() {
      _selectedMoodTypeId = null;
      _dailyPhoto = null;
      noteController.clear();
      _selectedState = null;
      _selectedStateId = null;
      forecastData = null;
    });
  }

  Future<int?> _getCurrentUserId() async {
    final email = supabase.auth.currentUser?.email;
    if (email == null) return null;

    final response = await supabase
        .from('user')
        .select('user_id')
        .eq('user_email', email)
        .single();

    return response['user_id'] as int;
  }

  Future<void> _pickDailyPhoto({bool fromCamera = false}) async {
    final pickedFile = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
    );

    if (pickedFile != null) {
      setState(() {
        _dailyPhoto = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadDailyPhoto(File image) async {
    try {
      final fileName =
          'dailyphoto_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('mood-images').upload(fileName, image);

      final imageUrl = supabase.storage
          .from('mood-images')
          .getPublicUrl(fileName);

      return imageUrl;
    } catch (e) {
      debugPrint('Daily photo upload error: $e');
      return null;
    }
  }

  Future<String?> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'Location services are disabled. Please enable GPS.';
        });
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission != LocationPermission.always &&
            permission != LocationPermission.whileInUse) {
          setState(() {
            _locationError = 'Location permission denied.';
          });
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission permanently denied. Please enable it in settings.';
        });
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final raw = placemarks.first.administrativeArea;
        debugPrint('Raw state from geocoder: $raw');
        final state = normalizeMalaysiaState(raw);
        if (state != null) return state;

        setState(() {
          _locationError = 'Unable to detect Malaysian state.';
        });
      } else {
        setState(() {
          _locationError = 'No placemark data found.';
        });
      }
      return null;
    } catch (e) {
      debugPrint('Location error: $e');
      setState(() {
        _locationError = 'Error detecting location: $e';
      });
      return null;
    }
  }

  String? normalizeMalaysiaState(String? raw) {
    if (raw == null) return null;

    final normalizationMap = {
      'Kuala Lumpur': 'WP Kuala Lumpur',
      'Putrajaya': 'WP Putrajaya',
      'Labuan': 'WP Labuan',
    };

    for (var key in normalizationMap.keys) {
      if (raw.toLowerCase().contains(key.toLowerCase())) {
        return normalizationMap[key];
      }
    }

    final regularStates = [
      'Perlis',
      'Kedah',
      'Pulau Pinang',
      'Perak',
      'Kelantan',
      'Terengganu',
      'Pahang',
      'Selangor',
      'Negeri Sembilan',
      'Melaka',
      'Johor',
      'Sarawak',
      'Sabah',
    ];

    for (var state in regularStates) {
      if (raw.toLowerCase().contains(state.toLowerCase())) {
        return state;
      }
    }

    return null;
  }

  Future<Forecast?> _getTodayForecastFromFuture() async {
    if (forecastData == null) return null;

    final data = await forecastData!;
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      return data.firstWhere((f) => f.date == todayStr);
    } catch (_) {
      return data.isNotEmpty ? data.first : null;
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _detectingLocation = true;
      _locationError = null;
    });

    final stateName = await _getCurrentLocation();

    if (!mounted) return;

    setState(() {
      _detectingLocation = false;
      if (stateName != null) {
        _selectedState = stateName;

        _selectedStateId = states.entries
            .firstWhere(
              (entry) => entry.value == stateName,
              orElse: () => const MapEntry('', ''),
            )
            .key;

        if (_selectedStateId != null && _selectedStateId!.isNotEmpty) {
          forecastData = _fetchForecastData(_selectedStateId!);
        }
      }
    });
  }

  final Map<String, String> states = {
    'St001': 'Perlis',
    'St002': 'Kedah',
    'St003': 'Pulau Pinang',
    'St004': 'Perak',
    'St005': 'Kelantan',
    'St006': 'Terengganu',
    'St007': 'Pahang',
    'St008': 'Selangor',
    'St009': 'WP Kuala Lumpur',
    'St010': 'WP Putrajaya',
    'St011': 'Negeri Sembilan',
    'St012': 'Melaka',
    'St013': 'Johor',
    'St501': 'Sarawak',
    'St502': 'Sabah',
    'St503': 'WP Labuan',
  };

  final Map<String, String> weather_status = {
    'Berjerebu': 'haze.png',
    'Tiada hujan': 'sunny.png',
    'Hujan': 'rainy.png',
    'Hujan di beberapa tempat': 'rainy.png',
    'Hujan di satu dua tempat': 'rainy.png',
    'Hujan di satu dua tempat di kawasan pantai': 'rainy.png',
    'Hujan di satu dua tempat di kawasan pedalaman': 'rainy.png',
    'Ribut petir': 'thunderstorm.png',
    'Ribut petir di beberapa tempat': 'thunderstorm.png',
    'Ribut petir di beberapa tempat di kawasan pedalaman Scattered':
        'thunderstorm.png',
    'Ribut petir di satu dua tempat': 'thunderstorm.png',
    'Ribut petir di satu dua tempat di kawasan pantai': 'thunderstorm.png',
    'Ribut petir di satu dua tempat di kawasan pedalaman': 'thunderstorm.png',
  };

  final Map<String, String> weatherTranslation = {
    'Tiada hujan': 'No rain',
    'Hujan': 'Rain',
    'Hujan di beberapa tempat': 'Rain in some areas',
    'Hujan di satu dua tempat': 'Isolated rain',
    'Hujan di satu dua tempat di kawasan pantai': 'Isolated coastal rain',
    'Hujan di satu dua tempat di kawasan pedalaman': 'Isolated inland rain',
    'Hujan di kebanyakan tempat': 'Rain in most areas',
    'Hujan menyeluruh': 'Widespread rain',
    'Ribut petir': 'Thunderstorms',
    'Ribut petir di beberapa tempat': 'Thunderstorms in some areas',
    'Ribut petir di beberapa tempat di kawasan pedalaman':
        'Thunderstorms in inland areas',
    'Ribut petir di kebanyakan tempat': 'Thunderstorms in most areas',
    'Ribut petir di satu dua tempat': 'Isolated thunderstorms',
    'Ribut petir di satu dua tempat di kawasan pantai':
        'Isolated coastal thunderstorms',
    'Ribut petir di satu dua tempat di kawasan pedalaman':
        'Isolated inland thunderstorms',
    'Ribut petir menyeluruh': 'Widespread thunderstorms',
    'Berjerebu': 'Hazy',
  };

  String translateWeather(String? bmText) {
    if (bmText == null) return '-';
    return weatherTranslation[bmText] ?? bmText;
  }

  Future<List<Forecast>> _fetchForecastData(String locationId) async {
    if (locationId.isEmpty) return [];

    final url = Uri.parse(
      'https://api.data.gov.my/weather/forecast?contains=$locationId@location__location_id&sort=date',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as List;
        return jsonData.map((json) => Forecast.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load forecast: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching forecast data: $e');
      return [];
    }
  }

  Future<Forecast?> getTodayForecast() async {
    if (forecastData == null) return null;

    final data = await forecastData!;

    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    try {
      return data.firstWhere((f) => f.date == todayStr);
    } catch (e) {
      return null;
    }
  }

  //get mood types
  Future<void> _fetchMoodTypes() async {
    setState(() => _isLoading = true);

    try {
      final categoriesResponse = await supabase
          .from('moodCategory')
          .select('moodCategoryId')
          .eq('status', true);

      final activeCategoryIds = (categoriesResponse as List)
          .map<int>((e) => e['moodCategoryId'] as int)
          .toList();

      if (activeCategoryIds.isEmpty) {
        setState(() {
          _moodTypes = [];
          _isLoading = false;
        });
        return;
      }

      final moodTypesResponse = await supabase
          .from('moodTypes')
          .select()
          .eq('status', true)
          .filter('moodCategoryId', 'in', '(${activeCategoryIds.join(",")})');

      setState(() {
        _moodTypes = (moodTypesResponse as List)
            .map((e) => MoodType.fromJson(e))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching mood types: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMoodRecord() async {
    if (_selectedMoodTypeId == null) return;

    final userId = await _getCurrentUserId();
    if (userId == null) {
      debugPrint('User ID not found');
      return;
    }

    final todayForecast = await _getTodayForecastFromFuture();

    final weatherSummary = todayForecast != null
        ? translateWeather(todayForecast.summary_forecast)
        : null;

    final temperature = todayForecast != null
        ? '${todayForecast.min_temp}-${todayForecast.max_temp}°C'
        : null;

    String? photoUrl;
    if (_dailyPhoto != null) {
      photoUrl = await _uploadDailyPhoto(_dailyPhoto!);
    }

    try {
      await supabase.from('moodRecords').insert({
        'user_id': userId, // ✅ THIS IS THE KEY LINE
        'moodTypesId': _selectedMoodTypeId,
        'description': noteController.text.trim(),
        'location': _selectedState,
        'weather': weatherSummary,
        'temperature': temperature,
        'picture': photoUrl,
      });

      _clearForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mood saved successfully')),
      );
    } catch (e) {
      debugPrint('Insert mood error: $e');
    }
  }

  Widget _buildMoodItem(MoodType mood) {
    final isSelected = _selectedMoodTypeId == mood.moodTypesId;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedMoodTypeId = mood.moodTypesId);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade300,
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (mood.picture != null)
              Image.network(
                mood.picture!,
                height: 36,
                width: 36,
                fit: BoxFit.contain,
              )
            else
              const Icon(Icons.mood, size: 36),
            const SizedBox(height: 6),
            Text(
              mood.name ?? '',
              style: const TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 300,
            child: GridView.builder(
              itemCount: _moodTypes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (_, index) => _buildMoodItem(_moodTypes[index]),
              shrinkWrap: true,
              physics: const AlwaysScrollableScrollPhysics(),
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "What's on your mind?",
              filled: true,
              fillColor: Colors.green.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _detectingLocation ? null : _useCurrentLocation,
                    icon: _detectingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Use my current location'),
                  ),
                ],
              ),
              if (_locationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _locationError!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),

          DropdownButtonFormField<String>(
            value: _selectedState,
            decoration: InputDecoration(
              labelText: 'Location (State)',
              filled: true,
              fillColor: Colors.green.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: states.values.map((state) {
              return DropdownMenuItem(value: state, child: Text(state));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedState = value;
                _selectedStateId = states.entries
                    .firstWhere(
                      (entry) => entry.value == value,
                      orElse: () => const MapEntry('', ''),
                    )
                    .key;
                if (_selectedStateId != null && _selectedStateId!.isNotEmpty) {
                  forecastData = _fetchForecastData(_selectedStateId!);
                }
              });
            },
          ),
          const SizedBox(height: 24),
          if (forecastData != null)
            FutureBuilder<List<Forecast>>(
              future: forecastData ?? Future.value([]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Text('Error loading forecast: ${snapshot.error}');
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                } else {
                  final now = DateTime.now();
                  final todayStr =
                      "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

                  final todayForecast = snapshot.data!.firstWhere(
                    (f) => f.date == todayStr,
                    orElse: () => snapshot.data!.first,
                  );

                  final weatherImage =
                      weather_status[todayForecast.summary_forecast] ??
                      'sunny.png';

                  return Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          'assets/images/$weatherImage',
                          width: 48,
                          height: 48,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Today: ${todayForecast.date}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Morning: ${translateWeather(todayForecast.morning_forecast)}',
                              ),
                              Text(
                                'Afternoon: ${translateWeather(todayForecast.afternoon_forecast)}',
                              ),
                              Text(
                                'Night: ${translateWeather(todayForecast.night_forecast)}',
                              ),
                              Text(
                                'Summary: ${translateWeather(todayForecast.summary_forecast)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Temp: ${todayForecast.min_temp}°C - ${todayForecast.max_temp}°C',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDailyPhoto(fromCamera: true),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDailyPhoto(fromCamera: false),
                      icon: const Icon(Icons.photo),
                      label: const Text('Choose from Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_dailyPhoto != null)
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: EdgeInsets.all(8),
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: InteractiveViewer(
                            child: Image.file(
                              _dailyPhoto!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.file(
                    _dailyPhoto!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _clearForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_selectedMoodTypeId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a mood')),
                        );
                        return;
                      }
                      _addMoodRecord();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade200,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Submit',
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
