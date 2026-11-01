import 'dart:convert';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../supabase/supabase_service.dart';
import 'source_adapter.dart';

/// Bentuk JSON tiap sumber BELUM terdokumentasi, jadi parsing di sini heuristik & defensif.
/// Gunakan halaman "Diagnosa Sumber" (Settings) untuk melihat respons mentah bila ada yang kosong.
class SankaApi {
  static const noEpisodeEndpoint = {'alqanime', 'nimegami'};

  static Future<dynamic> get(String path) async {
    final d = (await db.functions.invoke('anime-multi', body: {'path': path})).data;
    if (d is String) { try { return jsonDecode(d); } catch (_) { return d; } }
    return d;
  }

  static List<String> detailPaths(String src, String id) {
    final e = Uri.encodeComponent(id);
    return switch (src) {
      'winbu' => ['/anime/winbu/anime/$e', '/anime/winbu/series/$e', '/anime/winbu/film/$e'],
      'nimegami' => ['/anime/nimegami/detail/$e', '/anime/nimegami/live-action/$e', '/anime/nimegami/drama/$e'],
      _ => ['/anime/$src/detail/$e'],
    };
  }

  static String? episodePath(String src, String epId) =>
      noEpisodeEndpoint.contains(src) ? null : '/anime/$src/episode/${Uri.encodeComponent(epId)}';

  /// "https://x/anime/animekompi/detail/abc?x=1" -> "abc"
  static String? slugOf(Map e) {
    final v = pick(e, ['slug', 'id', 'episode_id', 'episodeId', 'endpoint', 'url', 'link', 'href', 'path'])?.toString();
    if (v == null || v.isEmpty) return null;
    final noQ = v.split('?').first.split('#').first;
    final parts = noQ.split('/').where((x) => x.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.last;
  }

  static final _img = RegExp(r'\.(jpe?g|png|webp|gif|svg|css|js|ico|woff2?)(\?|$)', caseSensitive: false);

  static bool isStreamUrl(String u) => RegExp(r'^https?://', caseSensitive: false).hasMatch(u) && !_img.hasMatch(u);

  /// Kumpulkan tautan stream (direct/embed) dari JSON mana pun. Bagian "download"/"batch" dilewati.
  static List<StreamSource> collectStreams(dynamic json) {
    final out = <StreamSource>[]; final seen = <String>{};
    void add(String u, String label) {
      u = u.trim();
      if (!isStreamUrl(u) || !seen.add(u)) return;
      out.add(StreamSource(u, label));
    }
    void html(String s, String label) {
      for (final m in RegExp(r'''src\s*=\s*["']([^"']+)["']''', caseSensitive: false).allMatches(s)) { add(m.group(1)!.startsWith('//') ? 'https:${m.group(1)}' : m.group(1)!, label); }
    }
    void walk(dynamic v, String path, String label) {
      final p = path.toLowerCase();
      if (p.contains('download') || p.contains('batch') || p.contains('navigation') || p.contains('related')) return;
      if (v is String) {
        if (v.contains('<iframe')) { html(v, label); }
        else if (isStreamUrl(v)) { add(v, label); }
        return;
      }
      if (v is List) { for (final x in v) { walk(x, path, label); } return; }
      if (v is Map) {
        final l = pick(v, ['server', 'name', 'label', 'quality', 'provider', 'resolution', 'title'])?.toString() ?? label;
        for (final e in v.entries) { walk(e.value, '$path/${e.key}', e.value is String ? l : label); }
      }
    }
    walk(json, '', '');
    return out;
  }

  /// Cari daftar episode di JSON detail: kunci bernama episode/eps, atau daftar map yang mirip episode.
  static List<Episode> collectEpisodes(dynamic root, String src) {
    List<dynamic>? best;
    void visit(dynamic v, String key, int depth) {
      if (depth > 6 || best != null) return;
      if (v is List && v.isNotEmpty && v.first is Map && RegExp(r'episode|eps|list_ep|chapters', caseSensitive: false).hasMatch(key) && !RegExp(r'download|batch', caseSensitive: false).hasMatch(key)) {
        if (v.whereType<Map>().any((m) => slugOf(m) != null)) { best = v; return; }
      }
      if (v is Map) { for (final e in v.entries) { visit(e.value, '${e.key}', depth + 1); } }
      else if (v is List) { for (final x in v.take(3)) { visit(x, key, depth + 1); } }
    }
    visit(root, '', 0);
    if (best == null) { // cadangan: daftar map yang judulnya mengandung "episode"
      void v2(dynamic v, int d) {
        if (d > 6 || best != null) return;
        if (v is List && v.length >= 1 && v.first is Map && v.whereType<Map>().any((m) => RegExp(r'epis|eps|\bep\b', caseSensitive: false).hasMatch('${pick(m, ['title', 'name', 'episode'])}') && slugOf(m) != null)) { best = v; return; }
        if (v is Map) { for (final x in v.values) { v2(x, d + 1); } } else if (v is List) { for (final x in v.take(3)) { v2(x, d + 1); } }
      }
      v2(root, 0);
    }
    final out = <Episode>[]; final seen = <String>{};
    for (final raw in (best ?? const [])) {
      if (raw is! Map) continue;
      final id = slugOf(raw); if (id == null || !seen.add(id)) continue;
      final title = pick(raw, ['title', 'name', 'episode_title', 'judul'])?.toString();
      final numRaw = pick(raw, ['number', 'episode', 'episode_number', 'eps', 'ep', 'no']) ?? RegExp(r'(?:episode|eps?)\.?\s*(\d+(?:\.\d+)?)', caseSensitive: false).firstMatch('${title ?? ''} $id')?.group(1);
      out.add(Episode(id, num.tryParse('$numRaw') ?? out.length + 1, title, noEpisodeEndpoint.contains(src) ? collectStreams(raw) : const []));
    }
    out.sort((a, b) => a.number.compareTo(b.number));
    return out;
  }

  /// Ambil info + episode dari endpoint detail (winbu/nimegami dicoba beberapa jenis path).
  static Future<({Map<String, dynamic> info, List<Episode> eps, dynamic raw})> detail(String src, String id) async {
    Object? lastErr; dynamic raw;
    for (final path in detailPaths(src, id)) {
      try {
        raw = await get(path);
        final eps = collectEpisodes(raw, src);
        final info = _info(raw);
        if (info['title'] != null || eps.isNotEmpty) return (info: info, eps: eps, raw: raw);
      } catch (e) { lastErr = e; }
    }
    if (raw != null) return (info: _info(raw), eps: const <Episode>[], raw: raw);
    throw Exception('Detail $src gagal dimuat: $lastErr');
  }

  static Map<String, dynamic> _info(dynamic raw) {
    Map? best;
    void visit(dynamic v, int d) {
      if (d > 4 || best != null) return;
      if (v is Map) {
        if (pick(v, ['title', 'name', 'judul']) != null && pick(v, ['synopsis', 'sinopsis', 'description', 'desc', 'overview', 'poster', 'image', 'thumbnail', 'cover']) != null) { best = v; return; }
        for (final x in v.values) { visit(x, d + 1); }
      } else if (v is List) { for (final x in v.take(2)) { visit(x, d + 1); } }
    }
    visit(raw, 0);
    final o = best ?? const {};
    final g = pick(o, ['genres', 'genre', 'categories']);
    return {
      'title': pick(o, ['title', 'name', 'judul']),
      'poster': pick(o, ['poster', 'image', 'thumbnail', 'thumb', 'cover']),
      'synopsis': pick(o, ['synopsis', 'sinopsis', 'description', 'desc', 'overview']),
      'status': pick(o, ['status']),
      'rating': pick(o, ['score', 'rating']),
      'genres': g is List ? g.map((x) => x is Map ? '${x['name'] ?? x['title'] ?? x['genre'] ?? ''}' : '$x').where((x) => x.isNotEmpty).toList() : (g is String ? g.split(',').map((x) => x.trim()).toList() : <String>[]),
    };
  }

  /// Ambil stream satu episode. Mengembalikan daftar (direct dulu) dan JSON mentah untuk diagnosa.
  static Future<({List<StreamSource> streams, dynamic raw})> streams(String src, Episode ep) async {
    if (ep.links.isNotEmpty) return (streams: ep.links, raw: {'links': [for (final l in ep.links) l.url]});
    final path = episodePath(src, ep.id);
    if (path == null) return (streams: const <StreamSource>[], raw: null);
    final raw = await get(path);
    var list = collectStreams(raw);
    if (list.isEmpty && src == 'animekompi') { try { final m = await get('$path/mirrors'); list = collectStreams(m); } catch (_) {} }
    if (list.isEmpty && src == 'winbu') list = await _winbuServers(raw);
    list.sort((a, b) => (b.isDirect ? 1 : 0).compareTo(a.isDirect ? 1 : 0));
    return (streams: list, raw: raw);
  }

  /// Winbu: episode berisi daftar server (post/nume/type) yang harus diminta ke /server.
  static Future<List<StreamSource>> _winbuServers(dynamic raw) async {
    final reqs = <Map>[];
    void walk(dynamic v, int d) {
      if (d > 6) return;
      if (v is Map) {
        if (v['post'] != null && v['nume'] != null) { reqs.add(v); return; }
        for (final x in v.values) { walk(x, d + 1); }
      } else if (v is List) { for (final x in v) { walk(x, d + 1); } }
    }
    walk(raw, 0);
    final out = <StreamSource>[];
    for (final r in reqs.take(5)) {
      try {
        final q = 'post=${Uri.encodeComponent('${r['post']}')}&nume=${Uri.encodeComponent('${r['nume']}')}&type=${Uri.encodeComponent('${r['type'] ?? 'schtml'}')}';
        final res = await get('/anime/winbu/server?$q');
        final name = pick(r, ['name', 'server', 'label', 'title'])?.toString() ?? 'Server ${r['nume']}';
        for (final s in collectStreams(res)) { out.add(StreamSource(s.url, name)); }
      } catch (_) {}
    }
    return out;
  }
}
