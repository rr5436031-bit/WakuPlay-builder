/// Model tunggal hasil normalisasi semua sumber.
class Anime {
  final String id; // "<source>:<originalId>"
  final String source; // legacy | animekompi | winbu | alqanime | donghub | nimegami
  final String originalId;
  final String title;
  final String? poster;
  final String? cover;
  final String? synopsis;
  final double? rating;
  final String? status;
  final String? type;
  final List<String> genres;
  final int? episodes;
  final String? detailUrl;

  Anime({
    required this.source,
    required this.originalId,
    required this.title,
    this.poster,
    this.cover,
    this.synopsis,
    this.rating,
    this.status,
    this.type,
    this.genres = const [],
    this.episodes,
    this.detailUrl,
  }) : id = '$source:$originalId';

  /// Kunci penyimpanan di database lama (favorites/watch_history/comments): sumber lama tetap polos, sumber baru diberi awalan.
  String get storeId => source == 'legacy' ? originalId : id;
  String epKey(String episodeId) => source == 'legacy' ? episodeId : '$source:$episodeId';

  static const sources = {'animekompi', 'winbu', 'alqanime', 'donghub', 'nimegami'};
  factory Anime.fromStoreId(String sid, {required String title, String? poster}) {
    final i = sid.indexOf(':');
    if (i > 0 && sources.contains(sid.substring(0, i))) return Anime(source: sid.substring(0, i), originalId: sid.substring(i + 1), title: title, poster: poster);
    return Anime(source: 'legacy', originalId: sid, title: title, poster: poster);
  }

  /// Kunci dedupe berdasarkan judul ternormalisasi (season berbeda tetap terpisah).
  String get dedupeKey => title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class SourceError {
  final String source;
  final String message;
  const SourceError(this.source, this.message);
}

class CatalogResult {
  final List<Anime> items;
  final List<SourceError> errors;
  const CatalogResult(this.items, this.errors);
}
