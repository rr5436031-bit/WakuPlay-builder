import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../../core/widgets/farm_art.dart';
import '../common/ui.dart';

/// Kebun Waku: seluruh aturan (panen, upgrade, harga) dihitung server lewat farm_* RPC. Adegan SVG belum dibuat ulang.
class FarmPage extends StatefulWidget {
  const FarmPage({super.key});
  @override
  State<FarmPage> createState() => _S();
}

class _S extends State<FarmPage> {
  Map? st; String? err; bool busy = false; String cat = 'fence'; Timer? _t;

  @override
  void initState() { super.initState(); _load(); _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); }); }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _load() async {
    try { final r = await rpc('farm_state'); if (mounted) setState(() { st = r as Map; err = null; }); }
    catch (e) { if (mounted) setState(() => err = '$e'); }
  }

  Future<void> _do(Future<dynamic> Function() f, [String? ok]) async {
    setState(() => busy = true);
    try { await f(); if (ok != null && mounted) toast(context, ok); await _load(); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String _cd() {
    final n = st?['next_at']; if (n == null) return '';
    final ms = DateTime.parse('$n').difference(DateTime.now()).inSeconds.clamp(0, 999999);
    return '${(ms ~/ 3600).toString().padLeft(2, '0')}:${((ms % 3600) ~/ 60).toString().padLeft(2, '0')}:${(ms % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Kebun Waku')),
      body: err != null ? Center(child: Text(err!)) : s == null ? const Center(child: CircularProgressIndicator()) : _body(s),
    );
  }

  Widget _body(Map s) {
    final level = (s['level'] as num?)?.toInt() ?? 0;
    final stock = (s['stock'] as num?)?.toInt() ?? 0;
    final cap = (s['cap'] as num?)?.toInt() ?? 1;
    final nx = s['next'] is Map ? s['next'] as Map : null;
    final items = [for (final i in (s['items'] as List? ?? const [])) if (i is Map && i['cat'] == cat) i];
    final owned = {for (final o in (s['owned'] as List? ?? const [])) '$o'};
    final eq = (s['equipped'] as Map?) ?? const {};
    final worth = stock * (num.tryParse('${s['carrot_gold']}') ?? 0);
    final scene = [for (final c in const ['tree', 'lamp', 'person', 'pet']) if ('${eq[c] ?? ''}'.isNotEmpty) '${eq[c]}'];
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (scene.isNotEmpty)
        Container(
          height: 130, margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(C.radiusCard), gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16345C), Color(0xFF2B6B3A)])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [for (final id in scene) FarmArt(id, height: 110, animate: true)]),
        ),
      card(child: Column(children: [
        Text(level == 0 ? 'Belum ditanami' : 'Level $level', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        LinearProgressIndicator(value: level == 0 ? 0 : (stock / cap).clamp(0, 1).toDouble(), minHeight: 10, color: const Color(0xFFFF8A1F), backgroundColor: C.border),
        const SizedBox(height: 8),
        Text(level == 0 ? '–' : '$stock / $cap wortel   •   ${_cd()}'),
        if (level > 0) Text('+${s['yield']} wortel / ${s['interval_min']} mnt • 1 wortel = ${s['carrot_gold']} Gold', style: const TextStyle(color: C.textDim, fontSize: 12)),
      ])),
      Row(children: [
        Expanded(child: pillButton(level == 0 || stock == 0 ? 'Panen' : 'Panen (${fmtNum(worth)} Gold)', busy || level == 0 || stock == 0 ? null : () => _do(() => rpc('farm_harvest'), 'Panen berhasil'), color: const Color(0xFFFF8A1F))),
        const SizedBox(width: 10),
        Expanded(child: pillButton(level == 0 ? 'Tanam' : 'Upgrade', busy || nx == null ? null : () => _do(() => rpc('farm_upgrade'), 'Berhasil'))),
      ]),
      if (nx != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Berikutnya: ${nx['yield']} wortel / ${nx['interval_min']} mnt, kapasitas ${nx['cap']}${nx['cost'] != null ? ' • biaya ${nx['cost']}' : ''}', style: const TextStyle(color: C.textDim, fontSize: 12))),
      const SizedBox(height: 16),
      Wrap(spacing: 8, children: [for (final c in const [['fence', 'Pagar'], ['lamp', 'Lampu'], ['tree', 'Pohon'], ['pet', 'Pet'], ['person', 'Orang']])
        ChoiceChip(label: Text(c[1]), selected: cat == c[0], onSelected: (_) => setState(() => cat = c[0]))]),
      const SizedBox(height: 10),
      for (final it in items)
        card(child: Row(children: [
          if (const {'tree', 'lamp', 'person', 'pet'}.contains(cat)) Padding(padding: const EdgeInsets.only(right: 10), child: FarmArt('${it['id']}', height: 52))
          else Container(width: 6, height: 36, color: rarityColor['${it['rarity']}'] ?? C.textDim),
          const SizedBox(width: 4),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${it['name'] ?? it['id']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(owned.contains('${it['id']}') ? 'Dimiliki' : '${it['price'] ?? ''} Gold', style: const TextStyle(color: C.textDim, fontSize: 12)),
          ])),
          if (!owned.contains('${it['id']}')) pillButton('Beli', busy ? null : () => _do(() => rpc('farm_buy', {'p_item': it['id']}), 'Dibeli'))
          else if (eq['$cat'] == it['id']) pillButton('Lepas', busy ? null : () => _do(() => rpc('farm_equip', {'p_cat': cat, 'p_item': null})), color: C.secondary)
          else pillButton('Pakai', busy ? null : () => _do(() => rpc('farm_equip', {'p_cat': cat, 'p_item': it['id']}))),
        ])),
    ]);
  }
}
