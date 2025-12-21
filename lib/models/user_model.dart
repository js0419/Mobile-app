class UserModel{
  final int id;
  final String name;
  final String icon;
  final String email;
  final String? gender;
  final String type;
  final DateTime createAt;
  final bool status;

  UserModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.email,
    required this.gender,
    required this.type,
    required this.createAt,
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
        createAt: DateTime.parse(json['create_at']),
        status: json['user_status']
    );
  }
}