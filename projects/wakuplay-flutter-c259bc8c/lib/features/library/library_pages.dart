import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../detail/detail_page.dart';

Widget _poster(String? u, double w, double h) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: SizedBox(width: w, height: h, child: u == null ? Container(color: C.surface) : CachedNetworkImage(imageUrl: u, fit: BoxFit.cover, memCacheWidth: (w * 3).round())));

void _open(BuildContext c, Anime a) => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailPage(anime: a)));

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: ref.watch(favoritesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) => rows.isEmpty
                  ? const Center(child: Text('Belum ada favorit', style: TextStyle(color: C.textDim)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.52),
                      itemCount: rows.length,
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final a = Anime.fromStoreId('${r['anime_id']}', title: '${r['title']}', poster: r['poster'] as String?);
                        return GestureDetector(
                          onTap: () => _open(context, a),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: LayoutBuilder(builder: (_, c) => _poster(a.poster, c.maxWidth, c.maxHeight))),
                            const SizedBox(height: 6),
                            Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ]),
                        );
                      }),
            ),
      );
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SafeArea(
        child: Column(children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Riwayat Menonton', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
          Expanded(
            child: ref.watch(historyProvider).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (rows) => ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: rows.length,
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final dur = (r['duration'] as num?) ?? 0, pr = (r['progress'] as num?) ?? 0;
                      return GestureDetector(
                        onLongPress: () async {
                          await ref.read(libraryRepoProvider).deleteHistory(['${r['episode_id']}']);
                          ref.invalidate(historyProvider);
                        },
                        onTap: () => _open(context, Anime.fromStoreId('${r['anime_id']}', title: '${r['anime_title']}', poster: r['anime_poster'] as String?)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
                          child: Row(children: [
                            _poster(r['anime_poster'] as String?, 80, 52),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${r['anime_title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text('Episode ${r['episode_number']}', style: const TextStyle(color: C.textDim, fontSize: 12)),
                              const SizedBox(height: 6),
                              LinearProgressIndicator(value: dur > 0 ? (pr / dur).clamp(0, 1).toDouble() : 0, color: C.danger, backgroundColor: C.border, minHeight: 3),
                            ])),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
          ),
        ]),
      );
}
