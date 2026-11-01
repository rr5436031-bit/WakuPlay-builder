import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';

/// Ilustrasi Kebun Waku (pohon, lampu, pet, orang): SVG hasil render FarmArt.jsx asli.
class FarmArtStore {
  static Map<String, String>? _m;
  static Future<Map<String, String>> load() async =>
      _m ??= Map<String, String>.from(jsonDecode(await rootBundle.loadString('assets/farm_art.json')) as Map);
}

/// [animate] = goyangan lembut (pohon/orang bergoyang, pet naik-turun, lampu berkedip). Satu controller per ilustrasi,
/// berhenti sendiri saat halaman tertutup (TickerMode) dan memakai RepaintBoundary.
class FarmArt extends StatefulWidget {
  final String id; final double height; final bool animate;
  const FarmArt(this.id, {super.key, this.height = 90, this.animate = false});
  @override
  State<FarmArt> createState() => _F();
}

class _F extends State<FarmArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: 2600 + (widget.id.hashCode.abs() % 1400)));
  late final double _phase = (widget.id.hashCode.abs() % 628) / 100;

  @override
  void initState() { super.initState(); if (widget.animate) _c.repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, String>>(
        future: FarmArtStore.load(),
        builder: (_, s) {
          final svg = s.data?[widget.id];
          if (svg == null) return SizedBox(height: widget.height);
          final pic = SvgPicture.string(svg, height: widget.height);
          if (!widget.animate) return SizedBox(height: widget.height, child: pic);
          final kind = widget.id.split('_').first;
          return SizedBox(height: widget.height, child: RepaintBoundary(child: AnimatedBuilder(
            animation: _c,
            child: pic,
            builder: (_, child) {
              final t = sin(_c.value * 2 * pi + _phase);
              switch (kind) {
                case 'tree': return Transform.rotate(angle: t * 0.035, alignment: Alignment.bottomCenter, child: child);
                case 'man': return Transform.rotate(angle: t * 0.02, alignment: Alignment.bottomCenter, child: Transform.translate(offset: Offset(0, -1.5 * (t + 1) / 2), child: child));
                case 'pet': return Transform.translate(offset: Offset(0, -4 * (t + 1) / 2), child: child);
                case 'lamp': return Opacity(opacity: 0.82 + 0.18 * (t + 1) / 2, child: child);
                default: return child!;
              }
            },
          )));
        },
      );
}
