import 'package:flutter/material.dart';
import '../theme/colors.dart';

class NavItem {
  final IconData icon; final String label;
  const NavItem(this.icon, this.label);
}

/// Bottom nav custom (bukan NavigationBar Material): pil aktif ungu-abu + label hanya pada tab aktif,
/// sama seperti BottomNav.jsx. Urutan: Home, Riwayat, Jadwal, Favorit, Akun.
class AppBottomNav extends StatelessWidget {
  final int index; final ValueChanged<int> onTap; final List<NavItem> items;
  const AppBottomNav({super.key, required this.index, required this.onTap, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: C.navBg,
      padding: EdgeInsets.only(top: 8, bottom: 8 + MediaQuery.of(context).padding.bottom),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (var i = 0; i < items.length; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onTap(i),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: i == index ? 64 : 40, height: 32,
                decoration: BoxDecoration(
                    color: i == index ? C.navActive : Colors.transparent, borderRadius: BorderRadius.circular(16)),
                child: Icon(items[i].icon, size: 24, color: i == index ? C.text : C.textDim),
              ),
              if (i == index)
                Padding(padding: const EdgeInsets.only(top: 2),
                    child: Text(items[i].label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
            ]),
          ),
      ]),
    );
  }
}
