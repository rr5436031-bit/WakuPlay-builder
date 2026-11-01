import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../profile/user_profile_page.dart';

/// Global Chat memakai tabel lama global_messages (RLS: baca semua, insert/hapus milik sendiri).
/// Identitas (nama/avatar/seq) diambil dari profil lewat RPC; kolom user_name/avatar/seq sama seperti Chat.jsx.
class GlobalChatPage extends StatefulWidget {
  const GlobalChatPage({super.key});
  @override
  State<GlobalChatPage> createState() => _S();
}

class _S extends State<GlobalChatPage> {
  final _c = TextEditingController();
  Map<String, dynamic>? _me;
  late final Stream<List<Map<String, dynamic>>> _stream = db
      .from('global_messages').stream(primaryKey: ['id']).order('created_at', ascending: false).limit(80);

  @override
  void initState() {
    super.initState();
    final uid = db.auth.currentUser!.id;
    db.rpc('get_public_profile', params: {'p_uid': uid}).then((r) {
      if (r is List && r.isNotEmpty && mounted) setState(() => _me = Map<String, dynamic>.from(r.first as Map));
    }).catchError((_) {});
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty || t.length > 500) return;
    _c.clear();
    await db.from('global_messages').insert({
      'user_id': db.auth.currentUser!.id,
      'user_name': _me?['name'], 'user_avatar': _me?['avatar'], 'user_seq': _me?['seq'],
      'body': t,
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final me = db.auth.currentUser!.id;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Global Chat')),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _stream,
          builder: (_, s) {
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rows = s.data!;
            return ListView.builder(
              reverse: true, padding: const EdgeInsets.all(12), itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i]; final mine = r['user_id'] == me;
                return Align(
                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => openProfile(context, r['user_id']),
                    onLongPress: mine ? () => db.from('global_messages').delete().eq('id', r['id']) : null, // hapus lewat tekan lama
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(color: mine ? C.pillBlue : C.surface, borderRadius: BorderRadius.circular(14)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${r['user_name'] ?? 'Pengguna'}  #${r['user_seq'] ?? ''}', style: const TextStyle(fontSize: 11, color: C.accent, fontWeight: FontWeight.w700)),
                        Text('${r['body']}'),
                      ]),
                    ),
                  ),
                );
              },
            );
          },
        )),
        SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(12, 6, 12, 8), child: Row(children: [
          Expanded(child: TextField(controller: _c, maxLength: 500, onSubmitted: (_) => _send(),
              decoration: InputDecoration(counterText: '', hintText: 'Tulis pesan', filled: true, fillColor: C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          IconButton(onPressed: _send, icon: const Icon(Icons.send, color: C.primary)),
        ]))),
      ]),
    );
  }
}
