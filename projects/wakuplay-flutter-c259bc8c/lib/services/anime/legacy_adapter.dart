import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/anime.dart';
import 'source_adapter.dart';

/// API anime WakuPlay lama (Edge Function `anime-api`). DIPERTAHANKAN, bukan diganti.
/// Path yang diizinkan server: /homepage, /search, /genres, /schedule, /anime/:id,
/// /anime/:id/episodes, /episode/:id/stream
class LegacyAdapter implements SourceAdapter {
  @override
  String get name => 'legacy';
  final SupabaseClient _db;
  LegacyAdapter(this._db);

  Future<dynamic> _get(String path) async =>
      (await _db.functions.invoke('anime-api', body: {'path': path})).data;

  List<Anime> _parse(dynamic json) => [
        for (final e in listFrom(json))
          if (e is Map && pick(e, ['title', 'name']) != null && pick(e, ['id', 'slug']) != null)
            Anime(
              source: 'legacy',
              originalId: '${pick(e, ['id', 'slug'])}',
              title: '${pick(e, ['title', 'name'])}',
              poster: pick(e, ['poster', 'image', 'cover'])?.toString(),
              rating: double.tryParse('${pick(e, ['rating', 'score'])}'),
              status: pick(e, ['status'])?.toString().toLowerCase(),
            )
      ];

  @override
  Future<List<Anime>> home({int page = 1}) async => _parse(await _get('/homepage'));
  @override
  Future<List<Anime>> search(String query, {int page = 1}) async =>
      _parse(await _get('/search?q=${Uri.encodeQueryComponent(query)}&page=$page'));
}
