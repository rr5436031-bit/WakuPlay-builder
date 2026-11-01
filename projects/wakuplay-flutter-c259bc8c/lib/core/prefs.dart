import 'package:shared_preferences/shared_preferences.dart';

/// Pengaturan lokal (setara lib/settings.js). Nilai hanya preferensi tampilan; tidak menyentuh data akun.
class Prefs {
  static late SharedPreferences _p;
  static Future<void> init() async => _p = await SharedPreferences.getInstance();
  static bool getB(String k, bool d) => _p.getBool(k) ?? d;
  static Future<void> setB(String k, bool v) => _p.setBool(k, v);
  static String get quality => _p.getString('quality') ?? '720p';
  static Future<void> setQuality(String v) => _p.setString('quality', v);
  static String get notifSpeed => _p.getString('notifSpeed') ?? 'normal';
  static Future<void> setNotifSpeed(String v) => _p.setString('notifSpeed', v);
  static bool get skipIntro => getB('skipIntro', true);
  static bool get autoNext => getB('autoNext', true);
}
