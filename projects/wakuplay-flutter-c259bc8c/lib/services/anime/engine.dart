import '../../models/anime.dart';
import 'content_filter.dart';
import 'source_adapter.dart';

/// Multi-Source Anime Engine: paralel, tahan gagal sebagian, dedupe, filter dewasa.
/// adapters[0] sebaiknya legacy -> menang saat judul sama (kompatibilitas sistem lama).
class AnimeEngine {
  final List<SourceAdapter> adapters;
  AnimeEngine(this.adapters);

  Future<CatalogResult> home({int page = 1}) => _fan((a) => a.home(page: page));
  Future<CatalogResult> search(String q, {int page = 1}) => _fan((a) => a.search(q, page: page));

  Future<CatalogResult> _fan(Future<List<Anime>> Function(SourceAdapter) call) async {
    final errors = <SourceError>[];
    final lists = await Future.wait(adapters.map((a) async {
      try {
        return await call(a).timeout(const Duration(seconds: 15));
      } catch (e) {
        errors.add(SourceError(a.name, '$e'));
        return <Anime>[];
      }
    }));
    final seen = <String>{};
    final merged = <Anime>[];
    for (final l in lists) {
      for (final a in l) {
        if (isBlocked(a.title, a.genres)) continue;
        if (seen.add(a.dedupeKey)) merged.add(a);
      }
    }
    return CatalogResult(merged, errors);
  }
}
