import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// Search bar pil sesuai referensi (surface, radius penuh, ikon kaca pembesar).
class AppSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  const AppSearchBar({super.key, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(30)),
          child: const Row(children: [
            Icon(Icons.search, color: C.textDim, size: 24),
            SizedBox(width: 12),
            Text('Cari Anime Di Sini', style: TextStyle(color: C.textDim, fontSize: 15)),
          ]),
        ),
      );
}
