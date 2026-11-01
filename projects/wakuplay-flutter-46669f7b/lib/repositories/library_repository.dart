import '../models/anime.dart';
import '../services/supabase/supabase_service.dart';

/// Favorit & riwayat memakai tabel LAMA `favorites` dan `watch_history` (RLS tetap berlaku).
class LibraryRepository {
  String get _uid => db.auth.currentUser!.id;

  Future<List<Map<String, dynamic>>> favorites() async =>
      List<Map<String, dynamic>>.from(await db.from('favorites').select().eq('user_id', _uid).order('created_at', ascending: false));

  Future<bool> isFavorite(String animeId) async =>
      await db.from('favorites').select('anime_id').eq('user_id', _uid).eq('anime_id', animeId).maybeSingle() != null;

  Future<void> addFavorite(Anime a) => db.from('favorites').upsert(
      {'user_id': _uid, 'anime_id': a.storeId, 'title': a.title, 'poster': a.poster},
      onConflict: 'user_id,anime_id');

  Future<void> removeFavorite(String animeId) => db.from('favorites').delete().eq('user_id', _uid).eq('anime_id', animeId);

  Future<List<Map<String, dynamic>>> history({int limit = 100}) async => List<Map<String, dynamic>>.from(
      await db.from('watch_history').select().eq('user_id', _uid).order('updated_at', ascending: false).limit(limit));

  Future<Set<String>> watchedIds(String animeId) async =>
      (await db.from('watch_history').select('episode_id').eq('user_id', _uid).eq('anime_id', animeId))
          .map<String>((r) => '${r['episode_id']}').toSet();

  Future<void> saveProgress({required Anime anime, required String episodeId, required num episodeNumber, required int progress, required int duration}) =>
      db.from('watch_history').upsert({
        'user_id': _uid,
        'anime_id': anime.storeId,
        'episode_id': episodeId,
        'episode_number': '$episodeNumber',
        'anime_title': anime.title,
        'anime_poster': anime.poster,
        'progress': progress,
        'duration': duration,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id,episode_id');

  Future<void> deleteHistory(List<String> episodeIds) =>
      db.from('watch_history').delete().eq('user_id', _uid).inFilter('episode_id', episodeIds);
}
