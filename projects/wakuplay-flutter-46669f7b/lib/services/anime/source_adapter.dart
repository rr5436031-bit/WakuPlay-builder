import '../../models/anime.dart';

/// Satu adapter per sumber. Gagal di satu sumber tidak boleh merusak sumber lain.
abstract class SourceAdapter {
  String get name;
  Future<List<Anime>> home({int page = 1});
  Future<List<Anime>> search(String query, {int page = 1});
}

/// Parsing defensif: struktur JSON tiap sumber berbeda dan belum terverifikasi.
dynamic pick(Map? o, List<String> keys) {
  if (o == null) return null;
  for (final k in keys) {
    final v = o[k];
    if (v != null && v != '') return v;
  }
  return null;
}

List<dynamic> listFrom(dynamic x) {
  if (x is List) return x;
  if (x is! Map) return const [];
  for (final k in ['results', 'items', 'list', 'data', 'animes', 'anime', 'rows', 'latest', 'ongoing', 'completed']) {
    final v = x[k];
    if (v is List && v.isNotEmpty) return v;
    if (v is Map) {
      final inner = listFrom(v);
      if (inner.isNotEmpty) return inner;
    }
  }
  for (final v in x.values) {
    if (v is List && v.isNotEmpty) return v;
  }
  return const [];
}
