import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

/// Banner profil: pasang wallpaper gacha yang dimiliki, atau URL .gif sendiri (hak Premium/staf diperiksa server di set_my_banner).
class BannerPickPage extends StatefulWidget {
  const BannerPickPage({super.key});
  @override
  State<BannerPickPage> createState() => _S();
}

class _S extends State<BannerPickPage> {
  String cur = ''; List<Map> inv = []; final url = TextEditingController(); bool busy = false;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { url.dispose(); super.dispose(); }

  Future<void> _load() async {
    try { final p = await rpc('get_public_profile', {'p_uid': db.auth.currentUser!.id}); if (p is List && p.isNotEmpty) cur = '${(p.first as Map)['banner_url'] ?? ''}'; } catch (_) {}
    try {
      final r = await rpc('gacha_inventory_me');
      final out = <Map>[];
      void walk(dynamic v) { if (v is List) { v.forEach(walk); } else if (v is Map) { if (v['url'] != null || v['image_url'] != null) { out.add(v); } else { v.values.forEach(walk); } } }
      walk(r); inv = out;
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _apply(String v, String ok) async {
    setState(() => busy = true);
    try { await rpc('set_my_banner', {'p_url': v}); cur = v; if (mounted) toast(context, ok); }
    catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => busy = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Pilih Banner')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (cur.isNotEmpty) ...[
            ClipRRect(borderRadius: BorderRadius.circular(C.radiusCard), child: Image.network(cur, height: 110, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
            TextButton(onPressed: busy ? null : () => _apply('', 'Banner dihapus'), child: const Text('Hapus banner')),
          ],
          const Text('Custom URL (.gif) — Premium/staf', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          TextField(controller: url, keyboardType: TextInputType.url, decoration: InputDecoration(hintText: 'https://contoh.com/gambar.gif', filled: true, fillColor: C.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none))),
          const SizedBox(height: 8),
          pillButton('Pasang Custom URL', busy ? null : () {
            final v = url.text.trim();
            if (!RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(v)) return toast(context, 'Link harus diawali http:// atau https://');
            if (!RegExp(r'\.gif($|[?#])', caseSensitive: false).hasMatch(v)) return toast(context, 'Link harus berupa gambar .gif');
            _apply(v, 'Banner dipasang');
          }),
          const SizedBox(height: 18),
          Text('Wallpaper gacha (${inv.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: inv.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2),
            itemBuilder: (_, i) {
              final it = inv[i]; final u = '${it['url'] ?? it['image_url']}';
              return GestureDetector(
                onTap: busy ? null : () => _apply(u, 'Banner dipasang'),
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: u == cur ? C.accent : rarityColor['${it['rarity']}'] ?? C.border, width: u == cur ? 2.5 : 1)),
                  child: ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.network(u, fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported))),
                ),
              );
            },
          ),
        ]),
      );
}
