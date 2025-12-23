class MoodCategory {
  final String moodCategoryId;
  final String name;
  final bool status;

  MoodCategory({
    required this.moodCategoryId,
    required this.name,
    required this.status,
  });

  factory MoodCategory.fromJson(Map<String, dynamic> json) {
    return MoodCategory(
      moodCategoryId: json['moodCategoryId'].toString(),
      name: json['name'] as String,
      status: json['status'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moodCategoryId': moodCategoryId,
      'name': name,
      'status': status,
    };
  }
}
