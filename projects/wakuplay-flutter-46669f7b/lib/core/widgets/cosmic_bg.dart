import 'dart:math';
import 'package:flutter/material.dart';

/// Latar kosmik (bintang berkedip) setara CosmicBg.jsx: satu CustomPainter + satu ticker,
/// berhenti otomatis saat app di background (TickerMode / lifecycle).
class CosmicBg extends StatefulWidget {
  final Widget child;
  const CosmicBg({super.key, required this.child});
  @override
  State<CosmicBg> createState() => _S();
}

class _S extends State<CosmicBg> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  static final _stars = List.generate(70, (i) { final r = Random(i * 7 + 3); return (r.nextDouble(), r.nextDouble(), r.nextDouble() * 1.6 + .4, r.nextDouble()); });

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) { s == AppLifecycleState.resumed ? _c.repeat() : _c.stop(); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B0A1F), Color(0xFF1A1040), Color(0xFF0E1630)])),
        child: Stack(children: [
          Positioned.fill(child: RepaintBoundary(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _P(_c.value))))),
          widget.child,
        ]),
      );
}

class _P extends CustomPainter {
  final double t;
  _P(this.t);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint();
    for (final (x, y, r, ph) in _S._stars) {
      final a = .25 + .75 * (0.5 + 0.5 * sin((t + ph) * 2 * pi));
      p.color = Colors.white.withValues(alpha: a);
      c.drawCircle(Offset(x * s.width, y * s.height), r, p);
    }
  }
  @override
  bool shouldRepaint(_P o) => o.t != t;
}
