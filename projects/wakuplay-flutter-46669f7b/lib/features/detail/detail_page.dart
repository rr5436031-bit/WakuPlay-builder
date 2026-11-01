import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../services/anime/sanka_api.dart';
import '../player/player_page.dart';

class DetailData {
  final Map<String, dynamic> info; final List<Episode> eps; final Set<String> watched; final dynamic raw;
  DetailData(this.info, this.eps, this.watched, this.raw);
}

final _detailProvider = FutureProvider.autoDispose.family<DetailData, Anime>((ref, a) async {
  final lib = ref.read(libraryRepoProvider);
  if (a.source == 'legacy') {
    final api = ref.read(legacyApiProvider);
    final r = await Future.wait([api.detail(a.originalId), api.episodes(a.originalId), lib.watchedIds(a.storeId)]);
    return DetailData(r[0] as Map<String, dynamic>, r[1] as List<Episode>, r[2] as Set<String>, null);
  }
  final d = await SankaApi.detail(a.source, a.originalId);
  return DetailData(d.info, d.eps, await lib.watchedIds(a.storeId), d.raw);
});

/// Tampilan JSON mentah (untuk mendiagnosa sumber yang bentuk datanya belum cocok). Bisa disalin.
class RawJsonPage extends StatelessWidget {
  final String title; final dynamic data;
  const RawJsonPage(this.title, this.data, {super.key});
  @override
  Widget build(BuildContext context) {
    final txt = data is String ? data as String : const JsonEncoder.withIndent(' ').convert(data);
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: Text(title, style: const TextStyle(fontSize: 15)), actions: [
        IconButton(icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: txt)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disalin'))); }),
      ]),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: SelectableText(txt.length > 60000 ? '${txt.substring(0, 60000)}\n… (dipotong)' : txt, style: const TextStyle(fontFamily: 'monospace', fontSize: 11))),
    );
  }
}

class DetailPage extends ConsumerStatefulWidget {
  final Anime anime;
  const DetailPage({super.key, required this.anime});
  @override
  ConsumerState<DetailPage> createState() => _S();
}

class _S extends ConsumerState<DetailPage> {
  bool? fav;

  @override
  void initState() {
    super.initState();
    ref.read(libraryRepoProvider).isFavorite(widget.anime.storeId).then((v) { if (mounted) setState(() => fav = v); });
  }

  Future<void> _toggleFav() async {
    final repo = ref.read(libraryRepoProvider);
    final now = !(fav ?? false);
    setState(() => fav = now);
    try { now ? await repo.addFavorite(widget.anime) : await repo.removeFavorite(widget.anime.storeId); }
    catch (_) { if (mounted) setState(() => fav = !now); }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anime;
    final d = ref.watch(_detailProvider(a));
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis), actions: [
        IconButton(onPressed: _toggleFav, icon: Icon(fav == true ? Icons.favorite : Icons.favorite_border, color: fav == true ? C.danger : null)),
      ]),
      body: d.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$e', textAlign: TextAlign.center, style: const TextStyle(color: C.textDim)),
          TextButton(onPressed: () => ref.invalidate(_detailProvider(a)), child: const Text('Coba lagi')),
        ]))),
        data: (v) {
          final info = v.info; final eps = v.eps; final watched = v.watched;
          final poster = (info['poster'] ?? a.poster)?.toString();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(C.radiusCard), child: SizedBox(width: 110, height: 165,
                  child: poster == null ? Container(color: C.surface) : CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover, memCacheWidth: 330))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${info['title'] ?? a.title}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('★ ${info['rating'] ?? '-'}  •  ${info['status'] ?? '-'}  •  ${a.source == 'legacy' ? 'WakuPlay' : a.source}', style: const TextStyle(color: C.accent)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final g in (info['genres'] as List)) Chip(label: Text('$g', style: const TextStyle(fontSize: 11)), backgroundColor: C.surface, side: BorderSide.none, visualDensity: VisualDensity.compact)]),
              ])),
            ]),
            const SizedBox(height: 14),
            Text('${info['synopsis'] ?? 'Tidak ada sinopsis'}', style: const TextStyle(color: C.textDim, height: 1.4)),
            const SizedBox(height: 18),
            Text('Episode (${eps.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (eps.isEmpty && v.raw != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Daftar episode tidak terbaca dari respons sumber ini.', style: TextStyle(color: C.accent, fontSize: 12)),
              TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RawJsonPage('Respons detail ${a.source}', v.raw))), child: const Text('Lihat respons mentah')),
            ])),
            const SizedBox(height: 8),
            for (final e in eps)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerPage(anime: a, episode: e, episodes: eps))),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard),
                      border: Border.all(color: watched.contains(a.epKey(e.id)) ? C.danger : Colors.transparent, width: 1.5)),
                  child: Row(children: [
                    Expanded(child: Text(e.title != null && a.source != 'legacy' ? e.title! : 'Episode ${e.number}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(20)), child: const Text('Buka', style: TextStyle(fontWeight: FontWeight.w700))),
                  ]),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
