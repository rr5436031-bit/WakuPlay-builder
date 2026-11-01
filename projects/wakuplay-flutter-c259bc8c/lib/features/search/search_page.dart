import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/anime_poster_card.dart';
import '../../models/anime.dart';
import '../detail/detail_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _S();
}

class _S extends ConsumerState<SearchPage> {
  Timer? _t;
  CatalogResult? res;
  bool loading = false;

  void _onChanged(String q) {
    _t?.cancel(); // debounce 450ms
    if (q.trim().length < 2) return setState(() => res = null);
    _t = Timer(const Duration(milliseconds: 450), () async {
      setState(() => loading = true);
      final r = await ref.read(animeEngineProvider).search(q.trim());
      if (mounted) setState(() { res = r; loading = false; });
    });
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                onChanged: _onChanged,
                decoration: InputDecoration(
                  hintText: 'Cari Anime Di Sini',
                  prefixIcon: const Icon(Icons.search),
                  filled: true, fillColor: C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (loading) const LinearProgressIndicator(minHeight: 2),
            if (res != null && res!.errors.isNotEmpty)
              Text('Sumber bermasalah: ${res!.errors.map((e) => e.source).join(', ')}', style: const TextStyle(color: C.accent, fontSize: 12)),
            Expanded(
              child: res == null
                  ? const SizedBox()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 10, childAspectRatio: 0.52),
                      itemCount: res!.items.length,
                      itemBuilder: (_, i) => AnimePosterCard(
                        anime: res!.items[i],
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(anime: res!.items[i]))),
                      ),
                    ),
            ),
          ]),
        ),
      );
}
