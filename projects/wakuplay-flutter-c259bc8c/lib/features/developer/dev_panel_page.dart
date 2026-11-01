import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';
import 'dev_extras_page.dart';

/// Developer Panel (bagian inti): cari user, ubah role, tambah/kurangi WakuGold, blokir/buka blokir.
/// Izin ditentukan server (has_dev_panel + cek di tiap RPC dev_*); klien hanya menyembunyikan tombol.
class DevPanelPage extends StatefulWidget {
  const DevPanelPage({super.key});
  @override
  State<DevPanelPage> createState() => _S();
}

class _S extends State<DevPanelPage> {
  final _seq = TextEditingController(), _amt = TextEditingController(), _reason = TextEditingController();
  bool? allowed; Map? u; String unit = 'hari'; int banAmount = 1;

  @override
  void initState() {
    super.initState();
    rpc('has_dev_panel').then((v) { if (mounted) setState(() => allowed = v == true); }).catchError((_) { if (mounted) setState(() => allowed = false); });
  }
  @override
  void dispose() { _seq.dispose(); _amt.dispose(); _reason.dispose(); super.dispose(); }

  Future<void> _find() async {
    final n = int.tryParse(_seq.text.replaceAll('#', '').trim());
    if (n == null) return;
    try { final r = await rpc('dev_find_user', {'p_seq': n}) as List; setState(() => u = r.isEmpty ? null : Map.from(r.first as Map)); if (r.isEmpty && mounted) toast(context, 'User tidak ditemukan'); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _run(Future<dynamic> Function() f, String ok) async {
    try { await f(); if (mounted) toast(context, ok); await _find(); } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
  }

  @override
  Widget build(BuildContext context) {
    if (allowed == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (allowed == false) return Scaffold(appBar: AppBar(backgroundColor: C.background), body: const Center(child: Text('Tidak punya akses Developer Panel')));
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Developer Panel')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
          Expanded(child: TextField(controller: _seq, keyboardType: TextInputType.number, onSubmitted: (_) => _find(), decoration: InputDecoration(hintText: '#ID user', filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          IconButton(onPressed: _find, icon: const Icon(Icons.search)),
        ]),
        Padding(padding: const EdgeInsets.only(top: 10), child: Align(alignment: Alignment.centerLeft,
            child: pillButton('Banner • Giveaway • Laporan', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevExtrasPage())), color: C.pillBlue))),
        if (u != null) ...[
          card(margin: const EdgeInsets.only(top: 12, bottom: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u!['name']} #${u!['seq']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('${u!['email']}', style: const TextStyle(color: C.textDim)),
            Text('Role: ${u!['role']}   •   Banned: ${u!['banned']}'),
          ])),
          Wrap(spacing: 8, children: [for (final r in const ['user', 'moderator', 'admin', 'developer'])
            ChoiceChip(label: Text(r), selected: u!['role'] == r, onSelected: (_) => _run(() => rpc('dev_update_user', {'p_target': u!['user_id'], 'p_field': 'role', 'p_val': r}), 'Role diubah'))]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: TextField(controller: _amt, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: 'Jumlah WakuGold', filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
            const SizedBox(width: 8),
            pillButton('+', () => _run(() => rpc('dev_gold_adjust', {'p_target': u!['user_id'], 'p_amount': int.tryParse(_amt.text) ?? 0, 'p_mode': 'add'}), 'Gold ditambah')),
            const SizedBox(width: 6),
            pillButton('−', () => _run(() => rpc('dev_gold_adjust', {'p_target': u!['user_id'], 'p_amount': int.tryParse(_amt.text) ?? 0, 'p_mode': 'sub'}), 'Gold dikurangi'), color: C.danger),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text(u!['muted_until'] != null && DateTime.tryParse('${u!['muted_until']}')?.isAfter(DateTime.now()) == true ? 'Bisu s/d ${u!['muted_until']}' : 'Tidak dibisukan', style: const TextStyle(color: C.textDim))),
            for (final h in const [1, 24, 168])
              Padding(padding: const EdgeInsets.only(left: 6), child: pillButton(h == 1 ? '1j' : h == 24 ? '1h' : '7h', () => _run(() => rpc('dev_update_user', {'p_target': u!['user_id'], 'p_field': 'muted_until', 'p_val': DateTime.now().toUtc().add(Duration(hours: h)).toIso8601String()}), 'User dibisukan'), color: C.secondary)),
            Padding(padding: const EdgeInsets.only(left: 6), child: pillButton('Buka', () => _run(() => rpc('dev_update_user', {'p_target': u!['user_id'], 'p_field': 'muted_until', 'p_val': ''}), 'Bisu dibuka'), color: C.secondary)),
          ]),
          const SizedBox(height: 14),
          TextField(controller: _reason, decoration: InputDecoration(hintText: 'Alasan blokir', filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          Row(children: [
            DropdownButton<String>(value: unit, items: [for (final x in const ['menit', 'jam', 'hari', 'bulan', 'tahun', 'permanen']) DropdownMenuItem(value: x, child: Text(x))], onChanged: (v) => setState(() => unit = v!)),
            const SizedBox(width: 10),
            DropdownButton<int>(value: banAmount, items: [for (final x in const [1, 3, 7, 14, 30]) DropdownMenuItem(value: x, child: Text('$x'))], onChanged: (v) => setState(() => banAmount = v!)),
            const Spacer(),
            pillButton('Blokir', () => _run(() => rpc('dev_ban_user', {'p_target': u!['user_id'], 'p_reason': _reason.text, 'p_amount': banAmount, 'p_unit': unit}), 'User diblokir'), color: C.danger),
            const SizedBox(width: 6),
            pillButton('Buka', () => _run(() => rpc('dev_unban_user', {'p_target': u!['user_id']}), 'Blokir dibuka'), color: C.secondary),
          ]),
        ],
        const Padding(padding: EdgeInsets.only(top: 20), child: Text('Belum dimigrasikan dari DevPanel.jsx: update app, Premium admin, level config, katalog pet/border/clan/emblem, tabel user lengkap.', style: TextStyle(color: C.textDim, fontSize: 12))),
      ]),
    );
  }
}
