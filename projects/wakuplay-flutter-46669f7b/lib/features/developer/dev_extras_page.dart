import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

InputDecoration _dec(String h) => InputDecoration(hintText: h, filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none));

/// Banner global (dev_publish_banner / dev_disable_banner / get_active_banner) dan pengaturan XP giveaway
/// (dev_giveaway_xp_get/set). Hak akses diperiksa server di setiap RPC.
class DevExtrasPage extends StatefulWidget {
  const DevExtrasPage({super.key});
  @override
  State<DevExtrasPage> createState() => _S();
}

class _S extends State<DevExtrasPage> {
  final title = TextEditingController(), body = TextEditingController(), btnText = TextEditingController(), btnUrl = TextEditingController();
  final xpDay = TextEditingController(), cap = TextEditingController();
  bool button = false; Map? active; Map? gx; String? reportsMsg; List<dynamic> reports = [];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { for (final c in [title, body, btnText, btnUrl, xpDay, cap]) { c.dispose(); } super.dispose(); }

  Future<void> _load() async {
    try { final b = await rpc('get_active_banner') as List; active = b.isEmpty ? null : Map.from(b.first as Map); } catch (_) {}
    try { gx = Map.from(await rpc('dev_giveaway_xp_get') as Map); xpDay.text = '${gx!['xp_per_day'] ?? ''}'; cap.text = '${gx!['daily_cap'] ?? ''}'; } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _run(Future<dynamic> Function() f, String ok) async {
    try { await f(); if (mounted) toast(context, ok); await _load(); } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _reports() async {
    try { final r = await rpc('dev_reports_list', {'p_limit': 100}) as List; setState(() { reports = r; reportsMsg = r.isEmpty ? 'Belum ada laporan' : null; }); }
    catch (e) { setState(() => reportsMsg = 'RPC dev_reports_list belum dipasang di Supabase (lihat supabase_additions/optional_dev_reports.sql). $e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Developer • Banner, Giveaway, Laporan')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Banner aplikasi', style: TextStyle(fontWeight: FontWeight.w800)),
          Text(active == null ? 'Tidak ada banner aktif' : 'Aktif: “${active!['title']}”', style: const TextStyle(color: C.textDim, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(controller: title, maxLength: 80, decoration: _dec('Judul')),
          const SizedBox(height: 6),
          TextField(controller: body, maxLines: 3, maxLength: 400, decoration: _dec('Isi')),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tombol'), value: button, onChanged: (v) => setState(() => button = v)),
          if (button) ...[TextField(controller: btnText, decoration: _dec('Teks tombol')), const SizedBox(height: 6), TextField(controller: btnUrl, decoration: _dec('https://…'))],
          const SizedBox(height: 8),
          Row(children: [
            pillButton('Kirim banner', () => _run(() => rpc('dev_publish_banner', {'p_title': title.text, 'p_body': body.text, 'p_button': button, 'p_button_text': button ? btnText.text : null, 'p_button_url': button ? btnUrl.text : null}), 'Banner dikirim')),
            const SizedBox(width: 8),
            pillButton('Matikan', active == null ? null : () => _run(() => rpc('dev_disable_banner'), 'Banner dimatikan'), color: C.danger),
          ]),
          const Divider(height: 36),
          const Text('XP Giveaway', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: xpDay, keyboardType: TextInputType.number, decoration: _dec('XP per hari'))), const SizedBox(width: 8),
            Expanded(child: TextField(controller: cap, keyboardType: TextInputType.number, decoration: _dec('Batas harian'))),
          ]),
          const SizedBox(height: 8),
          pillButton('Simpan', () => _run(() => rpc('dev_giveaway_xp_set', {'p_xp_per_day': int.tryParse(xpDay.text) ?? 0, 'p_daily_cap': int.tryParse(cap.text) ?? 0}), 'Tersimpan')),
          const Divider(height: 36),
          const Text('Laporan pengguna', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          pillButton('Muat laporan', _reports, color: C.secondary),
          if (reportsMsg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(reportsMsg!, style: const TextStyle(color: C.textDim, fontSize: 12))),
          for (final r in reports.whereType<Map>())
            card(margin: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r['user_name'] ?? r['user_id']}  •  ${r['created_at']}', style: const TextStyle(color: C.textDim, fontSize: 11)),
              Text('${r['reason']}'),
              if (r['anime_id'] != null) Text('anime ${r['anime_id']}  eps ${r['episode_id'] ?? '-'}', style: const TextStyle(color: C.textDim, fontSize: 11)),
            ])),
        ]),
      );
}
