import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/anime_poster_card.dart';
import '../../core/widgets/app_search_bar.dart';
import '../account/account_page.dart';
import '../chat/global_chat_page.dart';
import '../detail/detail_page.dart';
import '../../models/anime.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../search/search_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = ref.watch(homeCatalogProvider);
    final sec = ref.watch(legacyHomeProvider).valueOrNull ?? const <String, List<Anime>>{};
    void open(Anime a) => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(anime: a)));
    return SafeArea(
      bottom: false,
      child: cat.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat: $e')),
        data: (r) => CustomScrollView(
          cacheExtent: 600,
          slivers: [
            SliverPadding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), sliver: SliverToBoxAdapter(child: AppSearchBar(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()))))),
            if (r.errors.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text('Sumber bermasalah: ${r.errors.map((e) => e.source).join(', ')}',
                      style: const TextStyle(color: C.accent, fontSize: 12)),
                ),
              ),
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
              Expanded(child: _Pill(Icons.chat_bubble_outline, 'Global Chat', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GlobalChatPage())))),
              const SizedBox(width: 10),
              _Pill(Icons.person_outline, 'Akun', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()))),
            ]))),
            if ((sec['slider'] ?? const []).isNotEmpty)
              SliverToBoxAdapter(child: SizedBox(height: 190, child: PageView.builder(
                controller: PageController(viewportFraction: 0.92),
                itemCount: sec['slider']!.length,
                itemBuilder: (_, i) {
                  final a = sec['slider']![i];
                  return GestureDetector(onTap: () => open(a), child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                    child: ClipRRect(borderRadius: BorderRadius.circular(C.radiusCard), child: Stack(fit: StackFit.expand, children: [
                      Container(color: C.surface),
                      if ((a.cover ?? a.poster) != null) CachedNetworkImage(imageUrl: (a.cover ?? a.poster)!, fit: BoxFit.cover, memCacheWidth: 800),
                      Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87]))),
                      Positioned(left: 12, right: 12, bottom: 10, child: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    ])),
                  ));
                },
              ))),
            for (final k in const [['hot', 'Hot Anime'], ['fresh', 'Anime Terbaru'], ['popular', 'Populer']])
              if ((sec[k[0]] ?? const []).isNotEmpty) ...[
                SliverPadding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), sliver: SliverToBoxAdapter(child: Text(k[1], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)))),
                SliverToBoxAdapter(child: SizedBox(height: 230, child: ListView.separated(
                  scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: sec[k[0]]!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => SizedBox(width: 118, child: AnimePosterCard(anime: sec[k[0]]![i], onTap: () => open(sec[k[0]]![i]))),
                ))),
              ],
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              sliver: SliverToBoxAdapter(child: Text('Katalog Semua Sumber', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.52),
                itemCount: r.items.length,
                itemBuilder: (_, i) => AnimePosterCard(anime: r.items[i], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(anime: r.items[i])))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData i; final String t; final VoidCallback f;
  const _Pill(this.i, this.t, this.f);
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: f, child: Container(
        height: 44, padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(22)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(i, size: 20, color: C.primary), const SizedBox(width: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.w600))]),
      ));
}
