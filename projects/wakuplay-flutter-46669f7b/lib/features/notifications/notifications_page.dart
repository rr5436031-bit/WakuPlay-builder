import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';

/// Notifikasi dalam aplikasi (tabel notifications, hanya baca; tandai dibaca lewat RPC). Push native belum ada.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _S();
}

class _S extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> f = _load();

  Future<List<Map<String, dynamic>>> _load() async => List<Map<String, dynamic>>.from(
      await db.from('notifications').select().eq('user_id', db.auth.currentUser!.id).order('created_at', ascending: false).limit(60));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Notifikasi'), actions: [
          TextButton(onPressed: () async { await rpc('notif_mark_read'); setState(() => f = _load()); }, child: const Text('Baca semua')),
        ]),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            if (s.data!.isEmpty) return const Center(child: Text('Belum ada notifikasi', style: TextStyle(color: C.textDim)));
            return ListView(children: [
              for (final n in s.data!)
                ListTile(
                  leading: Icon(n['type'] == 'dm' ? Icons.chat : n['type'] == 'episode' ? Icons.play_circle : Icons.person_add, color: n['read_at'] == null ? C.primary : C.textDim),
                  title: Text('${n['title']}', style: TextStyle(fontWeight: n['read_at'] == null ? FontWeight.w800 : FontWeight.w400)),
                  subtitle: Text('${n['body'] ?? ''}'),
                  onTap: () async { await rpc('notif_mark_read', {'p_id': n['id']}); setState(() => f = _load()); },
                ),
            ]);
          },
        ),
      );
}
