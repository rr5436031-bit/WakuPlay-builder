// Diisi saat build lewat --dart-define-from-file=env.json
// Hanya kunci PUBLISHABLE/anon yang boleh ada di sini. JANGAN taruh service_role key.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static bool get ok => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}

/// Versi aplikasi (samakan dengan pubspec.yaml). Dipakai pengecekan update.
const appVersion = '1.8.5';
