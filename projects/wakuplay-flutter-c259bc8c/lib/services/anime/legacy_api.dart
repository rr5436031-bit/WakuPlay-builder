import '../../models/anime.dart';
import '../../models/episode.dart';
import '../supabase/supabase_service.dart';
import 'source_adapter.dart';

/// Detail, episode, stream untuk API lama (Edge Function anime-api). Path & parsing mengikuti normalize.js v185.
class LegacyApi {
  Future<dynamic> _get(String p) async => (await db.functions.invoke('anime-api', body: {'path': p})).data;

  dynamic _unwrap(dynamic r) => (r is Map && r['data'] != null) ? r['data'] : r;


  List<Anime> _animes(dynamic r) => [
        for (final e in listFrom(r))
          if (e is Map && pick(e, ['id', 'anime_id', 'animeId']) != null)
            Anime(
              source: 'legacy',
              originalId: '${pick(e, ['id', 'anime_id', 'animeId'])}',
              title: '${pick(e, ['title', 'name', 'judul']) ?? 'Tanpa judul'}',
              poster: pick(e, ['image_poster', 'poster', 'poster_url', 'image', 'thumbnail', 'cover'])?.toString(),
              cover: pick(e, ['image_cover', 'cover', 'banner', 'backdrop', 'poster'])?.toString(),
              rating: double.tryParse('${pick(e, ['score', 'rating', 'mean'])}'),
              status: pick(e, ['status'])?.toString(),
            )
      ];

  /// Seksi beranda lama: slider, hot, new, popular (kunci sama dengan toHome di normalize.js).
  Future<Map<String, List<Anime>>> homeSections() async {
    final d = _unwrap(await _get('/homepage'));
    final m = d is Map ? d : const {};
    List<Anime> sec(List<String> keys) {
      for (final k in keys) { if (m[k] != null) return _animes(m[k]); }
      return const [];
    }
    return {
      'slider': sec(['slider', 'sliders', 'banner', 'banners']),
      'hot': sec(['hot', 'hot_anime', 'hotAnime']),
      'fresh': sec(['new', 'new_anime', 'newAnime', 'latest']),
      'popular': sec(['popular']),
    };
  }

  /// day: MONDAY..SUNDAY
  Future<List<Map<String, dynamic>>> schedule(String day) async {
    final r = _unwrap(await _get('/schedule?day=$day'));
    final out = <Map<String, dynamic>>[];
    for (final e in listFrom(r)) {
      if (e is! Map) continue;
      final a = _animes([e]);
      if (a.isEmpty) continue;
      out.add({'anime': a.first, 'time': pick(e, ['time', 'release_time', 'broadcast_time', 'jam', 'airing_at'])?.toString() ?? '', 'episode': pick(e, ['episode', 'episode_number', 'latest_episode'])?.toString()});
    }
    out.sort((x, y) => '${x['time']}'.compareTo('${y['time']}'));
    return out;
  }


  Future<List<Map<String, String>>> genres() async {
    final out = <Map<String, String>>[];
    for (final g in listFrom(_unwrap(await _get('/genres')))) {
      if (g is String) { out.add({'id': g, 'name': g}); continue; }
      if (g is! Map) continue;
      final name = pick(g, ['name', 'title', 'label'])?.toString();
      if (name == null) continue;
      out.add({'id': '${pick(g, ['id', 'slug', 'value']) ?? name}', 'name': name});
    }
    return out;
  }

  Future<List<Anime>> byGenre(String genreId, {int page = 1}) async =>
      _animes(_unwrap(await _get('/search?genre_in=${Uri.encodeQueryComponent(genreId)}${page > 1 ? '&page=$page' : ''}')));

  Future<Anime?> brief(String id) async {
    try {
      final d = await detail(id);
      if (d['title'] == null) return null;
      return Anime(source: 'legacy', originalId: id, title: '${d['title']}', poster: d['poster']?.toString(), rating: double.tryParse('${d['rating']}'), status: d['status']?.toString());
    } catch (_) { return null; }
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final d = _unwrap(await _get('/anime/${Uri.encodeComponent(id)}'));
    if (d is! Map) return {};
    final o = (d['anime'] is Map ? d['anime'] : d['detail'] is Map ? d['detail'] : d) as Map;
    return {
      'title': pick(o, ['title', 'name', 'judul']),
      'poster': pick(o, ['image_poster', 'poster', 'poster_url', 'image', 'thumbnail']),
      'cover': pick(o, ['image_cover', 'cover', 'banner', 'poster']),
      'synopsis': pick(o, ['synopsis', 'sinopsis', 'description']),
      'status': pick(o, ['status']),
      'rating': pick(o, ['score', 'rating']),
      'genres': (pick(o, ['genres', 'genre']) is List)
          ? (pick(o, ['genres', 'genre']) as List).map((g) => g is Map ? '${g['name'] ?? g['title']}' : '$g').toList()
          : <String>[],
    };
  }

  /// Catatan: API membagi episode per halaman (+-30). Loop sampai kosong / tidak ada kemajuan.
  Future<List<Episode>> episodes(String id) async {
    final out = <String, Episode>{};
    for (var page = 1; page <= 40; page++) {
      final r = await _get('/anime/${Uri.encodeComponent(id)}/episodes?page=$page');
      final arr = listFrom(_unwrap(r));
      if (arr.isEmpty) break;
      final before = out.length;
      for (var i = 0; i < arr.length; i++) {
        final o = arr[i];
        if (o is! Map) continue;
        final eid = pick(o, ['id', 'episode_id', 'episodeId']);
        if (eid == null) continue;
        final title = pick(o, ['title', 'name'])?.toString();
        var n = pick(o, ['number', 'episode', 'episode_number', 'eps', 'ep', 'no']);
        if (n == null && title != null) {
          final m = RegExp(r'(?:episode|eps?)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch(title);
          n = m?.group(1);
        }
        out['$eid'] = Episode('$eid', num.tryParse('$n') ?? out.length + 1, title);
      }
      if (out.length == before) break;
    }
    final l = out.values.toList()..sort((a, b) => a.number.compareTo(b.number));
    return l;
  }

  Future<List<StreamSource>> streams(String episodeId) async {
    final r = _unwrap(await _get('/episode/${Uri.encodeComponent(episodeId)}/stream'));
    final found = <StreamSource>[];
    void push(dynamic u, dynamic q) {
      if (u is String && RegExp(r'^https?://', caseSensitive: false).hasMatch(u)) found.add(StreamSource(u, q?.toString() ?? 'Auto'));
    }
    void walk(dynamic v, dynamic q) {
      if (v is String) return push(v, q);
      if (v is List) return v.forEach((x) => walk(x, q));
      if (v is! Map) return;
      final u = pick(v, ['url', 'src', 'file', 'link', 'stream', 'stream_url', 'hls', 'm3u8', 'mp4']);
      final ql = pick(v, ['quality', 'label', 'resolution', 'res', 'name']);
      if (u is String) return push(u, ql ?? q);
      v.forEach((k, val) {
        if (const {'subtitle', 'subtitles', 'captions', 'tracks', 'thumbnail', 'poster', 'image', 'cover'}.contains(k)) return;
        if (val is Map || val is List) walk(val, RegExp(r'^\d{3,4}p?$').hasMatch('$k') ? k : q);
        else if (val is String && RegExp(r'^\d{3,4}p?$').hasMatch('$k')) push(val, k);
      });
    }
    walk(r, null);
    final seen = <String>{};
    final u = found.where((s) => seen.add(s.url)).toList();
    int qn(StreamSource s) => int.tryParse(s.quality.replaceAll(RegExp(r'\D'), '')) ?? 0;
    u.sort((a, b) => qn(b).compareTo(qn(a)));
    return u;
  }
}
