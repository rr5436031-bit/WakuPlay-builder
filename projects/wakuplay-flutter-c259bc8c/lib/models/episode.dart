class Episode {
  final String id;
  final num number;
  final String? title;
  /// Tautan stream bawaan (dipakai sumber yang tidak punya endpoint episode terpisah).
  final List<StreamSource> links;
  const Episode(this.id, this.number, this.title, [this.links = const []]);
}

class StreamSource {
  final String url;
  final String quality;
  const StreamSource(this.url, this.quality);
  String get label => quality.isEmpty ? Uri.tryParse(url)?.host ?? 'Server' : quality;
  bool get isHls => url.toLowerCase().contains('.m3u8');
  bool get isEmbed => !isDirect;
  bool get isDirect => isHls || RegExp(r'\.(mp4|webm|mkv)(\?|$)', caseSensitive: false).hasMatch(url);
}
