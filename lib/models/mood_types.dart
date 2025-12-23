class MoodType {
  final int moodTypesId;
  final int? moodCategoryId;
  final String? name;
  final String? picture;
  final bool? status;
  final int? scale;
  final DateTime createdAt;
  final bool? categoryStatus;

  MoodType({
    required this.moodTypesId,
    this.moodCategoryId,
    this.name,
    this.picture,
    this.status,
    this.scale,
    required this.createdAt,
    this.categoryStatus,
  });

  factory MoodType.fromJson(Map<String, dynamic> json) {
    return MoodType(
      moodTypesId: json['moodTypesId'] as int,
      moodCategoryId: json['moodCategoryId'] != null
          ? json['moodCategoryId'] as int
          : null,
      name: json['name'] as String?,
      picture: json['picture'] as String?,
      status: json['status'] as bool?,
      scale: json['scale'] != null ? json['scale'] as int : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      categoryStatus: json['moodCategory'] != null
          ? json['moodCategory']['status'] as bool?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moodTypesId': moodTypesId,
      'moodCategoryId': moodCategoryId,
      'name': name,
      'picture': picture,
      'status': status,
      'scale': scale,
      'created_at': createdAt.toIso8601String(),
      'moodCategory': {'status': categoryStatus},
    };
  }
}
