import 'package:flutter/services.dart';

/// Jembatan ke MainActivity.kt (channel "wakuplay/native").
class NativeBridge {
  static const _ch = MethodChannel('wakuplay/native');
  static Future<void> setPipAllowed(bool on) => _ch.invokeMethod('setPipAllowed', {'enabled': on});
  static Future<void> setLandscape(bool on) => _ch.invokeMethod('setLandscape', {'enabled': on});
  static Future<void> setImmersive(bool on) => _ch.invokeMethod('setImmersive', {'enabled': on});
}
