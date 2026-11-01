import 'package:flutter/material.dart';
import '../../core/prefs.dart';
import '../../core/theme/colors.dart';
import '../../services/notify/push_service.dart';
import '../diagnose/diagnose_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _S();
}

class _S extends State<SettingsPage> {
  Widget _sw(String label, String key, bool def) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
        child: SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: Prefs.getB(key, def),
            onChanged: (v) async { await Prefs.setB(key, v); setState(() {}); }),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Setting Aplikasi')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Kualitas', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final q in const ['360p', '480p', '720p', '1080p'])
              ChoiceChip(label: Text(q), selected: Prefs.quality == q, onSelected: (_) async { await Prefs.setQuality(q); setState(() {}); }),
          ]),
          const SizedBox(height: 16),
          _sw('Tampilkan EXP Popup', 'expPopup', true),
          _sw('Skip Intro', 'skipIntro', true),
          _sw('Auto Next', 'autoNext', true),
          const SizedBox(height: 8),
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.bug_report, color: C.primary), title: const Text('Diagnosa Sumber Anime'), trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DiagnosePage()))),
          const SizedBox(height: 8),
          const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(C.radiusCard)),
            child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Notifikasi aktif'), value: Prefs.getB('notifAll', true),
                onChanged: (v) async { await Prefs.setB('notifAll', v); await PushService.syncPrefs(); setState(() {}); }),
          ),
          const Text('Kecepatan cek saat aplikasi ditutup', style: TextStyle(color: C.textDim, fontSize: 12)),
          Wrap(spacing: 8, children: [
            for (final s in const [['cepat', 'Cepat (5 dtk, boros baterai)'], ['normal', 'Normal (30 dtk)'], ['hemat', 'Hemat (~5 menit)']])
              ChoiceChip(label: Text(s[1], style: const TextStyle(fontSize: 12)), selected: Prefs.notifSpeed == s[0],
                  onSelected: (_) async { await Prefs.setNotifSpeed(s[0]); await PushService.setSpeed(); setState(() {}); }),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            TextButton(onPressed: PushService.openNotif, child: const Text('Izin notifikasi')),
            TextButton(onPressed: PushService.openBattery, child: const Text('Abaikan optimasi baterai')),
          ]),
        ]),
      );
}
