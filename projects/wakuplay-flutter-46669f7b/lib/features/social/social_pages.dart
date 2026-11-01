import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../profile/user_profile_page.dart';

/// Teman, permintaan pertemanan, cari lewat #ID. Semua lewat RPC lama.
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _F();
}

class _F extends State<FriendsPage> {
  late Future<List<dynamic>> friends = rpc('get_friends').then((r) => r as List);
  late Future<List<dynamic>> reqs = rpc('get_friend_requests').then((r) => r as List);
  final _id = TextEditingController();
  List<dynamic> found = [];

  void _refresh() => setState(() { friends = rpc('get_friends').then((r) => r as List); reqs = rpc('get_friend_requests').then((r) => r as List); });
  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _find() async {
    final n = int.tryParse(_id.text.replaceAll('#', '').trim());
    if (n == null) return;
    try { final r = await rpc('find_friend', {'p_seq': n}); setState(() => found = r as List); } catch (e) { _msg('$e'); }
  }

  @override
  void dispose() { _id.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Teman & Pesan')),
        body: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            Expanded(child: TextField(controller: _id, keyboardType: TextInputType.number, onSubmitted: (_) => _find(),
                decoration: InputDecoration(hintText: 'Cari teman lewat #ID', filled: true, fillColor: C.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
            IconButton(onPressed: _find, icon: const Icon(Icons.search)),
          ]),
          for (final u in found)
            ListTile(
              title: Text('${u['name']} #${u['seq']}'), subtitle: Text('${u['relation']}'),
              trailing: u['relation'] == 'none'
                  ? TextButton(onPressed: () async { try { _msg('${await rpc('friend_request', {'p_target': u['user_id']})}'); _refresh(); } catch (e) { _msg('$e'); } }, child: const Text('Tambah'))
                  : null,
            ),
          const Padding(padding: EdgeInsets.only(top: 14, bottom: 4), child: Text('Permintaan', style: TextStyle(fontWeight: FontWeight.w800))),
          FutureBuilder<List<dynamic>>(future: reqs, builder: (_, s) => Column(children: [
            for (final r in (s.data ?? const []).where((x) => x['direction'] == 'in'))
              ListTile(
                title: Text('${r['name']} #${r['seq']}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: () async { await rpc('friend_respond', {'p_id': r['id'], 'p_accept': true}); _refresh(); }),
                  IconButton(icon: const Icon(Icons.close, color: C.danger), onPressed: () async { await rpc('friend_respond', {'p_id': r['id'], 'p_accept': false}); _refresh(); }),
                ]),
              ),
          ])),
          const Padding(padding: EdgeInsets.only(top: 14, bottom: 4), child: Text('Teman', style: TextStyle(fontWeight: FontWeight.w800))),
          FutureBuilder<List<dynamic>>(future: friends, builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return Column(children: [
              for (final f in s.data!)
                ListTile(
                  leading: GestureDetector(onTap: () => openProfile(context, f['user_id']), child: CircleAvatar(backgroundColor: C.surface, backgroundImage: f['avatar'] != null ? NetworkImage('${f['avatar']}') : null)),
                  title: Text('${f['name']} #${f['seq']}'),
                  trailing: (f['unread'] as num? ?? 0) > 0 ? CircleAvatar(radius: 11, backgroundColor: C.danger, child: Text('${f['unread']}', style: const TextStyle(fontSize: 11))) : null,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatPage(peerId: '${f['user_id']}', peerName: '${f['name']}'))).then((_) => _refresh()),
                ),
            ]);
          }),
        ]),
      );
}

class DirectChatPage extends StatefulWidget {
  final String peerId, peerName;
  const DirectChatPage({super.key, required this.peerId, required this.peerName});
  @override
  State<DirectChatPage> createState() => _D();
}

class _D extends State<DirectChatPage> {
  final _c = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  Timer? _t;
  String get me => db.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 4), (_) => _load()); // polling; realtime DM belum dimigrasikan
  }

  Future<void> _load() async {
    try {
      final p = widget.peerId;
      final r = await db.from('direct_messages').select()
          .or('and(sender.eq.$me,receiver.eq.$p),and(sender.eq.$p,receiver.eq.$me)').order('created_at', ascending: false).limit(80);
      if (mounted) setState(() => rows = List<Map<String, dynamic>>.from(r));
      rpc('dm_mark_read', {'p_peer': p});
    } catch (_) {}
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    try { await db.from('direct_messages').insert({'sender': me, 'receiver': widget.peerId, 'body': t}); _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  @override
  void dispose() { _t?.cancel(); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: Text(widget.peerName)),
        body: Column(children: [
          Expanded(child: ListView.builder(reverse: true, padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (_, i) {
            final r = rows[i]; final mine = r['sender'] == me;
            return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(color: mine ? C.pillBlue : C.surface, borderRadius: BorderRadius.circular(14)),
              child: Text('${r['body']}')));
          })),
          SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), child: Row(children: [
            Expanded(child: TextField(controller: _c, maxLength: 500, onSubmitted: (_) => _send(),
                decoration: InputDecoration(counterText: '', hintText: 'Tulis pesan', filled: true, fillColor: C.surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
            IconButton(onPressed: _send, icon: const Icon(Icons.send, color: C.primary)),
          ]))),
        ]),
      );
}
