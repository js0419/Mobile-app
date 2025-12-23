class MoodRecord {
  final int? moodRecordsId;
  final int moodTypesId;
  final int? userId;
  final String? description;
  final String? location;
  final String? weather;
  final String? temperature;
  final String? picture;
  final DateTime? createdAt;

  MoodRecord({
    this.moodRecordsId,
    required this.moodTypesId,
    this.userId,
    this.description,
    this.location,
    this.weather,
    this.temperature,
    this.picture,
    this.createdAt,
  });

  factory MoodRecord.fromJson(Map<String, dynamic> json) {
    return MoodRecord(
      moodRecordsId: json['moodRecordsId'] as int?,
      moodTypesId: json['moodTypesId'] as int,
      userId: json['user_id'] as int?,
      description: json['description'] as String?,
      location: json['location'] as String?,
      weather: json['weather'] as String?,
      temperature: json['temperature'] as String?,
      picture: json['picture'] as String?,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moodTypesId': moodTypesId,
      'user_id': userId,
      'description': description,
      'location': location,
      'weather': weather,
      'temperature': temperature,
      'picture': picture,
    };
  }
}
