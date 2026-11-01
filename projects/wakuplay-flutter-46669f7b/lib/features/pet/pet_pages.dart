import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';
import '../games/gacha_pages.dart';

const _rar = {'mythic': ('Mythic', Color(0xFFFF3D7F)), 'legendary': ('Legend', Color(0xFFF5A30A)), 'epic': ('Epic', Color(0xFFA855F7)), 'rare': ('Rare', Color(0xFF3B82F6)), 'common': ('Common', Color(0xFF9CA3AF))};

String _left(int ms) {
  final s = (ms / 1000).ceil().clamp(0, 99999999);
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, x = s % 60;
  return h > 0 ? '${h}j ${m.toString().padLeft(2, '0')}m' : '${m.toString().padLeft(2, '0')}:${x.toString().padLeft(2, '0')}';
}

/// Langit habitat (setara PetSkyBg) + pet melayang pelan. Satu AnimationController untuk semua pet.
class HabitatView extends StatefulWidget {
  final List<Map> pets; final void Function(Map)? onTap; final int skewMs;
  const HabitatView({super.key, required this.pets, this.onTap, this.skewMs = 0});
  @override
  State<HabitatView> createState() => _H();
}

class _H extends State<HabitatView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch + widget.skewMs;
    return Container(
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(C.radiusCard), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF3A7BD5), Color(0xFF8FD3F4), Color(0xFFB6F0C0)])),
      child: widget.pets.isEmpty
          ? const SizedBox(height: 180, child: Center(child: Text('Belum ada pet di habitat', style: TextStyle(color: Colors.white70))))
          : AnimatedBuilder(animation: _c, builder: (_, __) => Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 14, children: [
              for (final (i, p) in widget.pets.indexed) _tile(p, i, now),
            ])),
    );
  }

  Widget _tile(Map p, int i, int now) {
    final ready = p['ready_at'] != null && (DateTime.tryParse('${p['ready_at']}')?.millisecondsSinceEpoch ?? 1 << 60) <= now;
    final dy = sin((_c.value + i * .13) * 2 * pi) * 4;
    final col = _rar['${p['rarity']}']?.$2 ?? Colors.white;
    return GestureDetector(
      onTap: widget.onTap == null ? null : () => widget.onTap!(p),
      child: Transform.translate(offset: Offset(0, dy), child: SizedBox(width: 84, child: Column(children: [
        Container(
          width: 76, height: 76, padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white24, border: Border.all(color: ready ? C.accent : col.withValues(alpha: .7), width: ready ? 3 : 1.5),
              boxShadow: ready ? [BoxShadow(color: C.accent.withValues(alpha: .7), blurRadius: 14)] : null),
          child: ClipOval(child: p['image_url'] != null ? Image.network('${p['image_url']}', fit: BoxFit.contain, cacheWidth: 200, errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.white)) : const Icon(Icons.pets, color: Colors.white)),
        ),
        const SizedBox(height: 3),
        Text(ready ? 'Klaim!' : (p['ready_at'] == null ? '' : _left((DateTime.tryParse('${p['ready_at']}')?.millisecondsSinceEpoch ?? now) - now)),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: ready ? C.accent : Colors.white, shadows: const [Shadow(blurRadius: 4)])),
      ]))),
    );
  }
}

/// Habitat Pet: pasang/simpan pet, klaim WakuGold (per pet atau semua), jual dari penyimpanan. Waktu & hadiah ditentukan server.
class PetPage extends StatefulWidget {
  const PetPage({super.key});
  @override
  State<PetPage> createState() => _P();
}

class _P extends State<PetPage> {
  Map? hab; String? err; bool busy = false; int skew = 0; Timer? _t;

  @override
  void initState() { super.initState(); _load(); _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try {
      final r = await rpc('pet_habitat_me') as Map;
      final sn = DateTime.tryParse('${r['now']}');
      if (mounted) setState(() { hab = r; err = null; if (sn != null) skew = sn.millisecondsSinceEpoch - DateTime.now().millisecondsSinceEpoch; });
    } catch (e) { if (mounted) setState(() => err = '$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _run(Future<dynamic> Function() f, {String? ok}) async {
    if (busy) return;
    setState(() => busy = true);
    try { final r = await f(); if (ok != null && mounted) toast(context, ok); if (r is Map && r['earned'] != null && mounted) toast(context, '+${fmtNum(num.tryParse('${r['earned']}') ?? 0)} WakuGold'); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    await _load();
    if (mounted) setState(() => busy = false);
  }

  bool _ready(Map p) => (DateTime.tryParse('${p['ready_at']}')?.millisecondsSinceEpoch ?? 1 << 60) <= DateTime.now().millisecondsSinceEpoch + skew;

  Future<bool> _confirm(String t) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(content: Text(t),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya'))])) == true;

  @override
  Widget build(BuildContext context) {
    final h = hab;
    final placed = [for (final x in (h?['placed'] as List? ?? const [])) if (x is Map) x];
    final stored = [for (final x in (h?['stored'] as List? ?? const [])) if (x is Map) x];
    final max = (h?['max'] as num?)?.toInt() ?? 15;
    final ready = placed.where(_ready).length;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Pet'), actions: [
        TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummonPage(title: 'Gacha Pet', infoRpc: 'pet_info', summonRpc: 'pet_summon'))).then((_) => _load()), child: const Text('Gacha')),
      ]),
      body: err != null ? Center(child: Text(err!)) : h == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: Text('Habitat ${placed.length}/$max  •  siap klaim $ready', style: const TextStyle(fontWeight: FontWeight.w700))),
          pillButton('Klaim Semua', busy || ready == 0 ? null : () => _run(() => rpc('pet_claim_all')), color: C.accent),
        ]),
        const SizedBox(height: 10),
        HabitatView(pets: placed, skewMs: skew, onTap: (p) {
          if (_ready(p)) { _run(() => rpc('pet_claim', {'p_unit': p['unit']})); }
          else { toast(context, '${p['name']}: siap diklaim ${_left((DateTime.tryParse('${p['ready_at']}')?.millisecondsSinceEpoch ?? 0) - (DateTime.now().millisecondsSinceEpoch + skew))} lagi'); }
        }),
        const SizedBox(height: 8),
        const Text('Ketuk pet yang bercahaya untuk klaim. Tekan lama untuk menyimpan.', style: TextStyle(color: C.textDim, fontSize: 12)),
        if (placed.isNotEmpty) Wrap(spacing: 6, children: [for (final p in placed)
          ActionChip(label: Text('Simpan ${p['name']}', style: const TextStyle(fontSize: 11)), onPressed: busy ? null : () { if (_ready(p)) { toast(context, 'Klaim WakuGold-nya dulu sebelum menyimpan pet ini'); } else { _run(() => rpc('pet_store', {'p_unit': p['unit']})); } })]),
        const Padding(padding: EdgeInsets.only(top: 18, bottom: 6), child: Text('Penyimpanan', style: TextStyle(fontWeight: FontWeight.w800))),
        if (stored.isEmpty) const Text('Kosong. Dapatkan pet lewat Gacha.', style: TextStyle(color: C.textDim)),
        for (final s in stored) card(child: Row(children: [
          SizedBox(width: 44, height: 44, child: s['image_url'] != null ? Image.network('${s['image_url']}', cacheWidth: 120, errorBuilder: (_, __, ___) => const Icon(Icons.pets)) : const Icon(Icons.pets)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s['name']}  ×${s['count']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(_rar['${s['rarity']}']?.$1 ?? '${s['rarity']}', style: TextStyle(color: _rar['${s['rarity']}']?.$2 ?? C.textDim, fontSize: 12)),
          ])),
          pillButton('Pasang', busy || placed.length >= max ? null : () => _run(() => rpc('pet_place', {'p_pet': s['pet_id']}))),
          const SizedBox(width: 6),
          pillButton('Jual', busy ? null : () async {
            final price = num.tryParse('${s['min']}') ?? 0;
            if (price < 1) return;
            if (await _confirm('Jual 1 ${s['name']} seharga ${fmtNum(price)} WakuGold?\nPet yang dijual hilang permanen.')) _run(() => rpc('pet_sell', {'p_pet': s['pet_id'], 'p_expected': price.toInt()}), ok: 'Terjual +${fmtNum(price)} WakuGold');
          }, color: C.danger),
        ])),
      ]),
    );
  }
}

/// Lihat habitat pemain lain (pet_view, hanya lihat).
class PetVisitPage extends StatefulWidget {
  final String uid, name;
  const PetVisitPage({super.key, required this.uid, required this.name});
  @override
  State<PetVisitPage> createState() => _V();
}

class _V extends State<PetVisitPage> {
  List<Map>? pets; String? err;
  @override
  void initState() {
    super.initState();
    rpc('pet_view', {'p_uid': widget.uid}).then((r) { if (mounted) setState(() => pets = [for (final x in ((r as Map)['pets'] as List? ?? const [])) if (x is Map) x]); })
        .catchError((e) { if (mounted) setState(() => err = '$e'.replaceFirst('Exception: ', '')); });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: Text('Peliharaan ${widget.name}')),
        body: err != null ? Center(child: Text(err!)) : pets == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Mode lihat saja', style: TextStyle(color: C.textDim, fontSize: 12)), const SizedBox(height: 8),
          HabitatView(pets: [for (final p in pets!) {...p, 'ready_at': null}]),
          Padding(padding: const EdgeInsets.only(top: 8), child: Text('${pets!.length} pet terpasang', style: const TextStyle(color: C.textDim))),
        ]),
      );
}
