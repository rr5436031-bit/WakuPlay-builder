/// Penyaring konten dewasa (aman untuk pengguna remaja).
const _blockedGenres = {'hentai', 'ecchi', 'adult', 'erotica', 'mature', 'smut', 'xxx'};
const _blockedWords = ['hentai', 'uncensored', '18+', 'r18', 'xxx'];

bool isBlocked(String title, Iterable<String> genres) {
  final t = title.toLowerCase();
  if (_blockedWords.any(t.contains)) return true;
  return genres.any((g) => _blockedGenres.contains(g.toLowerCase().trim()));
}
