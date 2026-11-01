import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/env.dart';
import '../../services/supabase/supabase_service.dart';

int cmpVer(String a, String b) {
  final x = a.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
  final y = b.split('.').map((e) => int.tryParse(e.replaceAll(RegExp(r'\D'), '')) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

Future<void> _open(String? url) async {
  final u = Uri.tryParse(url ?? '');
  if (u != null && (u.scheme == 'https' || u.scheme == 'http')) await launchUrl(u, mode: LaunchMode.externalApplication);
}

/// Pengumuman awal sesi: update aplikasi (get_app_update; versi lebih baru, bisa dipaksa) lalu banner aktif (get_active_banner).
class ActiveBanner {
  static bool _shown = false;
  static Future<void> show(BuildContext context) async {
    if (_shown) return;
    _shown = true;
    try {
      final r = await rpc('get_app_update');
      final row = r is List ? (r.isEmpty ? null : r.first as Map) : r as Map?;
      if (row != null && cmpVer('${row['latest_version']}', appVersion) > 0 && context.mounted) {
        final force = row['force_update'] == true;
        await showDialog(context: context, barrierDismissible: !force, builder: (c) => PopScope(canPop: !force, child: AlertDialog(
          title: Text('Update ${row['latest_version']} tersedia'),
          content: Text('${row['message'] ?? 'Versi baru WakuPlay sudah tersedia.'}\n\nVersi kamu: $appVersion'),
          actions: [
            if (!force) TextButton(onPressed: () => Navigator.pop(c), child: const Text('Nanti')),
            TextButton(onPressed: () => _open('${row['download_url']}'), child: const Text('Unduh')),
          ],
        )));
      }
    } catch (_) {}
    try {
      final r = await rpc('get_active_banner') as List;
      if (r.isEmpty || !context.mounted) return;
      final b = r.first as Map;
      await showDialog(context: context, builder: (c) => AlertDialog(
        title: Text('${b['title']}'), content: Text('${b['body']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
          if (b['button_enabled'] == true) TextButton(onPressed: () { _open('${b['button_url']}'); Navigator.pop(c); }, child: Text('${b['button_text'] ?? 'Buka'}')),
        ],
      ));
    } catch (_) {}
  }
}
