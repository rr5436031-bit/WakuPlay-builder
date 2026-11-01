import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Widget card({required Widget child, EdgeInsets? margin, Color? color}) => Container(
      margin: margin ?? const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color ?? C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
      child: child);

Widget pillButton(String t, VoidCallback? f, {Color color = C.primary}) => GestureDetector(
      onTap: f,
      child: Opacity(opacity: f == null ? .4 : 1, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(22)),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)))));

const rarityColor = {'common': Color(0xFF9CA3AF), 'rare': Color(0xFF4A8CFF), 'epic': Color(0xFFB26BFF), 'legendary': Color(0xFFF5B50A), 'mythic': Color(0xFFFF4D6D)};

/// Tampilkan JSON hasil RPC apa adanya (untuk respons yang bentuknya belum dipetakan).
class JsonRows extends StatelessWidget {
  final Map data;
  const JsonRows(this.data, {super.key});
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final e in data.entries)
          if (e.value is! Map && e.value is! List)
            Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text('${e.key}', style: const TextStyle(color: C.textDim))), Flexible(child: Text('${e.value}', textAlign: TextAlign.end)),
            ])),
      ]);
}
