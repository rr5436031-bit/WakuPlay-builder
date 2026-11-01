import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

List<String> _names(dynamic r) {
  final out = <String>[];
  void walk(dynamic v) {
    if (v is List) { v.forEach(walk); return; }
    if (v is Map) { if (v['name'] != null) { out.add('${v['name']}${v['rarity'] != null ? ' (${v['rarity']})' : ''}'); return; } v.values.forEach(walk); }
  }
  walk(r);
  return out;
}

/// "Clan Gacha" = Spin Warna clan (clan_spin / clan_spin5). Hanya pemimpin; biaya & hasil ditentukan server.
class ClanSpinPage extends StatefulWidget {
  final int clanId; final Map config;
  const ClanSpinPage({super.key, required this.clanId, required this.config});
  @override
  State<ClanSpinPage> createState() => _S();
}

class _S extends State<ClanSpinPage> {
  bool busy = false; String? result; List<dynamic> colors = [];
  @override
  void initState() { super.initState(); _colors(); }
  Future<void> _colors() async { try { final r = await rpc('clan_colors_list', {'p_clan': widget.clanId}); if (mounted) setState(() => colors = r as List); } catch (_) {} }

  Future<void> _spin(String fn) async {
    setState(() => busy = true);
    try {
      final r = await rpc(fn, {'p_req': uuid4()});
      final n = _names(r);
      setState(() => result = n.isEmpty ? '$r' : n.join(', '));
      await _colors();
    } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cost = num.tryParse('${widget.config['spin_cost'] ?? 300}') ?? 300;
    final cost5 = num.tryParse('${widget.config['spin5_cost'] ?? cost * 5}') ?? cost * 5;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Clan Gacha • Spin Warna')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: pillButton('Spin • ${fmtNum(cost)} XPGold', busy ? null : () => _spin('clan_spin'))), const SizedBox(width: 10),
          Expanded(child: pillButton('Spin x5 • ${fmtNum(cost5)}', busy ? null : () => _spin('clan_spin5'), color: C.accent)),
        ]),
        if (result != null) card(margin: const EdgeInsets.only(top: 12), child: Text('Hasil: $result')),
        const SizedBox(height: 14),
        Text('Warna (${colors.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
        for (final c in colors.whereType<Map>())
          ListTile(
            title: Text('${c['name'] ?? c['id']}'), subtitle: Text('${c['rarity'] ?? ''}'),
            trailing: c['owned'] == true
                ? (c['selected'] == true ? const Text('Dipakai', style: TextStyle(color: C.accent)) : TextButton(onPressed: () async { try { await rpc('clan_set_color', {'p_color': c['id']}); _colors(); } catch (e) { if (mounted) toast(context, '$e'); } }, child: const Text('Pakai')))
                : null,
          ),
      ]),
    );
  }
}

/// Emblem clan: daftar (clan_emblems_list), pilih (clan_set_emblem), spin (clan_emblem_spin 1 atau 5).
class ClanEmblemPage extends StatefulWidget {
  final int clanId; final Map config;
  const ClanEmblemPage({super.key, required this.clanId, required this.config});
  @override
  State<ClanEmblemPage> createState() => _E();
}

class _E extends State<ClanEmblemPage> {
  List<dynamic> list = []; bool busy = false; String? result; String? err;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { try { final r = await rpc('clan_emblems_list', {'p_clan': widget.clanId}); if (mounted) setState(() { list = r as List; err = null; }); } catch (e) { if (mounted) setState(() => err = '$e'); } }

  Future<void> _spin(int n) async {
    setState(() => busy = true);
    try { final r = await rpc('clan_emblem_spin', {'p_req': uuid4(), 'p_count': n}); final nm = _names(r); setState(() => result = nm.isEmpty ? '$r' : nm.join(', ')); await _load(); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) {
    final cost = num.tryParse('${widget.config['emblem_spin_cost'] ?? widget.config['spin_cost'] ?? 0}') ?? 0;
    final cost5 = num.tryParse('${widget.config['emblem_spin5_cost'] ?? cost * 5}') ?? cost * 5;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Emblem Clan')),
      body: err != null ? Center(child: Text(err!)) : ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: pillButton('Spin${cost > 0 ? ' • ${fmtNum(cost)}' : ''}', busy ? null : () => _spin(1))), const SizedBox(width: 10),
          Expanded(child: pillButton('Spin x5${cost5 > 0 ? ' • ${fmtNum(cost5)}' : ''}', busy ? null : () => _spin(5), color: C.accent)),
        ]),
        if (result != null) card(margin: const EdgeInsets.only(top: 12), child: Text('Hasil: $result')),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: list.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .85),
          itemBuilder: (_, i) {
            final e = list[i] as Map; final owned = e['owned'] == true;
            return GestureDetector(
              onTap: owned ? () async { try { await rpc('clan_set_emblem', {'p_emblem': e['selected'] == true ? null : e['id']}); _load(); } catch (x) { if (mounted) toast(context, '$x'); } } : null,
              child: Opacity(opacity: owned ? 1 : .35, child: Container(
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard),
                    border: Border.all(color: e['selected'] == true ? C.accent : rarityColor['${e['rarity']}'] ?? C.border, width: e['selected'] == true ? 2.5 : 1)),
                padding: const EdgeInsets.all(8),
                child: Column(children: [
                  Expanded(child: e['image_url'] != null ? Image.network('${e['image_url']}', fit: BoxFit.contain, cacheWidth: 200, errorBuilder: (_, __, ___) => const Icon(Icons.shield)) : const Icon(Icons.shield)),
                  Text('${e['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                ]),
              )),
            );
          },
        ),
      ]),
    );
  }
}
