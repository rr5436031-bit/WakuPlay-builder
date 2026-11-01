import 'package:flutter/material.dart';
import '../../core/widgets/bottom_nav.dart';
import '../../services/notify/push_service.dart';
import '../../services/notify/notif_router.dart';
import '../../services/xp/xp_service.dart';
import '../common/active_banner.dart';
import '../common/placeholder_page.dart';
import '../home/home_page.dart';
import '../library/library_pages.dart';
import '../schedule/schedule_page.dart';
import '../wakugames/wakugames_page.dart';

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});
  @override
  State<ShellPage> createState() => _S();
}

class _S extends State<ShellPage> {
  int i = 0;
  @override
  void initState() { super.initState(); PushService.ensure(); NotifRouter.init(); XpService.init(); WidgetsBinding.instance.addPostFrameCallback((_) => ActiveBanner.show(context)); }
  static const items = [
    NavItem(Icons.home_rounded, 'Home'),
    NavItem(Icons.history_rounded, 'Riwayat'),
    NavItem(Icons.calendar_month_rounded, 'Jadwal'),
    NavItem(Icons.video_library_rounded, 'Favorit'),
    NavItem(Icons.sports_esports_rounded, 'Games'),
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [
          HomePage(),
          HistoryPage(),
          SchedulePage(),
          FavoritesPage(),
          WakuGamesPage(),
        ]),
        bottomNavigationBar: AppBottomNav(index: i, items: items, onTap: (v) => setState(() => i = v)),
      );
}
