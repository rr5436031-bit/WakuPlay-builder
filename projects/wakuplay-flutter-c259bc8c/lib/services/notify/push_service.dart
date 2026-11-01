import 'package:flutter/services.dart';
import '../../core/config/env.dart';
import '../../core/prefs.dart';
import '../supabase/supabase_service.dart';

/// Notifikasi latar belakang tanpa Firebase: perangkat didaftarkan lewat RPC lama `notif_device_register`,
/// lalu layanan Kotlin/Java (PollService) memanggil `notif_poll` berkala. Rahasia perangkat disimpan di SharedPreferences app.
class PushService {
  static const _ch = MethodChannel('wakuplay/native');
  static const speeds = {'cepat': 5000, 'normal': 30000, 'hemat': 300000};
  static int get _interval => speeds[Prefs.notifSpeed] ?? 30000;
  static Map<String, bool> _prefs() {
    final on = Prefs.getB('notifAll', true);
    return {'friend': on, 'dm': on, 'episode': on, 'mention': on, 'reply': on, 'clan': on, 'anime': on};
  }

  static Future<void> ensure() async {
    try {
      final uid = db.auth.currentUser?.id;
      if (uid == null) return;
      final st = Map<String, dynamic>.from(await _ch.invokeMethod('notifStatus') as Map);
      if (st['configured'] == true && st['uid'] == uid && '${st['device']}'.isNotEmpty) {
        await _ch.invokeMethod('notifSetSpeed', {'interval': _interval});
        return;
      }
      final r = await rpc('notif_device_register', {'p_prefs': _prefs()}) as Map;
      if (r['device_id'] == null || r['secret'] == null) return;
      await _ch.invokeMethod('notifConfigure', {
        'url': Env.supabaseUrl, 'key': Env.supabaseAnonKey, 'device': '${r['device_id']}',
        'secret': '${r['secret']}', 'since': '${r['since'] ?? ''}', 'uid': uid, 'interval': _interval,
      });
    } catch (_) {}
  }

  static Future<void> syncPrefs() async {
    try {
      final st = Map<String, dynamic>.from(await _ch.invokeMethod('notifStatus') as Map);
      if ('${st['device']}'.isNotEmpty) await rpc('notif_device_set_prefs', {'p_device': st['device'], 'p_prefs': _prefs()});
    } catch (_) {}
  }

  static Future<void> setSpeed() async { try { await _ch.invokeMethod('notifSetSpeed', {'interval': _interval}); } catch (_) {} }

  /// Dipanggil sebelum logout: cabut perangkat di server lalu bersihkan pengaturan native.
  static Future<void> clear() async {
    try {
      final st = Map<String, dynamic>.from(await _ch.invokeMethod('notifStatus') as Map);
      if ('${st['device']}'.isNotEmpty) await rpc('notif_device_revoke', {'p_device': st['device']});
    } catch (_) {}
    try { await _ch.invokeMethod('notifClear'); } catch (_) {}
  }

  static Future<Map<String, dynamic>> status() async {
    try { return Map<String, dynamic>.from(await _ch.invokeMethod('notifStatus') as Map); } catch (_) { return {}; }
  }
  static Future<void> openBattery() => _ch.invokeMethod('openBatterySettings');
  static Future<void> openNotif() => _ch.invokeMethod('openNotifSettings');
}
