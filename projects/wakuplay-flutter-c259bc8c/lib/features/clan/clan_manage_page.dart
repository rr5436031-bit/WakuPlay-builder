import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

/// Kelola clan: permintaan gabung, donasi, riwayat XP clan, mode gabung, tier, slot, bubarkan.
/// Semua izin & biaya diputuskan RPC server (peran leader/vice_leader/admiral/officer/member).
class ClanManagePage extends StatefulWidget {
  final int clanId; final String myRole; final Map config;
  const ClanManagePage({super.key, required this.clanId, required this.myRole, required this.config});
  @override
  State<ClanManagePage> createState() => _S();
}

class _S extends State<ClanManagePage> {
  List<dynamic> reqs = [], donations = [], logs = []; final gold = TextEditingController(); bool busy = false;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { gold.dispose(); super.dispose(); }

  Future<void> _load() async {
    final id = widget.clanId;
    try { reqs = await rpc('clan_requests_list', {'p_clan': id}) as List; } catch (_) { reqs = []; }
    try { donations = await rpc('clan_donations_list', {'p_clan': id, 'p_limit': 50}) as List; } catch (_) {}
    try { logs = await rpc('clan_log_list', {'p_clan': id, 'p_limit': 30}) as List; } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _do(Future<dynamic> Function() f, String ok, {bool pop = false}) async {
    setState(() => busy = true);
    try { await f(); if (mounted) toast(context, ok); if (pop && mounted) { Navigator.pop(context, true); return; } await _load(); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  Future<bool> _confirm(String t) async => await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: Text(t), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya'))])) == true;

  @override
  Widget build(BuildContext context) {
    final lead = widget.myRole == 'leader';
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Kelola Clan')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Donasi XPGold ke clan', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: TextField(controller: gold, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Jumlah Gold', filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none)))),
          const SizedBox(width: 8),
          pillButton('Donasi', busy ? null : () => _do(() => rpc('clan_donate', {'p_gold': int.tryParse(gold.text) ?? 0, 'p_req': uuid4()}), 'Donasi terkirim')),
        ]),
        if (['leader', 'vice_leader', 'admiral'].contains(widget.myRole)) ...[
          const Padding(padding: EdgeInsets.only(top: 18, bottom: 6), child: Text('Permintaan gabung', style: TextStyle(fontWeight: FontWeight.w800))),
          if (reqs.isEmpty) const Text('Tidak ada permintaan', style: TextStyle(color: C.textDim)),
          for (final r in reqs.whereType<Map>()) ListTile(
            leading: CircleAvatar(backgroundColor: C.surface, backgroundImage: r['avatar'] != null ? NetworkImage('${r['avatar']}') : null),
            title: Text('${r['name']} #${r['seq']}'), subtitle: Text('XP ${num.tryParse('${r['xp']}')?.round() ?? 0}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: busy ? null : () => _do(() => rpc('clan_request_respond', {'p_id': r['id'], 'p_accept': true}), 'Diterima')),
              IconButton(icon: const Icon(Icons.close, color: C.danger), onPressed: busy ? null : () => _do(() => rpc('clan_request_respond', {'p_id': r['id'], 'p_accept': false}), 'Ditolak')),
            ]),
          ),
          const Padding(padding: EdgeInsets.only(top: 14, bottom: 6), child: Text('Mode gabung', style: TextStyle(fontWeight: FontWeight.w800))),
          Wrap(spacing: 8, children: [for (final m in const [['open', 'Terbuka'], ['request', 'Persetujuan'], ['closed', 'Tertutup']])
            ActionChip(label: Text(m[1]), onPressed: busy ? null : () => _do(() => rpc('clan_set_join_mode', {'p_mode': m[0]}), 'Mode diubah'))]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: pillButton('Naik Tier', busy ? null : () async { if (await _confirm('Naik tier? Biaya XPGold dipotong dari kas clan.')) _do(() => rpc('clan_upgrade_tier', {'p_req': uuid4()}), 'Tier naik'); }, color: C.accent)),
            const SizedBox(width: 10),
            Expanded(child: pillButton('Tambah Slot', busy ? null : () async { if (await _confirm('Beli slot anggota?')) _do(() => rpc('clan_buy_slots', {'p_req': uuid4()}), 'Slot bertambah'); }, color: C.pillBlue)),
          ]),
        ],
        const Padding(padding: EdgeInsets.only(top: 18, bottom: 6), child: Text('Donasi terbaru', style: TextStyle(fontWeight: FontWeight.w800))),
        for (final d in donations.whereType<Map>().take(15)) ListTile(dense: true, title: Text('${d['name']}'), trailing: Text('+${fmtNum(num.tryParse('${d['gold']}') ?? 0)} Gold • ${fmtNum(num.tryParse('${d['xp']}') ?? 0)} XP')),
        const Padding(padding: EdgeInsets.only(top: 14, bottom: 6), child: Text('Riwayat clan', style: TextStyle(fontWeight: FontWeight.w800))),
        for (final l in logs.whereType<Map>()) ListTile(dense: true, title: Text('${l['note'] ?? l['kind']}'), subtitle: Text('${l['name'] ?? ''}  ${l['created_at'] ?? ''}', style: const TextStyle(fontSize: 11)),
            trailing: Text('${(l['delta'] as num? ?? 0) >= 0 ? '+' : ''}${l['delta']}', style: TextStyle(color: (l['delta'] as num? ?? 0) >= 0 ? Colors.green : C.danger))),
        if (lead) Padding(padding: const EdgeInsets.only(top: 20), child: pillButton('Bubarkan Clan', busy ? null : () async { if (await _confirm('Bubarkan clan? Tindakan ini tidak bisa dibatalkan.')) _do(() => rpc('clan_disband'), 'Clan dibubarkan', pop: true); }, color: C.danger)),
      ]),
    );
  }
}
