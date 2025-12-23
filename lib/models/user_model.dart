class UserModel{
  final int id;
  final String name;
  final String? icon;
  final String email;
  final String? gender;
  final String type;
  final DateTime createdAt;
  final bool status;

  UserModel({
    required this.id,
    required this.name,
    this.icon,
    required this.email,
    this.gender,
    required this.type,
    required this.createdAt,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json){
    return UserModel(
        id: json['user_id'],
        name: json['user_name'],
        icon: json['user_icon'],
        email: json['user_email'],
        gender: json['user_gender'],
        type: json['user_type'],
        createdAt: DateTime.parse(json['created_at']),
        status: json['user_status']
    );
  }
}