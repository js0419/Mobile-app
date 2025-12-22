import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

const String supabaseUrl = 'https://cfxlszlqcvjxrdwxcaci.supabase.co';
const String supabaseKey = 'sb_secret_ArXfGwmFJKu_MpAcTDfVDA_3RSvhw2j';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const MyApp());
}



