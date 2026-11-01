import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/env.dart';
import '../notify/push_service.dart';
import '../supabase/supabase_service.dart';

/// Sama seperti auth.js lama: Google native -> idToken -> supabase.auth.signInWithIdToken.
/// Hasilnya user UUID yang sama dengan akun WakuPlay lama (tidak ada registrasi baru).
class AuthService {
  // serverClientId = Web Client ID (nilai sama dengan VITE_GOOGLE_WEB_CLIENT_ID)
  final _google = GoogleSignIn(serverClientId: Env.googleWebClientId, scopes: ['email', 'profile']);

  Future<void> signInWithGoogle() async {
    final acc = await _google.signIn();
    if (acc == null) throw Exception('Login dibatalkan');
    final auth = await acc.authentication;
    final idToken = auth.idToken;
    if (idToken == null) throw Exception('Token Google tidak diterima');
    await db.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
    // Profil lama dipastikan ada lewat RPC lama (tanpa membuat tabel baru).
    try { await db.rpc('ensure_profile'); } catch (_) {}
  }

  Future<void> signOut() async {
    await PushService.clear();
    try { await _google.signOut(); } catch (_) {}
    await db.auth.signOut();
  }

  User? get user => db.auth.currentUser;
  Stream<AuthState> get changes => db.auth.onAuthStateChange;
}
