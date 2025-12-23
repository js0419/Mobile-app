import 'package:supabase_flutter/supabase_flutter.dart';

const String supabaseUrl = 'https://cfxlszlqcvjxrdwxcaci.supabase.co';
const String supabaseKey = 'sb_secret_ArXfGwmFJKu_MpAcTDfVDA_3RSvhw2j';

Future<void> initSupabase() async {
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
}

final supabase = Supabase.instance.client;
