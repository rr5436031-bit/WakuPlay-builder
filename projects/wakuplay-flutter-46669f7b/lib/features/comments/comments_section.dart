import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../../services/supabase/supabase_service.dart';
import '../profile/user_profile_page.dart';

/// Komentar episode + balasan (kolom parent_id) + laporkan. Tabel/RPC lama; RLS & trigger server tetap berlaku.
class CommentsSection extends StatefulWidget {
  final Anime anime; final String episodeId;
  const CommentsSection({super.key, required this.anime, required this.episodeId});
  @override
  State<CommentsSection> createState() => _S();
}

class _S extends State<CommentsSection> {
  final _c = TextEditingController();
  List<Map<String, dynamic>> rows = [];
  Map<int, int> counts = {};
  final Map<int, List<Map<String, dynamic>>> replies = {};
  Map<String, dynamic>? replyTo;
  bool loading = true;
  String get me => db.auth.currentUser!.id;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(CommentsSection o) { super.didUpdateWidget(o); if (o.episodeId != widget.episodeId) { replies.clear(); replyTo = null; _load(); } }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = List<Map<String, dynamic>>.from(await db.from('comments').select().eq('episode_id', widget.episodeId).isFilter('parent_id', null).order('created_at', ascending: false).limit(60));
      Map<int, int> cn = {};
      if (r.isNotEmpty) {
        final rc = await rpc('get_reply_counts', {'p_ids': [for (final x in r) x['id']]}) as List;
        cn = {for (final x in rc) (x['parent_id'] as num).toInt(): (x['n'] as num).toInt()};
      }
      if (mounted) setState(() { rows = r; counts = cn; loading = false; });
    } catch (_) { if (mounted) setState(() => loading = false); }
  }

  Future<void> _loadReplies(int id) async {
    final r = List<Map<String, dynamic>>.from(await db.from('comments').select().eq('parent_id', id).order('created_at', ascending: true).limit(100));
    if (mounted) setState(() => replies[id] = r);
  }

  Future<void> _send() async {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    _c.clear();
    Map? prof;
    try { final r = await db.rpc('get_public_profile', params: {'p_uid': me}); if (r is List && r.isNotEmpty) prof = r.first as Map; } catch (_) {}
    final parent = replyTo?['id'];
    try {
      await db.from('comments').insert({
        'episode_id': widget.episodeId, 'anime_id': widget.anime.storeId, 'user_id': me,
        'user_name': prof?['name'], 'user_avatar': prof?['avatar'], 'body': t, if (parent != null) 'parent_id': parent,
      });
      setState(() => replyTo = null);
      if (parent != null) { await _loadReplies((parent as num).toInt()); }
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal kirim: $e'))); }
  }

  Future<void> _report(Map<String, dynamic> r) async {
    try {
      await db.from('reports').insert({'user_id': me, 'anime_id': widget.anime.storeId, 'episode_id': widget.episodeId, 'reason': 'Komentar #${r['id']} oleh ${r['user_name'] ?? r['user_id']}'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Laporan terkirim')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); }
  }

  Widget _item(Map<String, dynamic> r, {bool sub = false}) {
    final mine = r['user_id'] == me; final id = (r['id'] as num).toInt();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ListTile(
        contentPadding: EdgeInsets.only(left: sub ? 48 : 16, right: 8),
        leading: GestureDetector(onTap: () => openProfile(context, r['user_id']), child: CircleAvatar(radius: sub ? 14 : 18, backgroundColor: C.surface, backgroundImage: r['user_avatar'] != null ? NetworkImage('${r['user_avatar']}') : null)),
        title: Text('${r['user_name'] ?? 'Pengguna'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        subtitle: Text('${r['body']}'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'del') { await db.from('comments').delete().eq('id', id); replies.clear(); _load(); }
            if (v == 'rep') _report(r);
          },
          itemBuilder: (_) => [if (mine) const PopupMenuItem(value: 'del', child: Text('Hapus')) else const PopupMenuItem(value: 'rep', child: Text('Laporkan'))],
        ),
      ),
      if (!sub) Padding(padding: const EdgeInsets.only(left: 70), child: Row(children: [
        GestureDetector(onTap: () => setState(() => replyTo = r), child: const Text('Balas', style: TextStyle(color: C.primary, fontSize: 12))),
        const SizedBox(width: 14),
        if ((counts[id] ?? 0) > 0) GestureDetector(
          onTap: () async { if (replies.containsKey(id)) { setState(() => replies.remove(id)); } else { await _loadReplies(id); } },
          child: Text(replies.containsKey(id) ? 'Sembunyikan' : 'Lihat ${counts[id]} balasan', style: const TextStyle(color: C.textDim, fontSize: 12))),
      ])),
      if (!sub) for (final x in (replies[id] ?? const <Map<String, dynamic>>[])) _item(x, sub: true),
    ]);
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (replyTo != null) Container(color: C.surface, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Row(children: [
          Expanded(child: Text('Membalas ${replyTo!['user_name'] ?? 'Pengguna'}', style: const TextStyle(fontSize: 12, color: C.textDim))),
          GestureDetector(onTap: () => setState(() => replyTo = null), child: const Icon(Icons.close, size: 16)),
        ])),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [
          Expanded(child: TextField(controller: _c, maxLength: 500, onSubmitted: (_) => _send(),
              decoration: InputDecoration(counterText: '', hintText: replyTo == null ? 'Tulis komentar' : 'Tulis balasan', filled: true, fillColor: C.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))),
          IconButton(onPressed: _send, icon: const Icon(Icons.send, color: C.primary)),
        ])),
        Expanded(child: loading
            ? const Center(child: CircularProgressIndicator())
            : rows.isEmpty
                ? const Center(child: Text('Belum ada komentar', style: TextStyle(color: C.textDim)))
                : ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => _item(rows[i]))),
      ]);
}
