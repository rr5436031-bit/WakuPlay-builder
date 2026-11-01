import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../../services/anime/sanka_adapter.dart';
import '../../services/anime/sanka_api.dart';
import '../../services/supabase/supabase_service.dart';
import '../detail/detail_page.dart' show RawJsonPage;

/// Diagnosa 5 sumber: home -> detail item pertama -> stream episode pertama. Tiap langkah punya tombol "mentah".
/// Dipakai untuk menyesuaikan parser bila bentuk JSON sumber ternyata berbeda.
class DiagnosePage extends StatefulWidget {
  const DiagnosePage({super.key});
  @override
  State<DiagnosePage> createState() => _S();
}

class _Row {
  String src; String home = '–', detail = '–', stream = '–'; dynamic rawHome, rawDetail, rawStream; bool running = false;
  _Row(this.src);
}

class _S extends State<DiagnosePage> {
  final rows = [for (final s in const ['animekompi', 'winbu', 'alqanime', 'donghub', 'nimegami']) _Row(s)];

  Future<void> _run(_Row r) async {
    setState(() { r.running = true; r.home = r.detail = r.stream = '…'; });
    try {
      final ad = SankaAdapter(r.src, db);
      final homePath = (r.src == 'animekompi' || r.src == 'winbu') ? '/anime/${r.src}/home' : '/anime/${r.src}/home?page=1';
      r.rawHome = await SankaApi.get(homePath);
      final List<Anime> items = await ad.home();
      r.home = items.isEmpty ? 'GAGAL: 0 item terbaca' : 'OK ${items.length} item • contoh: ${items.first.title} [${items.first.originalId}]';
      setState(() {});
      if (items.isEmpty) return;
      final d = await SankaApi.detail(r.src, items.first.originalId);
      r.rawDetail = d.raw;
      r.detail = d.eps.isEmpty ? 'Detail ${d.info['title'] != null ? 'OK' : 'kosong'} • GAGAL: 0 episode terbaca' : 'OK • ${d.eps.length} episode • eps1: ${d.eps.first.id}';
      setState(() {});
      if (d.eps.isEmpty) return;
      final s = await SankaApi.streams(r.src, d.eps.last);
      r.rawStream = s.raw;
      r.stream = s.streams.isEmpty ? (SankaApi.noEpisodeEndpoint.contains(r.src) && d.eps.last.links.isEmpty ? 'Tidak ada endpoint stream / tautan di detail' : 'GAGAL: 0 link terbaca') : 'OK • ${s.streams.where((x) => x.isDirect).length} direct, ${s.streams.where((x) => x.isEmbed).length} embed';
    } catch (e) {
      if (r.home.startsWith('…')) { r.home = 'ERROR $e'; } else if (r.detail.startsWith('…')) { r.detail = 'ERROR $e'; } else { r.stream = 'ERROR $e'; }
    } finally { if (mounted) setState(() => r.running = false); }
  }

  Widget _line(String label, String v, dynamic raw) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 56, child: Text(label, style: const TextStyle(color: C.textDim, fontSize: 12))),
        Expanded(child: Text(v, style: TextStyle(fontSize: 12, color: v.startsWith('OK') ? Colors.greenAccent : v.startsWith('GAGAL') || v.startsWith('ERROR') ? C.danger : C.text))),
        if (raw != null) GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RawJsonPage('$label mentah', raw))), child: const Padding(padding: EdgeInsets.only(left: 6), child: Text('mentah', style: TextStyle(color: C.primary, fontSize: 12)))),
      ]));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Diagnosa Sumber'), actions: [
          TextButton(onPressed: () async { for (final r in rows) { if (!mounted) return; await _run(r); } }, child: const Text('Jalankan semua')),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Butuh Edge Function anime-multi sudah di-deploy. Jika ada yang GAGAL, buka "mentah" lalu kirim isinya ke Claude untuk menyesuaikan parser.', style: TextStyle(color: C.textDim, fontSize: 12)),
          for (final r in rows) Container(
            margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text(r.src, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const Spacer(), r.running ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : TextButton(onPressed: () => _run(r), child: const Text('Uji'))]),
              _line('Home', r.home, r.rawHome), _line('Detail', r.detail, r.rawDetail), _line('Stream', r.stream, r.rawStream),
            ]),
          ),
        ]),
      );
}
