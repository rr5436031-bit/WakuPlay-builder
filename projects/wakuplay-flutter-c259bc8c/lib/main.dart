import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env.dart';
import 'core/prefs.dart';
import 'services/supabase/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  if (!Env.ok) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('env.json belum dipakai: build dengan --dart-define-from-file=env.json')))));
    return;
  }
  await Prefs.init();
  await initSupabase();
  runApp(const ProviderScope(child: WakuPlayApp()));
}
