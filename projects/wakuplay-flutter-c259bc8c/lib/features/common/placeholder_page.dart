import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Halaman yang BELUM dimigrasikan. Sengaja jujur: bukan fitur selesai.
class PlaceholderPage extends StatelessWidget {
  final String title; final String source;
  const PlaceholderPage(this.title, this.source, {super.key});
  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Belum dimigrasikan\nsumber: $source', textAlign: TextAlign.center, style: const TextStyle(color: C.textDim)),
          ]),
        ),
      );
}
