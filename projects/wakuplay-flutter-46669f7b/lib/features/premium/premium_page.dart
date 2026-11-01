import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/colors.dart';
import '../../core/util.dart';
import '../../services/supabase/supabase_service.dart';
import '../common/ui.dart';

/// Memanggil Edge Function `premium` lama (create / pay_info / save_url / save_qr / check / cancel).
/// Server yang mengaktifkan Premium lewat webhook; klien tidak pernah menandai dirinya Premium.
class PremiumApi {
  static Future<Map> _call(String action, Map<String, dynamic> p) async {
    final r = await db.functions.invoke('premium', body: {'action': action, ...p});
    final d = r.data;
    if (d is! Map || d['ok'] != true) throw Exception(d is Map ? '${d['error'] ?? 'Gagal'}' : 'Gagal');
    return d['order'] as Map;
  }
  static Future<Map> create(String plan) => _call('create', {'plan_id': plan});
  static Future<Map> payInfo(String id) => _call('pay_info', {'order_id': id});
  static Future<Map> check(String id) => _call('check', {'order_id': id});
  static Future<Map> cancel(String id) => _call('cancel', {'order_id': id});
  static Future<Map> saveUrl(String id, String url) => _call('save_url', {'order_id': id, 'url': url});
  static Future<Map> saveQr(String id, String qr) => _call('save_qr', {'order_id': id, 'qr': qr});
}

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});
  @override
  State<PremiumPage> createState() => _S();
}

class _S extends State<PremiumPage> {
  late Future<List<dynamic>> f = _load();
  bool busy = false;

  Future<List<dynamic>> _load() => Future.wait([rpc('premium_overview'), rpc('premium_orders_me', {'p_limit': 20})]);

  Future<void> _buy(Map plan) async {
    setState(() => busy = true);
    try {
      final o = await PremiumApi.create('${plan['id']}');
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => PayFlowPage(order: o)));
    } catch (e) { if (mounted) toast(context, '$e'.replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() { busy = false; f = _load(); }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: C.background, title: const Text('Premium')),
        body: FutureBuilder<List<dynamic>>(
          future: f,
          builder: (_, s) {
            if (s.hasError) return Center(child: Text('${s.error}'));
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final ov = s.data![0] as Map; final orders = s.data![1] as List;
            return ListView(padding: const EdgeInsets.all(16), children: [
              if ('${ov['benefits']}'.isNotEmpty) card(child: Text('${ov['benefits']}')),
              for (final p in (ov['plans'] as List? ?? const []))
                card(child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${p['days']} hari', style: const TextStyle(color: C.textDim, fontSize: 12)),
                  ])),
                  Text('Rp ${fmtNum(num.tryParse('${p['price']}') ?? 0)}', style: const TextStyle(color: C.accent, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  pillButton('Beli', busy ? null : () => _buy(p as Map)),
                ])),
              const SizedBox(height: 8),
              const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w800)),
              for (final o in orders)
                ListTile(
                  title: Text('${o['plan_name']}'), subtitle: Text('${o['status']}'), trailing: Text('Rp ${fmtNum(num.tryParse('${o['total_payment']}') ?? 0)}'),
                  onTap: o['status'] == 'pending'
                      ? () async { try { final x = await PremiumApi.payInfo('${o['order_id']}'); if (!mounted) return; await Navigator.push(context, MaterialPageRoute(builder: (_) => PayFlowPage(order: x))); setState(() => f = _load()); } catch (e) { if (mounted) toast(context, '$e'); } }
                      : null,
                ),
            ]);
          },
        ),
      );
}

/// Alur bayar: halaman Sociabuzz (isi otomatis lewat wp-pay-fill.js) -> QRIS ditangkap -> tampil di app -> cek status berkala.
class PayFlowPage extends StatefulWidget {
  final Map order;
  const PayFlowPage({super.key, required this.order});
  @override
  State<PayFlowPage> createState() => _P();
}

class _P extends State<PayFlowPage> {
  late Map o = widget.order;
  String phase = 'init'; // init | web | wait | done | bad
  String? msg; WebViewController? web; Timer? poll; String lastUrl = ''; double progress = 0;

  String get id => '${o['order_id']}';
  static bool _isSocia(String u) {
    final x = Uri.tryParse(u);
    return x != null && x.scheme == 'https' && x.host != '' && (x.host == 'sociabuzz.com' || x.host.endsWith('.sociabuzz.com'));
  }

  @override
  void initState() {
    super.initState();
    if (o['status'] == 'completed' && o['activated'] == true) { phase = 'done'; }
    else if (o['pay_qr'] != null) { _wait(); }
    else { _openWeb(); }
  }

  @override
  void dispose() { poll?.cancel(); super.dispose(); }

  void _wait() {
    setState(() => phase = 'wait');
    poll?.cancel();
    poll = Timer.periodic(const Duration(seconds: 6), (_) => _check(silent: true));
  }

  Future<void> _check({bool silent = false}) async {
    try {
      final r = await PremiumApi.check(id);
      if (!mounted) return;
      setState(() => o = {...o, ...r});
      if (r['status'] == 'completed' && r['activated'] == true) { poll?.cancel(); setState(() => phase = 'done'); }
      else if (r['status'] == 'expired' || r['status'] == 'canceled' || r['status'] == 'failed') { poll?.cancel(); setState(() => phase = 'bad'); }
      else if (!silent) { setState(() => msg = 'Pembayaran belum terbaca. Jika sudah bayar, jangan bayar lagi: Premium masuk otomatis.'); }
    } catch (e) { if (!silent && mounted) setState(() => msg = '$e'.replaceFirst('Exception: ', '')); }
  }

  Future<void> _openWeb() async {
    final fill = (o['fill'] as Map?) ?? const {};
    final url = '${o['pay_url'] ?? fill['page'] ?? ''}';
    if (!_isSocia(url)) { setState(() { phase = 'bad'; msg = 'Alamat pembayaran tidak valid'; }); return; }
    final basePath = Uri.parse('${fill['page'] ?? url}').path;
    final script = await rootBundle.loadString('assets/wp-pay-fill.js');
    final auto = o['pay_url'] == null;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel('WPPayCh', onMessageReceived: (m) async {
        final src = m.message;
        if (src.length > 400000 || !(src.startsWith('data:image/') || src.startsWith('https://'))) return;
        try { final r = await PremiumApi.saveQr(id, src); if (!mounted) return; setState(() => o = {...o, ...r, 'pay_qr': src}); _wait(); } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) => setState(() => progress = p / 100),
        onNavigationRequest: (r) => r.url.startsWith('https://') ? NavigationDecision.navigate : NavigationDecision.prevent,
        onPageFinished: (u) async {
          _report(u, basePath);
          if (!_isSocia(u)) return;
          await web?.runJavaScript('window.WPPay={qr:function(s){WPPayCh.postMessage(String(s))}};window.__WPAUTO=$auto;window.__WPFILL=${jsonEncode(fill)};$script');
        },
        onUrlChange: (ch) { if (ch.url != null) _report(ch.url!, basePath); },
      ))
      ..loadRequest(Uri.parse(url));
    setState(() { web = c; phase = 'web'; });
  }

  void _report(String u, String basePath) {
    if (!_isSocia(u)) return;
    final x = Uri.parse(u); final clean = x.replace(fragment: '').toString();
    if (x.path == basePath || x.path == '$basePath/' || clean == lastUrl) return;
    lastUrl = clean;
    PremiumApi.saveUrl(id, clean).catchError((_) => <dynamic, dynamic>{});
  }

  Future<void> _cancel() async { try { await PremiumApi.cancel(id); } catch (_) {} if (mounted) Navigator.pop(context); }

  @override
  Widget build(BuildContext context) {
    final qr = o['pay_qr']?.toString();
    return Scaffold(
      appBar: AppBar(backgroundColor: C.background, title: Text('Premium · ${o['plan_name'] ?? ''}')),
      body: switch (phase) {
        'web' => Column(children: [
            if (progress < 1) LinearProgressIndicator(value: progress, minHeight: 3),
            Expanded(child: WebViewWidget(controller: web!)),
          ]),
        'wait' => ListView(padding: const EdgeInsets.all(20), children: [
            const Text('Scan QRIS untuk membayar', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (qr != null) Container(color: Colors.white, padding: const EdgeInsets.all(12),
                child: qr.startsWith('data:image/') ? Image.memory(base64Decode(qr.split(',').last), height: 280) : Image.network(qr, height: 280)),
            const SizedBox(height: 10),
            Text('Total: Rp ${fmtNum(num.tryParse('${o['amount']}') ?? 0)}', textAlign: TextAlign.center),
            if (msg != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(msg!, textAlign: TextAlign.center, style: const TextStyle(color: C.accent, fontSize: 12))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              pillButton('Saya sudah bayar', () => _check()), const SizedBox(width: 10),
              pillButton('Batalkan', _cancel, color: C.danger),
            ]),
          ]),
        'done' => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.workspace_premium, size: 80, color: C.accent), const SizedBox(height: 12),
            const Text('Premium aktif!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), const SizedBox(height: 16),
            pillButton('Selesai', () => Navigator.pop(context)),
          ])),
        'bad' => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(o['status'] == 'expired' ? 'Pembayaran kedaluwarsa' : o['status'] == 'canceled' ? 'Pesanan dibatalkan' : (msg ?? 'Pembayaran gagal'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('Jika kamu sudah terlanjur membayar, jangan bayar lagi: Premium tetap masuk otomatis.', textAlign: TextAlign.center, style: TextStyle(color: C.textDim)),
            const SizedBox(height: 16), pillButton('Kembali', () => Navigator.pop(context)),
          ]))),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}
