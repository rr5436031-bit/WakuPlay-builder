import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../models/anime.dart';
import '../theme/colors.dart';

/// Kartu poster 2:3 dengan badge sumber, rating (kanan atas), judul di bawah. Gambar di-cache & di-downscale.
class AnimePosterCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onTap;
  const AnimePosterCard({super.key, required this.anime, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 2 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(C.radiusCard),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: C.surface),
              if (anime.poster != null)
                CachedNetworkImage(
                  imageUrl: anime.poster!,
                  fit: BoxFit.cover,
                  memCacheWidth: 360,
                  fadeInDuration: const Duration(milliseconds: 120),
                  errorWidget: (_, __, ___) => const SizedBox(),
                ),
              Positioned(
                left: 6, top: 6,
                child: _Chip(text: anime.source == 'legacy' ? 'WAKU' : anime.source, color: C.primary),
              ),
              if (anime.rating != null)
                Positioned(
                  right: 6, top: 6,
                  child: _Chip(text: '★ ${anime.rating!.toStringAsFixed(2)}', color: Colors.black87, fg: C.accent),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(anime.title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text; final Color color; final Color fg;
  const _Chip({required this.text, required this.color, this.fg = Colors.white});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
