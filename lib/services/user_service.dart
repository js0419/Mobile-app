import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tikwei_assignment/models/user_model.dart';

class UserService {
  static final _supabase = Supabase.instance.client;

  // ========================
  // AUTH
  // ========================

  static Future<void> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (authResponse.user == null) {
      throw Exception('Registration failed');
    }
  }

  static Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.flutter://login-callback',
    );
  }

  /// ✅ LOGOUT（可以安心用）
  static Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // ========================
  // USER CREATE (POST LOGIN)
  // ========================

  static Future<void> handlePostLogin({String? nameFromRegister}) async {
    final authUser = _supabase.auth.currentUser;

    if (authUser == null || authUser.email == null) {
      throw Exception('User not authenticated');
    }

    final existingUser = await _supabase
        .from('user')
        .select('user_id')
        .eq('user_email', authUser.email!)
        .maybeSingle();

    if (existingUser == null) {
      await _supabase.from('user').insert({
        'user_email': authUser.email,
        'user_name': nameFromRegister ?? 'User',
        'user_icon': 'assets/images/defaultIcon.png',
        'user_type': 'user',
        'user_status': true,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ========================
  // FETCH
  // ========================

  static Future<List<UserModel>> fetchAllUsers() async {
    final response = await _supabase
        .from('user')
        .select(
      'user_id, user_name, user_email, user_gender, user_status, user_type, created_at',
    )
        .eq('user_type', 'user')
        .order('created_at');

    debugPrint('RAW RESPONSE: $response');
    return (response as List)
        .map((json) {
      debugPrint('ROW: $json');
      return UserModel.fromJson(json);
    })
        .toList();

  }

  static Future<UserModel> getUserById(int userId) async {
    final data = await _supabase
        .from('user')
        .select()
        .eq('user_id', userId)
        .single();

    return UserModel.fromJson(data);
  }

  static Future<String?> getCurrentUserRole() async {
    final authUser = _supabase.auth.currentUser;
    if (authUser == null || authUser.email == null) return null;

    final data = await _supabase
        .from('user')
        .select('user_type')
        .eq('user_email', authUser.email!)
        .single();

    return data['user_type'];
  }

  // ========================
  // UPDATE
  // ========================

  static Future<void> updateUserStatus({
    required String email,
    required bool newStatus,
  }) async {
    await _supabase
        .from('user')
        .update({'user_status': newStatus})
        .eq('user_email', email);
  }
}