import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// 50 border SVG bawaan (hasil render borderArt.js asli, tanpa animasi CSS) + border bergambar (.gif) dari server.
/// Geometri sama dengan BorderFrame.jsx: SVG 180% dari avatar (offset -40%); gambar 1.2x (IMG_SCALE).
class BorderArtStore {
  static Map<String, dynamic>? _m;
  static Future<Map<String, dynamic>> load() async => _m ??= jsonDecode(await rootBundle.loadString('assets/border_art.json')) as Map<String, dynamic>;
}

class BorderFrame extends StatelessWidget {
  final String? id; final String? imageUrl; final double size; final Widget child;
  const BorderFrame({super.key, this.id, this.imageUrl, required this.size, required this.child});

  static String _svg(String inner) => '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-15 -15 180 180">$inner</svg>';

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      final pad = size * 0.1;
      return SizedBox(width: size, height: size, child: Stack(clipBehavior: Clip.none, children: [
        child,
        Positioned(left: -pad, top: -pad, width: size * 1.2, height: size * 1.2,
            child: IgnorePointer(child: Image.network(imageUrl!, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox()))),
      ]));
    }
    if (id == null || id!.isEmpty) return child;
    return FutureBuilder<Map<String, dynamic>>(
      future: BorderArtStore.load(),
      builder: (_, s) {
        final art = s.data?[id] as Map?;
        if (art == null) return child;
        final off = -size * 0.4, big = size * 1.8;
        Widget layer(String key) => art[key] == null || '${art[key]}'.isEmpty ? const SizedBox()
            : Positioned(left: off, top: off, width: big, height: big, child: IgnorePointer(child: SvgPicture.string(_svg('${art[key]}'))));
        return SizedBox(width: size, height: size, child: RepaintBoundary(child: Stack(clipBehavior: Clip.none, children: [layer('b'), child, layer('f')])));
      },
    );
  }
}

/// Lencana peringkat (Top LB bulanan / Top Giver bulanan / Top Level) — gradasi sama dengan index.css.
class RankBadge extends StatelessWidget {
  final int rank; final String label; final List<Color> colors; final Color num;
  const RankBadge({super.key, required this.rank, required this.label, required this.colors, required this.num});

  factory RankBadge.lb(int r) => RankBadge(rank: r, label: 'LB BULANAN', num: const Color(0xFFEADCFF), colors: const [Color(0xD69664FF), Color(0xCC5420A0), Color(0xD60A0516)]);
  factory RankBadge.giver(int r) => RankBadge(rank: r, label: 'GIVER BULANAN', num: const Color(0xFFFFF0C4), colors: const [Color(0xDBFFCD50), Color(0xD1BE700E), Color(0xDB1E0F03)]);
  factory RankBadge.level(int r) => RankBadge(rank: r, label: 'LEVEL TERTINGGI', num: const Color(0xFFE2FFFF), colors: const [Color(0xDB5FE0E6), Color(0xD1146E96), Color(0xE0040E1E)]);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 13, 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, stops: const [0, .38, 1], colors: colors),
            border: Border.all(color: Colors.white24)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text.rich(TextSpan(children: [const TextSpan(text: 'TOP '), TextSpan(text: '$rank', style: TextStyle(fontSize: 21, color: num))]), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: .6, height: 1.1)),
          Text(label, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: Color(0xD1E8DAFF), height: 1.1)),
        ]),
      );
}
