import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';

/// Memakai project Supabase WakuPlay yang SAMA (URL + publishable key dari env.json).
Future<void> initSupabase() async {
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
}

SupabaseClient get db => Supabase.instance.client;

/// Panggil RPC lama dan ubah error Postgres jadi pesan yang bisa ditampilkan.
Future<dynamic> rpc(String name, [Map<String, dynamic>? params]) async {
  try {
    return await db.rpc(name, params: params);
  } on PostgrestException catch (e) {
    throw Exception(e.message);
  }
}
