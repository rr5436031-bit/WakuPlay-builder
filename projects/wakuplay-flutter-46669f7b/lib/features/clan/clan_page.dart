import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';
import 'clan_extra_pages.dart';
import 'clan_manage_page.dart';
import '../profile/user_profile_page.dart';

/// Clan: lihat clan sendiri, daftar clan teratas, gabung, buat, keluar, klaim harian. Semua validasi di RPC server.
class ClanPage extends StatefulWidget {
  const ClanPage({super.key});
  @override
  State<ClanPage> createState() => _S();
}

class _S extends State<ClanPage> {
  Map? ov; List<dynamic> top = []; Map? detail; List<dynamic> members = []; String? err; bool busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final o = await rpc('clan_overview') as Map;
      final clan = o['clan'] is Map ? o['clan'] as Map : null;
      final id = clan?['id'] ?? o['clan_id'];
      Map? d; List<dynamic> m = const [];
      List<dynamic> t = const [];
      if (id != null) {
        d = await rpc('clan_detail', {'p_id': id}) as Map;
        m = await rpc('clan_members_list', {'p_clan': id}) as List;
      } else {
        t = await rpc('clan_top', {'p_limit': 50}) as List;
      }
      if (mounted) setState(() { ov = o; detail = d; members = m; top = t; err = null; });
    } catch (e) { if (mounted) setState(() => err = '$e'); }
  }

  Future<void> _do(Future<dynamic> Function() f, [String? ok]) async {
    setState(() => busy = true);
    try { final r = await f(); if (mounted) toast(context, ok ?? (r is String ? r : 'Berhasil')); await _load(); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String _myRole() {
    final me = db.auth.currentUser?.id;
    for (final m in members) { if (m is Map && m['user_id'] == me) return '${m['role']}'; }
    return 'member';
  }

  Future<void> _editBanner() async {
    final c = TextEditingController(text: '${detail?['banner'] ?? ''}');
    final ok = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Banner Clan (.gif)'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: c, keyboardType: TextInputType.url, decoration: const InputDecoration(hintText: 'https://domain/…/banner.gif')),
        const SizedBox(height: 6), const Text('Kosongkan untuk menghapus. Hanya Leader/Vice Leader.', style: TextStyle(fontSize: 11, color: C.textDim)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Simpan'))],
    ));
    final v = c.text.trim();
    c.dispose();
    if (ok != true) return;
    if (v.isNotEmpty && !RegExp(r'^https://([a-z0-9-]+\.)+[a-z]{2,}/[^\s?#@]*\.gif(\?[^\s#]*)?$', caseSensitive: false).hasMatch(v)) { toast(context, 'Link harus https://domain/.../nama.gif'); return; }
    _do(() => rpc('clan_set_banner', {'p_url': v.isEmpty ? null : v}), 'Banner disimpan');
  }

  int _cid() => ((((ov!['clan'] as Map?)?['id']) ?? ov!['clan_id']) as num).toInt();
  Future<void> _open(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => _load());

  Future<void> _create() async {
    final tag = TextEditingController(), name = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: Text('Buat Clan • ${fmtNum(num.tryParse('${(ov?['config'] as Map?)?['create_cost'] ?? 3500}') ?? 3500)} Gold'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: tag, maxLength: 4, decoration: const InputDecoration(labelText: 'TAG')),
        TextField(controller: name, maxLength: 24, decoration: const InputDecoration(labelText: 'Nama clan')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Buat'))],
    ));
    if (ok == true) _do(() => rpc('clan_create', {'p_tag': tag.text.trim(), 'p_name': name.text.trim(), 'p_req': uuid4()}), 'Clan dibuat');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Clan')),
        body: err != null ? Center(child: Text(err!)) : ov == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
          if (detail != null) ...[
            card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ('${detail!['banner'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network('${detail!['banner']}', height: 100, width: double.infinity, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => const SizedBox()))),
              Row(children: [
                Expanded(child: Text('${(ov!['clan'] as Map?)?['name'] ?? detail!['name'] ?? 'Clan'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                if (const {'leader', 'vice_leader'}.contains(_myRole())) TextButton(onPressed: busy ? null : _editBanner, child: const Text('Banner')),
              ]),
              const SizedBox(height: 8), JsonRows(detail!),
            ])),
            Row(children: [
              Expanded(child: pillButton('Klaim Harian', busy ? null : () => _do(() => rpc('clan_daily_claim', {'p_req': uuid4()}), 'Klaim diproses'))),
              const SizedBox(width: 10),
              pillButton('Keluar', busy ? null : () => _do(() => rpc('clan_leave'), 'Keluar dari clan'), color: C.danger),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: pillButton('Clan Gacha', () => _open(ClanSpinPage(clanId: _cid(), config: (ov!['config'] as Map?) ?? const {})), color: C.pillBlue)),
              const SizedBox(width: 10),
              Expanded(child: pillButton('Emblem', () => _open(ClanEmblemPage(clanId: _cid(), config: (ov!['config'] as Map?) ?? const {})), color: C.secondary)),
            ]),
            const SizedBox(height: 10),
            pillButton('Kelola Clan • Donasi • Permintaan', () => _open(ClanManagePage(clanId: _cid(), myRole: _myRole(), config: (ov!['config'] as Map?) ?? const {})), color: C.secondary),
            const SizedBox(height: 14),
            Text('Anggota (${members.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
            for (final m in members) ListTile(
              onTap: () => openProfile(context, m['user_id']),
              leading: CircleAvatar(backgroundColor: C.surface, backgroundImage: m['avatar'] != null ? NetworkImage('${m['avatar']}') : null),
              title: Text('${m['name']} #${m['seq']}'), subtitle: Text('${m['role']} • XP ${num.tryParse('${m['xp']}')?.round() ?? 0}'),
              trailing: m['user_id'] == db.auth.currentUser?.id ? null : PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'kick') { _do(() => rpc('clan_kick', {'p_user': m['user_id']}), 'Anggota dikeluarkan'); }
                  else if (v == 'transfer') { _do(() => rpc('clan_transfer', {'p_user': m['user_id']}), 'Kepemimpinan dipindahkan'); }
                  else { _do(() => rpc('clan_set_role', {'p_user': m['user_id'], 'p_role': v}), 'Peran diubah'); }
                },
                itemBuilder: (_) => [
                  for (final r in const ['vice_leader', 'admiral', 'officer', 'member']) PopupMenuItem(value: r, child: Text('Jadikan $r')),
                  const PopupMenuItem(value: 'kick', child: Text('Keluarkan')),
                  const PopupMenuItem(value: 'transfer', child: Text('Serahkan pemimpin')),
                ],
              )),
          ] else ...[
            pillButton('Buat Clan', busy ? null : _create),
            const SizedBox(height: 14),
            const Text('Clan teratas', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final c in top) card(child: Row(children: [
              Text('[${c['tag']}]', style: const TextStyle(color: C.accent, fontWeight: FontWeight.w800)), const SizedBox(width: 8),
              Expanded(child: Text('${c['name']}\nLv ${c['level']} • ${c['members']} anggota', style: const TextStyle(fontSize: 13))),
              pillButton('Gabung', busy ? null : () => _do(() => rpc('clan_join', {'p_clan': c['id'], 'p_req': uuid4()}))),
            ])),
          ],
        ]),
      );
}
