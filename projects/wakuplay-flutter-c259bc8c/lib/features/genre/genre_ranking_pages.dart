import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/anime_poster_card.dart';
import '../../models/anime.dart';
import '../detail/detail_page.dart';

void _open(BuildContext c, Anime a) => Navigator.push(c, MaterialPageRoute(builder: (_) => DetailPage(anime: a)));

class GenrePage extends ConsumerStatefulWidget {
  const GenrePage({super.key});
  @override
  ConsumerState<GenrePage> createState() => _G();
}

class _G extends ConsumerState<GenrePage> {
  String? sel; List<Anime> items = []; bool loading = false; String? err;

  Future<void> _pick(String id) async {
    setState(() { sel = id; loading = true; err = null; });
    try { final r = await ref.read(legacyApiProvider).byGenre(id); if (mounted) setState(() { items = r; loading = false; }); }
    catch (e) { if (mounted) setState(() { err = '$e'; loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final g = ref.watch(genresProvider);
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Genres')),
      body: g.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final x in list)
              GestureDetector(onTap: () => _pick(x['id']!), child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: sel == x['id'] ? C.pillBlue : C.surface, borderRadius: BorderRadius.circular(20)),
                child: Text(x['name']!, style: const TextStyle(fontSize: 13)))),
          ])),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          if (err != null) Text(err!, style: const TextStyle(color: C.danger)),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.52),
            itemCount: items.length,
            itemBuilder: (_, i) => AnimePosterCard(anime: items[i], onTap: () => _open(context, items[i])),
          )),
        ]),
      ),
    );
  }
}

class RankingPage extends ConsumerWidget {
  const RankingPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Peringkat Anime')),
        body: ref.watch(rankingProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (rows) => ListView.builder(
                padding: const EdgeInsets.all(14), itemCount: rows.length,
                itemBuilder: (_, i) {
                  final (a, v) = rows[i];
                  return ListTile(
                    onTap: () => _open(context, a),
                    leading: Container(width: 36, height: 28, alignment: Alignment.center,
                        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(8)),
                        child: Text('#${i + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800))),
                    title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('$v views', style: const TextStyle(color: C.textDim)),
                  );
                }),
            ),
      );
}
