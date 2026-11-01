import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../banner/banner_pick_page.dart';
import '../developer/dev_panel_page.dart';
import '../info/game_info_page.dart';
import '../genre/genre_ranking_pages.dart';
import '../leaderboard/leaderboard_page.dart';
import '../notifications/notifications_page.dart';
import '../premium/premium_page.dart';
import '../settings/settings_page.dart';
import '../social/social_pages.dart';

/// Profil dibaca dari RPC get_public_profile + wp_gold (database lama). Tidak ada nilai dihitung di klien.
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(myProfileProvider);
    final gold = ref.watch(goldProvider);
    final u = ref.read(authProvider).user;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Akun')),
      body: p.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (m) {
          final avatar = (m?['avatar'] ?? u?.userMetadata?['avatar_url'])?.toString();
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              CircleAvatar(radius: 34, backgroundColor: C.surface, backgroundImage: avatar == null ? null : CachedNetworkImageProvider(avatar)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m?['name'] ?? u?.email ?? 'Pengguna'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                Text('#${m?['seq'] ?? '-'}  •  ${m?['role'] ?? 'user'}', style: const TextStyle(color: C.textDim)),
                Text(u?.email ?? '', style: const TextStyle(color: C.textDim, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 18),
            _row('XP', '${m?['xp'] ?? 0}'),
            _row('WakuGold', gold.maybeWhen(data: (v) => '${v ?? 0}', orElse: () => '…')),
            _row('Komentar', '${m?['comments'] ?? 0}'),
            const SizedBox(height: 14),
            for (final (t, ic, w) in <(String, IconData, Widget)>[
              ('Teman & Pesan', Icons.chat, const FriendsPage()),
              ('Notifikasi', Icons.notifications, const NotificationsPage()),
              ('Leaderboard', Icons.leaderboard, const LeaderboardPage()),
              ('Genre', Icons.category, const GenrePage()),
              ('Peringkat Anime', Icons.trending_up, const RankingPage()),
              ('Premium', Icons.workspace_premium, const PremiumPage()),
              ('Banner Profil', Icons.image, const BannerPickPage()),
              ('Info! Panduan Game', Icons.info, const GameInfoPage()),
              ('Setting Aplikasi', Icons.settings, const SettingsPage()),
              ('Developer Panel', Icons.code, const DevPanelPage()),
            ])
              ListTile(leading: Icon(ic, color: C.primary), title: Text(t), trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => w))),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async => ref.read(authProvider).signOut().then((_) { if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst); }),
              child: Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: C.danger, borderRadius: BorderRadius.circular(24)),
                  child: const Text('Logout', style: TextStyle(fontWeight: FontWeight.w800))),
            ),
          ]);
        },
      ),
    );
  }

  Widget _row(String a, String b) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );
}
