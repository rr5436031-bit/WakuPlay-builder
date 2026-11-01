import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../features/clan/clan_page.dart';
import '../../features/detail/detail_page.dart';
import '../../features/notifications/notifications_page.dart';
import '../../features/social/social_pages.dart';
import '../../models/anime.dart';

final navKey = GlobalKey<NavigatorState>();

/// Ketukan notifikasi sistem -> buka halaman tujuan (dm, teman, episode, balasan/mention, permintaan clan).
class NotifRouter {
  static const _ch = MethodChannel('wakuplay/native');
  static bool _ready = false;

  static void init() {
    if (_ready) return;
    _ready = true;
    _ch.setMethodCallHandler((c) async { if (c.method == 'notifTap') _go(Map<String, dynamic>.from(c.arguments as Map)); });
    Future.delayed(const Duration(milliseconds: 600), () async {
      try { final t = await _ch.invokeMethod('takeLaunchNotif'); if (t is Map) _go(Map<String, dynamic>.from(t)); } catch (_) {}
    });
  }

  static void _go(Map<String, dynamic> t) {
    final nav = navKey.currentState; if (nav == null) return;
    Map d = {};
    try { d = jsonDecode('${t['data'] ?? '{}'}') as Map; } catch (_) {}
    Widget? w;
    switch ('${t['type']}') {
      case 'dm': w = d['from'] != null ? DirectChatPage(peerId: '${d['from']}', peerName: '${t['title'] ?? 'Pesan'}') : const FriendsPage();
      case 'friend_request': case 'friend_accept': w = const FriendsPage();
      case 'episode': case 'new_anime': if (d['anime_id'] != null) { w = DetailPage(anime: Anime.fromStoreId('${d['anime_id']}', title: '${t['title'] ?? ''}', poster: d['poster']?.toString())); }
      case 'clan_request': w = const ClanPage();
      default: w = const NotificationsPage();
    }
    if (w != null) nav.push(MaterialPageRoute(builder: (_) => w!));
  }
}
