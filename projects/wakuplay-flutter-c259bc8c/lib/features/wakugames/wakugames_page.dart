import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../core/widgets/cosmic_bg.dart';
import '../../core/widgets/game_icons.dart';
import '../clan/clan_page.dart';
import '../games/farm_page.dart';
import '../games/gacha_pages.dart';
import '../info/game_info_page.dart';
import '../pet/pet_pages.dart';
import '../premium/premium_page.dart';

/// WakuGames: 6 menu + kartu WakuGold di atas latar kosmik. Ikon/ilustrasi SVG (GameIcons.jsx) belum dibuat ulang.
class WakuGamesPage extends ConsumerWidget {
  const WakuGamesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gold = ref.watch(goldProvider);
    void go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w)).then((_) => ref.invalidate(goldProvider));
    final menus = <(String, String, String, Widget)>[
      ('Kebun Waku', 'Panen wortel', 'CarrotIcon', const FarmPage()),
      ('Clan', 'Gabung & bersaing', 'ClanEmblem', const ClanPage()),
      ('Gacha Wallpaper', 'Koleksi banner', 'WallIcon', const SummonPage(title: 'Gacha Wallpaper', infoRpc: 'gacha_info', summonRpc: 'gacha_summon')),
      ('Avatar Border', 'Dekorasi avatar', 'BorderIcon', const BorderShopPage()),
      ('Pet', 'Koleksi pet', 'PetIcon', const PetPage()),
      ('Info!', 'Panduan game', 'InfoIcon', const GameInfoPage()),
      ('Premium', 'Bebas iklan', 'BadgeIcon', const PremiumPage()),
    ];
    return CosmicBg(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('WakuGames', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(C.radiusCard), border: Border.all(color: Colors.white12)),
              child: Row(children: [
                const Icon(Icons.monetization_on, color: C.accent), const SizedBox(width: 10),
                const Text('WakuGold', style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(),
                Text(gold.maybeWhen(data: (v) => fmtNum(v ?? 0), orElse: () => '…'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.accent)),
              ]),
            ),
            const SizedBox(height: 14),
            Expanded(child: GridView.builder(
              itemCount: menus.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.25),
              itemBuilder: (_, k) {
                final m = menus[k];
                return _MenuCard(index: k, icon: m.$3, title: m.$1, sub: m.$2, onTap: () => go(m.$4));
              },
            )),
          ]),
        ),
      ),
    );
  }
}

/// Kartu menu: masuk bertahap (fade + naik), tekan = menyusut, ikon melayang pelan. Tanpa efek berat.
class _MenuCard extends StatefulWidget {
  final int index; final String icon, title, sub; final VoidCallback onTap;
  const _MenuCard({required this.index, required this.icon, required this.title, required this.sub, required this.onTap});
  @override
  State<_MenuCard> createState() => _MC();
}

class _MC extends State<_MenuCard> with SingleTickerProviderStateMixin {
  bool down = false;
  late final AnimationController _f = AnimationController(vsync: this, duration: Duration(milliseconds: 2600 + widget.index * 230))..repeat(reverse: true);
  @override
  void dispose() { _f.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 420 + widget.index * 70), curve: Curves.easeOutCubic,
        builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 24), child: child)),
        child: GestureDetector(
          onTapDown: (_) => setState(() => down = true),
          onTapCancel: () => setState(() => down = false),
          onTapUp: (_) => setState(() => down = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: down ? .95 : 1, duration: const Duration(milliseconds: 110),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(C.radiusCard), border: Border.all(color: Colors.white12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                AnimatedBuilder(animation: _f, builder: (_, child) => Transform.translate(offset: Offset(0, -3 * _f.value), child: child), child: GameIcon(widget.icon)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(widget.sub, style: const TextStyle(color: C.textDim, fontSize: 12)),
                ]),
              ]),
            ),
          ),
        ),
      );
}
