import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

/// Halaman summon generik untuk Gacha Wallpaper (gacha_info/gacha_summon) dan Pet (pet_info/pet_summon).
/// Peluang & harga sepenuhnya dari server; klien hanya menampilkan.
class SummonPage extends StatefulWidget {
  final String title, infoRpc, summonRpc;
  const SummonPage({super.key, required this.title, required this.infoRpc, required this.summonRpc});
  @override
  State<SummonPage> createState() => _S();
}

class _S extends State<SummonPage> with SingleTickerProviderStateMixin {
  Map? info; String? err, last; bool busy = false; List<Map> got = [];
  late final AnimationController _orb = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() { _orb.dispose(); super.dispose(); }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final r = await rpc(widget.infoRpc); if (mounted) setState(() { info = r as Map; err = null; }); }
    catch (e) { if (mounted) setState(() => err = '$e'); }
  }

  Future<void> _summon(int n) async {
    setState(() { busy = true; got = []; last = null; });
    try {
      final r = await rpc(widget.summonRpc, {'p_count': n});
      await Future.delayed(const Duration(milliseconds: 900)); // jeda animasi orb sebelum hasil dibuka
      final items = <Map>[];
      void collect(dynamic v) { if (v is List) { v.forEach(collect); } else if (v is Map) { if (v['name'] != null && v['rarity'] != null) { items.add(v); } else { v.values.forEach(collect); } } }
      collect(r);
      if (mounted) setState(() => got = items);
      final names = <String>[];
      void walk(dynamic v) {
        if (v is List) { v.forEach(walk); return; }
        if (v is Map) { if (v['name'] != null && v['rarity'] != null) { names.add('${v['name']} (${v['rarity']})'); return; } v.values.forEach(walk); }
      }
      walk(r);
      if (mounted) setState(() => last = names.isEmpty ? const JsonEncoder.withIndent(' ').convert(r) : names.join('\n'));
      await _load();
    } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final i = info;
    final list = [for (final x in (i?['list'] as List? ?? const [])) if (x is Map) x];
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: Text(widget.title)),
      body: err != null ? Center(child: Text(err!)) : i == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: pillButton('Summon x1 • ${fmtNum(num.tryParse('${i['cost1']}') ?? 0)}', busy ? null : () => _summon(1))),
          const SizedBox(width: 10),
          Expanded(child: pillButton('x10 • ${fmtNum(num.tryParse('${i['cost10']}') ?? 0)}', busy ? null : () => _summon(10), color: C.pillBlue)),
        ]),
        if (busy) Padding(padding: const EdgeInsets.only(top: 18), child: Center(child: AnimatedBuilder(animation: _orb, builder: (_, __) => Transform.scale(scale: 0.85 + 0.3 * _orb.value, child: Container(width: 84, height: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Colors.white, Color(0xFFB26BFF), Color(0x00B26BFF)]), boxShadow: [BoxShadow(color: const Color(0xFFB26BFF).withValues(alpha: .6), blurRadius: 30 * _orb.value + 10)])))))),
        if (!busy && got.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 14), child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
          for (final (i, it) in got.indexed) _RevealCard(it, i),
        ])),
        if (!busy && got.isEmpty && last != null) card(margin: const EdgeInsets.only(top: 12), child: Text(last!)),
        const SizedBox(height: 14),
        Text('Daftar (${list.where((x) => x['owned'] == true).length}/${list.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        for (final x in list)
          card(margin: const EdgeInsets.only(bottom: 6), child: Row(children: [
            Container(width: 6, height: 28, color: rarityColor['${x['rarity']}'] ?? C.textDim), const SizedBox(width: 10),
            Expanded(child: Text('${x['name']}${x['owned'] == true ? '  ✓' : ''}')),
            Text('${num.tryParse('${x['pct']}')?.toStringAsFixed(3) ?? ''}%', style: const TextStyle(color: C.textDim)),
          ])),
      ]),
    );
  }
}

class BorderShopPage extends StatefulWidget {
  const BorderShopPage({super.key});
  @override
  State<BorderShopPage> createState() => _B();
}

class _B extends State<BorderShopPage> {
  Map? d; String? err; bool busy = false;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await rpc('border_shop'); if (mounted) setState(() { d = r as Map; err = null; }); }
    catch (e) { if (mounted) setState(() => err = '$e'); }
  }
  Future<void> _act(String fn, String id) async {
    setState(() => busy = true);
    try { await rpc(fn, {'p_id': id}); await _load(); } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final list = [for (final x in (d?['list'] as List? ?? const [])) if (x is Map) x];
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Avatar Border')),
      body: err != null ? Center(child: Text(err!)) : d == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        card(child: Text('WakuGold: ${fmtNum(num.tryParse('${d!['gold']}') ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w800))),
        for (final b in list)
          card(child: Row(children: [
            Container(width: 6, height: 36, color: rarityColor['${b['rarity']}'] ?? C.textDim), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${b['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(b['owned'] == true ? 'Dimiliki' : '${fmtNum(num.tryParse('${b['price']}') ?? 0)} Gold', style: const TextStyle(color: C.textDim, fontSize: 12)),
            ])),
            if (b['owned'] != true) pillButton('Beli', busy ? null : () => _act('border_buy', '${b['id']}'))
            else if (d!['equipped'] == b['id'] || b['equipped'] == true) const Text('Dipakai', style: TextStyle(color: C.accent))
            else pillButton('Pakai', busy ? null : () => _act('border_equip', '${b['id']}')),
          ])),
      ]),
    );
  }
}

/// Kartu hasil summon: muncul bertahap (skala + fade), warna bingkai mengikuti rarity, kartu langka bersinar.
class _RevealCard extends StatelessWidget {
  final Map it; final int index;
  const _RevealCard(this.it, this.index);
  @override
  Widget build(BuildContext context) {
    final col = rarityColor['${it['rarity']}'] ?? C.textDim;
    final rare = const {'epic', 'legendary', 'mythic'}.contains('${it['rarity']}');
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 380 + min(index, 9) * 90), curve: Curves.easeOutBack,
      builder: (_, v, child) => Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: Transform.scale(scale: .6 + .4 * v, child: child)),
      child: Container(
        width: 96, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: col, width: 2), boxShadow: rare ? [BoxShadow(color: col.withValues(alpha: .55), blurRadius: 16)] : null),
        child: Column(children: [
          SizedBox(height: 64, child: (it['image_url'] ?? it['url']) != null ? Image.network('${it['image_url'] ?? it['url']}', fit: BoxFit.contain, cacheWidth: 200, errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome, color: col)) : Icon(Icons.auto_awesome, color: col)),
          const SizedBox(height: 4),
          Text('${it['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text('${it['rarity']}', style: TextStyle(fontSize: 10, color: col, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}
