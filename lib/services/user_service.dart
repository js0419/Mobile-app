import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final _supabase = Supabase.instance.client;

  static Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final user = authResponse.user;
    if (user == null) {
      throw Exception('Registration failed');
    }
  }

  static Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback',
    );
  }

  static Future<void> handlePostLogin({
    String? nameFromRegister,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null || user.email == null) {
      throw Exception('User not authenticated');
    }

    final existingUser = await _supabase
        .from('user')
        .select('user_email')
        .eq('user_email', user.email!)
        .maybeSingle();

    if (existingUser == null) {
      await _supabase.from('user').insert({
        'user_email': user.email,
        'user_name': nameFromRegister ?? 'User',
        'user_icon': 'assets/images/defaultIcon.png',
        'user_type': 'user',
        'user_status': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    final response = await _supabase
        .from('user')
        .select(
      'user_name, user_email, user_gender, user_status, user_type, created_at',
    )
        .order('created_at');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> logout() async {
    await Supabase.instance.client.auth.signOut();
  }
}