import 'dart:async';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/native_bridge.dart';
import '../../core/prefs.dart';
import '../../core/providers.dart';
import '../../core/theme/colors.dart';
import '../../models/anime.dart';
import '../../models/episode.dart';
import '../../services/anime/sanka_api.dart';
import '../../services/supabase/supabase_service.dart';
import '../../services/xp/xp_service.dart';
import '../comments/comments_section.dart';
import '../detail/detail_page.dart' show RawJsonPage;

class PlayerPage extends ConsumerStatefulWidget {
  final Anime anime; final Episode episode; final List<Episode> episodes;
  const PlayerPage({super.key, required this.anime, required this.episode, required this.episodes});
  @override
  ConsumerState<PlayerPage> createState() => _S();
}

class _S extends ConsumerState<PlayerPage> {
  VideoPlayerController? _vc;
  ChewieController? _cc;
  WebViewController? _web;
  List<StreamSource> _src = [];
  dynamic _raw;
  int _q = 0;
  String? _err, _xpToken;
  Timer? _save, _xp;
  bool _advancing = false, _skipped = false;
  late Episode _ep = widget.episode;
  Anime get a => widget.anime;

  @override
  void initState() {
    super.initState();
    NativeBridge.setPipAllowed(true);
    _load();
  }

  int _qn(StreamSource s) => int.tryParse(s.quality.replaceAll(RegExp(r'\D'), '')) ?? 0;

  Future<void> _disposeMedia() async {
    final oldC = _cc, oldV = _vc;
    _cc = null; _vc = null; _web = null;
    oldC?.dispose(); await oldV?.dispose();
  }

  Future<void> _load() async {
    _advancing = false; _skipped = false; _xp?.cancel(); _xpToken = null;
    setState(() => _err = null);
    await _disposeMedia();
    if (mounted) setState(() {});
    try {
      if (a.source == 'legacy') {
        _src = await ref.read(legacyApiProvider).streams(_ep.id);
      } else {
        final r = await SankaApi.streams(a.source, _ep);
        _src = r.streams; _raw = r.raw;
      }
      if (_src.isEmpty) throw Exception('Tidak ada link stream untuk episode ini');
      // pilih: direct sesuai kualitas Settings, kalau tidak ada pakai embed pertama
      final want = int.tryParse(Prefs.quality.replaceAll(RegExp(r'\D'), '')) ?? 720;
      final directs = [for (var i = 0; i < _src.length; i++) if (_src[i].isDirect) i];
      var idx = directs.firstWhere((i) => _qn(_src[i]) <= want && _qn(_src[i]) > 0, orElse: () => directs.isNotEmpty ? directs.first : 0);
      await _open(idx, keepPos: false);
      try { rpc('add_view', {'p_anime': a.storeId, 'p_episode': a.epKey(_ep.id)}); } catch (_) {}
    } catch (e) {
      if (mounted) setState(() => _err = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _open(int i, {bool keepPos = true}) async {
    final pos = keepPos ? (_vc?.value.position ?? Duration.zero) : Duration.zero;
    await _disposeMedia();
    _save?.cancel(); _xp?.cancel();
    _q = i;
    final s = _src[i];
    if (s.isEmbed) { _openEmbed(s); return; }
    final vc = VideoPlayerController.networkUrl(Uri.parse(s.url));
    await vc.initialize();
    if (pos > Duration.zero) await vc.seekTo(pos);
    await vc.play();
    vc.addListener(() {
      final v = vc.value;
      if (Prefs.autoNext && !_advancing && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(seconds: 1)) { _advancing = true; _next(); }
    });
    _save = Timer.periodic(const Duration(seconds: 15), (_) => _saveProgress());
    _startXp(vc);
    if (!mounted) { await vc.dispose(); return; }
    setState(() {
      _vc = vc;
      _cc = ChewieController(videoPlayerController: vc, autoPlay: true, allowFullScreen: true, allowPlaybackSpeedChanging: true,
          playbackSpeeds: const [0.5, 1, 1.25, 1.5, 2], materialProgressColors: ChewieProgressColors(playedColor: C.primary));
    });
  }

  /// Embed (iframe) dibuka di WebView. Navigasi frame utama ke domain lain diblokir (anti pop-up/redirect iklan).
  void _openEmbed(StreamSource s) {
    final host = Uri.parse(s.url).host;
    final c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
        if (!r.url.startsWith('https://') && !r.url.startsWith('http://')) return NavigationDecision.prevent;
        if (!r.isMainFrame) return NavigationDecision.navigate;
        final h = Uri.tryParse(r.url)?.host ?? '';
        return (h == host || h.endsWith('.$host') || host.endsWith('.$h')) ? NavigationDecision.navigate : NavigationDecision.prevent;
      }))
      ..loadRequest(Uri.parse(s.url));
    // riwayat tetap dicatat (tanpa posisi) agar episode ditandai sudah dibuka
    ref.read(libraryRepoProvider).saveProgress(anime: a, episodeId: a.epKey(_ep.id), episodeNumber: _ep.number, progress: 0, duration: 0).catchError((_) {});
    if (mounted) setState(() => _web = c);
  }

  Future<void> _startXp(VideoPlayerController vc) async {
    try {
      final t = await rpc('xp_start', {'p_anime': a.storeId, 'p_ep': a.epKey(_ep.id), 'p_duration': vc.value.duration.inSeconds, 'p_pos': vc.value.position.inSeconds});
      _xpToken = t?.toString();
    } catch (_) { return; }
    var watched = 0; // seperti xp.js: detak dikirim setelah 2 menit PENUH memutar
    _xp = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_xpToken == null || !vc.value.isPlaying) return;
      watched += 5;
      if (watched < 120) return;
      watched -= 120;
      try {
        final r = await rpc('xp_beat', {'p_token': _xpToken, 'p_pos': vc.value.position.inSeconds});
        final n = num.tryParse('$r');
        if (n != null) XpService.onTotal(n);
      } catch (_) { _xpToken = null; }
    });
  }

  Future<void> _saveProgress() async {
    final v = _vc?.value;
    if (v == null || !v.isInitialized) return;
    try { await ref.read(libraryRepoProvider).saveProgress(anime: a, episodeId: a.epKey(_ep.id), episodeNumber: _ep.number, progress: v.position.inSeconds, duration: v.duration.inSeconds); } catch (_) {}
  }

  void _next() {
    final i = widget.episodes.indexWhere((e) => e.id == _ep.id);
    if (i >= 0 && i + 1 < widget.episodes.length) { _saveProgress(); _ep = widget.episodes[i + 1]; _load(); }
  }

  void _pick(Episode e) { _saveProgress(); _ep = e; _load(); }

  @override
  void dispose() {
    _saveProgress();
    _save?.cancel(); _xp?.cancel();
    NativeBridge.setPipAllowed(false);
    _cc?.dispose(); _vc?.dispose();
    super.dispose();
  }

  Widget _skipButton() => ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _vc!,
        builder: (_, v, __) {
          final show = Prefs.skipIntro && !_skipped && v.isInitialized && v.duration.inSeconds > 600 && v.position.inSeconds < 220;
          if (!show) return const SizedBox();
          return Positioned(right: 12, bottom: 48, child: GestureDetector(
            onTap: () { final t = v.position + const Duration(seconds: 85); _vc!.seekTo(t < v.duration ? t : v.duration - const Duration(seconds: 1)); setState(() => _skipped = true); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.border)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.forward_10, size: 18), SizedBox(width: 6), Text('Skip Intro', style: TextStyle(fontWeight: FontWeight.w700))])),
          ));
        },
      );

  Widget _screen() {
    if (_err != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_err!, textAlign: TextAlign.center, style: const TextStyle(color: C.danger)),
        if (_raw != null) TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RawJsonPage('Respons episode ${a.source}', _raw))), child: const Text('Lihat respons mentah')),
      ])));
    }
    if (_web != null) return WebViewWidget(controller: _web!);
    if (_cc != null) return Stack(children: [Chewie(controller: _cc!), _skipButton()]);
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(backgroundColor: C.background, title: Text('${a.title} • Eps ${_ep.number}', style: const TextStyle(fontSize: 15)), actions: [
            if (_src.length > 1)
              PopupMenuButton<int>(icon: const Icon(Icons.dns), tooltip: 'Server / kualitas', onSelected: (i) => _open(i),
                  itemBuilder: (_) => [for (var i = 0; i < _src.length; i++) PopupMenuItem(value: i, child: Text('${_src[i].isDirect ? '▶ ' : '🌐 '}${_src[i].label}${i == _q ? '  ✓' : ''}'))]),
          ]),
          body: Column(children: [
            AspectRatio(aspectRatio: 16 / 9, child: _screen()),
            const TabBar(tabs: [Tab(text: 'Episode'), Tab(text: 'Komentar')]),
            Expanded(child: TabBarView(children: [
              ListView(children: [for (final e in widget.episodes) ListTile(selected: e.id == _ep.id, title: Text(e.title != null && a.source != 'legacy' ? e.title! : 'Episode ${e.number}', maxLines: 1, overflow: TextOverflow.ellipsis), onTap: () => _pick(e))]),
              CommentsSection(anime: a, episodeId: a.epKey(_ep.id)),
            ])),
          ]),
        ),
      );
}
