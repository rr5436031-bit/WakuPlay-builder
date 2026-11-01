import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/anime.dart';
import 'sanka_api.dart';
import 'source_adapter.dart';

/// Path home/search/detail/episode sudah sesuai daftar endpoint (sanka-endpoints.json). Bentuk JSON respons masih diurai heuristik.
/// Adapter 5 sumber sankavollerei lewat Edge Function `anime-multi` (alamat server tidak ditanam di APK).
/// Path home mengikuti spesifikasi. Path SEARCH di bawah adalah HIPOTESIS dan belum diuji:
/// jalankan scripts/probe-sources.sh lalu sesuaikan _searchPath / kunci JSON per sumber.
class SankaAdapter implements SourceAdapter {
  @override
  final String name;
  final SupabaseClient _db;
  SankaAdapter(this.name, this._db);

  String _homePath(int page) =>
      (name == 'animekompi' || name == 'winbu') ? '/anime/$name/home' : '/anime/$name/home?page=$page';
  String _searchPath(String q, int page) {
    final e = Uri.encodeComponent(q);
    return (name == 'animekompi' || name == 'winbu') ? '/anime/$name/search?q=$e&page=$page' : '/anime/$name/search/$e${page > 1 ? '?page=$page' : ''}';
  }

  Future<dynamic> _get(String path) async =>
      (await _db.functions.invoke('anime-multi', body: {'path': path})).data;

  List<Anime> _parse(dynamic json) {
    final out = <Anime>[];
    for (final e in listFrom(json)) {
      if (e is! Map) continue;
      final title = pick(e, ['title', 'name', 'judul'])?.toString();
      final oid = SankaApi.slugOf(e);
      if (title == null || oid == null) continue;
      final g = pick(e, ['genres', 'genre']);
      out.add(Anime(
        source: name,
        originalId: oid,
        title: title,
        poster: pick(e, ['poster', 'image', 'thumbnail', 'thumb', 'cover'])?.toString(),
        rating: double.tryParse('${pick(e, ['rating', 'score'])}'),
        status: pick(e, ['status'])?.toString().toLowerCase(),
        type: pick(e, ['type'])?.toString(),
        genres: g is List ? g.map((x) => x is Map ? '${x['title'] ?? x['name']}' : '$x').toList() : const [],
        detailUrl: pick(e, ['href', 'url', 'link'])?.toString(),
      ));
    }
    return out;
  }

  @override
  Future<List<Anime>> home({int page = 1}) async => _parse(await _get(_homePath(page)));
  @override
  Future<List<Anime>> search(String query, {int page = 1}) async => _parse(await _get(_searchPath(query, page)));
}
