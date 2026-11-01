import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../core/widgets/border_frame.dart';
import '../../services/supabase/supabase_service.dart';
import '../../services/xp/xp_service.dart';
import '../common/ui.dart';
import '../pet/pet_pages.dart';
import '../social/social_pages.dart';

void openProfile(BuildContext c, dynamic uid) {
  if (uid == null) return;
  Navigator.push(c, MaterialPageRoute(builder: (_) => UserProfilePage(uid: '$uid')));
}

/// Profil publik pemain lain (get_public_profile): banner, avatar, #ID, peran, level, XP, komentar, tanggal bergabung.
class UserProfilePage extends StatefulWidget {
  final String uid;
  const UserProfilePage({super.key, required this.uid});
  @override
  State<UserProfilePage> createState() => _S();
}

class _S extends State<UserProfilePage> {
  Map? p; String? err; String? borderUrl, borderId; bool premium = false; int? topLb, topGiver, topLevel;
  bool get mine => widget.uid == db.auth.currentUser?.id;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final r = await rpc('get_public_profile', {'p_uid': widget.uid}); if (r is List && r.isNotEmpty) { if (mounted) setState(() => p = r.first as Map); } else if (mounted) { setState(() => err = 'Profil tidak ditemukan'); } }
    catch (e) { if (mounted) setState(() => err = '$e'.replaceFirst('Exception: ', '')); return; }
    try { final b = await rpc('border_of', {'p_uids': [widget.uid]}) as List; if (b.isNotEmpty && b.first is Map && mounted) setState(() => borderUrl = (b.first as Map)['image_url']?.toString()); } catch (_) {}
    int? rk(dynamic v) => v is num && v >= 1 && v <= 10 ? v.toInt() : null;
    try { final v = rk(await rpc('monthly_top_of', {'p_user': widget.uid})); if (mounted) setState(() => topLb = v); } catch (_) {}
    try { final v = rk(await rpc('monthly_giver_of', {'p_user': widget.uid})); if (mounted) setState(() => topGiver = v); } catch (_) {}
    try { final v = rk(await rpc('top_level_of', {'p_user': widget.uid})); if (mounted) setState(() => topLevel = v); } catch (_) {}
    try { final pr = await rpc('premium_of', {'p_ids': [widget.uid]}) as List; if (mounted) setState(() => premium = pr.map((x) => '$x').contains(widget.uid)); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final u = p;
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: const Text('Profil')),
      body: err != null ? Center(child: Text(err!)) : u == null ? const Center(child: CircularProgressIndicator()) : _body(u),
    );
  }

  Widget _body(Map u) {
    final xp = num.tryParse('${u['xp']}') ?? 0;
    final li = XpService.levelInfo(xp);
    final banner = '${u['banner_url'] ?? ''}';
    final joined = DateTime.tryParse('${u['joined']}');
    return ListView(children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(height: 150, width: double.infinity, child: banner.isNotEmpty
            ? Image.network(banner, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: C.surface))
            : Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A1B5E), Color(0xFF16345C)])))),
        Positioned(left: 20, bottom: -38, child: Container(
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.background, width: 4)),
          child: BorderFrame(id: borderId, imageUrl: borderUrl, size: 84,
              child: CircleAvatar(radius: 42, backgroundColor: C.surface, backgroundImage: u['avatar'] != null ? NetworkImage('${u['avatar']}') : null)),
        )),
      ]),
      const SizedBox(height: 46),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text('${u['name'] ?? 'Pengguna'}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: C.secondary, borderRadius: BorderRadius.circular(12)), child: Text('Lvl. ${li.level}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
        ]),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text('#${u['seq']}', style: const TextStyle(color: C.textDim)),
          if ('${u['role']}' != 'user' && '${u['role']}' != 'null') _badge('${u['role']}'.toUpperCase(), switch ('${u['role']}') { 'developer' => const Color(0xFF7C3AED), 'admin' => C.danger, 'moderator' => const Color(0xFF16A34A), _ => C.secondary }, null),
          if (premium) _badge('PREMIUM', const Color(0xFFB45309), Icons.workspace_premium),
        ]),
        if (topLb != null || topGiver != null || topLevel != null) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: [
          if (topLb != null) RankBadge.lb(topLb!), if (topGiver != null) RankBadge.giver(topGiver!), if (topLevel != null) RankBadge.level(topLevel!),
        ])),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: li.pct, minHeight: 8, color: C.primary, backgroundColor: C.border)),
        const SizedBox(height: 4),
        Text('${fmtNum(li.into)} / ${fmtNum(li.need)} XP ke level berikutnya', style: const TextStyle(color: C.textDim, fontSize: 11)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _stat('Total XP', fmtNum(xp))), const SizedBox(width: 8),
          Expanded(child: _stat('Komentar', fmtNum(num.tryParse('${u['comments']}') ?? 0))), const SizedBox(width: 8),
          Expanded(child: _stat('Bergabung', joined == null ? '-' : '${joined.day}/${joined.month}/${joined.year}')),
        ]),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          if (!mine) pillButton('Tambah Teman', () async { try { final r = await rpc('friend_request', {'p_target': widget.uid}); if (mounted) toast(context, '$r'); } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); } }),
          if (!mine) pillButton('Pesan', () => Navigator.push(context, MaterialPageRoute(builder: (_) => DirectChatPage(peerId: widget.uid, peerName: '${u['name']}'))), color: C.pillBlue),
          pillButton('Lihat Pet', () => Navigator.push(context, MaterialPageRoute(builder: (_) => PetVisitPage(uid: widget.uid, name: '${u['name']}'))), color: C.accent),
        ]),
      ])),
    ]);
  }

  Widget _badge(String t, Color c, IconData? ic) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (ic != null) Icon(ic, size: 12, color: C.accent), if (ic != null) const SizedBox(width: 3), Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))]),
      );

  Widget _stat(String a, String b) => card(margin: EdgeInsets.zero, child: Column(children: [Text(b, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 2), Text(a, style: const TextStyle(color: C.textDim, fontSize: 11))]));
}
