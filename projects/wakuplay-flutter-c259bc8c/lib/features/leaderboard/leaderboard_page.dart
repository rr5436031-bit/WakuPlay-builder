import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../profile/user_profile_page.dart';

/// Leaderboard XP (harian/mingguan/bulanan), Top Level, Top Giver. Data murni dari RPC lama.
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _S();
}

class _S extends State<LeaderboardPage> {
  int tab = 0; String period = 'daily';
  Future<List<dynamic>>? f;

  @override
  void initState() { super.initState(); _reload(); }

  void _reload() => setState(() {
        f = switch (tab) {
          0 => rpc('get_xp_leaderboard', {'p_period': period}).then((r) => r as List),
          1 => rpc('get_top_levels', {'p_limit': 100}).then((r) => r as List),
          _ => rpc('get_top_givers', {'p_period': 'all', 'p_limit': 100}).then((r) => r as List),
        };
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Leaderboard')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(10), child: Row(children: [
            for (final (i, t) in ['XP', 'Top Level', 'Top Giver'].indexed)
              Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                onTap: () { tab = i; _reload(); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: tab == i ? C.pillBlue : C.surface, borderRadius: BorderRadius.circular(20)), child: Text(t)))),
          ])),
          if (tab == 0)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final p in const [['daily', 'Harian'], ['weekly', 'Mingguan'], ['monthly', 'Bulanan']])
                TextButton(onPressed: () { period = p[0]; _reload(); }, child: Text(p[1], style: TextStyle(color: period == p[0] ? C.accent : C.textDim))),
            ]),
          Expanded(child: FutureBuilder<List<dynamic>>(
            future: f,
            builder: (_, s) {
              if (s.hasError) return Center(child: Text('${s.error}'));
              if (!s.hasData) return const Center(child: CircularProgressIndicator());
              final rows = s.data!;
              return ListView.builder(itemCount: rows.length, itemBuilder: (_, i) {
                final r = rows[i] as Map;
                final val = tab == 0 ? r['gain'] : r['total_xp'];
                return ListTile(
                  onTap: () => openProfile(context, r['user_id']),
                  leading: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 28, child: Text('${r['rank']}', style: TextStyle(fontWeight: FontWeight.w800, color: (r['rank'] as num) <= 3 ? C.accent : C.text))),
                    CircleAvatar(radius: 18, backgroundColor: C.surface, backgroundImage: r['avatar'] != null ? NetworkImage('${r['avatar']}') : null),
                  ]),
                  title: Text('${r['name'] ?? 'Pengguna'}', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('#${r['seq'] ?? ''}  ${r['role'] ?? ''}', style: const TextStyle(color: C.textDim, fontSize: 12)),
                  trailing: Text('${val is num ? val.round() : val} XP', style: const TextStyle(fontWeight: FontWeight.w800)),
                );
              });
            },
          )),
        ]),
      );
}
