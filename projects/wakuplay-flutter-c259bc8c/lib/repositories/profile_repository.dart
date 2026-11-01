import '../services/supabase/supabase_service.dart';

/// Hanya MEMBACA lewat RPC/tabel lama. Role, XP, saldo, Premium tidak pernah dihitung di klien.
class ProfileRepository {
  Future<Map<String, dynamic>?> myPublicProfile(String uid) async {
    final r = await db.rpc('get_public_profile', params: {'p_uid': uid});
    if (r is Map<String, dynamic>) return r;
    if (r is List && r.isNotEmpty && r.first is Map<String, dynamic>) return r.first as Map<String, dynamic>;
    return null;
  }

  Future<num?> myGold() async {
    final r = await db.rpc('wp_gold');
    return r is num ? r : num.tryParse('$r');
  }
}
