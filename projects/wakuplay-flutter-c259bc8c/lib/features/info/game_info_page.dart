import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/theme/colors.dart';

/// Info! — tutorial semua game (data dari src/lib/gameInfo.js, diekspor ke assets/game_info.json).
class GameInfoPage extends StatefulWidget {
  const GameInfoPage({super.key});
  @override
  State<GameInfoPage> createState() => _S();
}

class _S extends State<GameInfoPage> {
  Map<String, dynamic>? data; String q = '';
  final open = <String>{};

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/game_info.json').then((t) { if (mounted) setState(() => data = jsonDecode(t) as Map<String, dynamic>); });
  }

  List<Widget> _rich(String t) => [
        RichText(text: TextSpan(style: const TextStyle(color: C.text, height: 1.4), children: [
          for (final (i, p) in t.split('**').indexed) TextSpan(text: p, style: TextStyle(fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w400)),
        ])),
      ];

  @override
  Widget build(BuildContext context) {
    final games = (data?['GAME_INFO'] as List? ?? const []).cast<Map>();
    final ql = q.toLowerCase().trim();
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Info!')),
      body: data == null ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [
        TextField(onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: 'Cari panduan', prefixIcon: const Icon(Icons.search), filled: true, fillColor: C.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none))),
        const SizedBox(height: 10),
        for (final g in games) ...() {
          final topics = [for (final t in (g['topics'] as List).cast<Map>()) if (ql.isEmpty || jsonEncode(t).toLowerCase().contains(ql)) t];
          if (topics.isEmpty) return <Widget>[];
          return <Widget>[
            Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text('${g['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
            if ('${g['tagline']}'.isNotEmpty) Text('${g['tagline']}', style: const TextStyle(color: C.textDim, fontSize: 12)),
            for (final (n, t) in topics.indexed) Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
              child: Column(children: [
                ListTile(
                  leading: CircleAvatar(radius: 14, backgroundColor: C.pillBlue, child: Text('${n + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text('${t['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: t['summary'] != null ? Text('${t['summary']}', style: const TextStyle(fontSize: 12)) : null,
                  trailing: Icon(open.contains('${g['id']}/${t['id']}') ? Icons.expand_less : Icons.expand_more),
                  onTap: () => setState(() { final k = '${g['id']}/${t['id']}'; open.contains(k) ? open.remove(k) : open.add(k); }),
                ),
                if (open.contains('${g['id']}/${t['id']}') || ql.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final (i, st) in (t['steps'] as List? ?? const []).indexed) Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${i + 1}. ', style: const TextStyle(color: C.accent, fontWeight: FontWeight.w800)), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _rich('$st'))),
                  ])),
                  for (final tp in (t['tips'] as List? ?? const [])) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.bolt, size: 16, color: C.accent), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _rich('Tips: $tp')))])),
                  if (t['warn'] != null) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0x33F0483E), borderRadius: BorderRadius.circular(10)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.shield, size: 16, color: C.danger), const SizedBox(width: 6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _rich('${t['warn']}')))])),
                ])),
              ]),
            ),
          ];
        }(),
        const Padding(padding: EdgeInsets.only(top: 22, bottom: 6), child: Text('Kabar terbaru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        for (final n in (data!['NEWS'] as List).cast<Map>().take(8)) ListTile(dense: true, title: Text('${n['text']}', style: const TextStyle(fontSize: 13)), subtitle: Text('${n['date']}', style: const TextStyle(color: C.textDim, fontSize: 11))),
      ]),
    );
  }
}
