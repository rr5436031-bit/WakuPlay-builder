import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/prefs.dart';
import '../../core/theme/colors.dart';
import '../notify/notif_router.dart' show navKey;
import '../supabase/supabase_service.dart';

class LevelInfo {
  final int level; final num xp, into, need; final double pct;
  const LevelInfo(this.level, this.xp, this.into, this.need, this.pct);
}

/// Level dihitung dari konfigurasi server (level_config_get) persis seperti levelcurve.js. XP asli selalu dari server.
class XpService {
  static num? myXp;
  static num _base = 0, _growth = 0;
  static bool _cfg = false;

  static Future<void> init() async {
    try {
      final c = await rpc('level_config_get');
      final m = c is List ? (c.isEmpty ? null : c.first) : c;
      if (m is Map) { _base = num.parse('${m['base_cost']}'); _growth = num.parse('${m['growth']}'); _cfg = _base > 0; }
    } catch (_) {}
    try {
      final p = await rpc('get_public_profile', {'p_uid': db.auth.currentUser!.id});
      if (p is List && p.isNotEmpty) myXp = num.tryParse('${(p.first as Map)['xp']}');
    } catch (_) {}
  }

  static num _total(int l) { final n = max(0, l - 1); return _base * n + _growth * n * n; }

  static LevelInfo levelInfo(num xpIn) {
    final x = max<num>(0, xpIn);
    if (!_cfg) return LevelInfo(1, x, 0, 1, 0);
    final n = _growth > 0 ? ((-_base + sqrt(_base * _base + 4 * _growth * x)) / (2 * _growth) + 1e-9).floor() : (x / _base + 1e-9).floor();
    final level = (n + 1).clamp(1, 999999).toInt();
    final start = _total(level), next = _total(level + 1);
    return LevelInfo(level, x, x - start, next - start, ((x - start) / (next - start)).clamp(0, 1).toDouble());
  }

  /// Dipanggil dengan total XP terbaru dari xp_beat. Tampilkan popup +XP / Level Up bila pengaturan aktif.
  static void onTotal(num total) {
    final old = myXp;
    myXp = total;
    if (old == null || total <= old || !Prefs.getB('expPopup', true)) return;
    final lo = levelInfo(old).level, ln = levelInfo(total).level;
    _toast('+${(total - old).round()} XP', null);
    if (ln > lo) { Future.delayed(const Duration(milliseconds: 700), () => _toast('LEVEL UP!', 'Level $ln')); }
  }

  static void _toast(String t, String? sub) {
    final ov = navKey.currentState?.overlay;
    if (ov == null) return;
    late OverlayEntry e;
    e = OverlayEntry(builder: (_) => Positioned(top: MediaQuery.of(ov.context).padding.top + 56, left: 0, right: 0,
        child: IgnorePointer(child: Center(child: _Chip(t, sub)))));
    ov.insert(e);
    Future.delayed(const Duration(milliseconds: 2400), () { try { e.remove(); } catch (_) {} });
  }
}

class _Chip extends StatelessWidget {
  final String t; final String? sub;
  const _Chip(this.t, this.sub);
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 2400),
        builder: (_, v, __) {
          final a = v < .12 ? v / .12 : v > .8 ? (1 - v) / .2 : 1.0;
          return Opacity(opacity: a.clamp(0.0, 1.0).toDouble(), child: Transform.translate(offset: Offset(0, (1 - a) * -14), child: Transform.scale(scale: .92 + .08 * a, child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: sub == null ? 9 : 12),
              decoration: BoxDecoration(color: sub == null ? const Color(0xE6101218) : const Color(0xE62B1B4F), borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: sub == null ? C.primary : C.accent, width: 1.5), boxShadow: [BoxShadow(color: (sub == null ? C.primary : C.accent).withValues(alpha: .35), blurRadius: 18)]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(t, style: TextStyle(fontSize: sub == null ? 15 : 18, fontWeight: FontWeight.w900, color: sub == null ? C.text : C.accent)),
                if (sub != null) Text(sub!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
            ),
          ))));
        },
      );
}
