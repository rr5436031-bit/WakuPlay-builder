package com.wibuplay.app.ui

import android.annotation.SuppressLint
import android.content.res.Configuration
import android.net.Uri
import android.os.SystemClock
import android.view.View
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.compose.BackHandler
import androidx.annotation.OptIn
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.media3.common.C as MediaC
import androidx.media3.common.MediaItem
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import com.wibuplay.app.AppVM
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.Sources
import com.wibuplay.app.data.StreamLink
import com.wibuplay.app.data.userMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

class PlayerHolder {
    var player: ExoPlayer? = null
    var lastPos: Long = 0
    var lastDur: Long = 0
}

class FullScreenReq(val view: View, val cb: WebChromeClient.CustomViewCallback)

@OptIn(UnstableApi::class)
@Composable
fun PlayerScreen(vm: AppVM, onBack: () -> Unit) {
    val ps = vm.player
    if (ps == null || ps.detail.episodes.isEmpty()) {
        ErrorBox("Tidak ada episode yang dipilih") { onBack() }
        return
    }
    val detail = ps.detail
    val src = Sources.byId(detail.source)
    var index by remember { mutableIntStateOf(ps.index.coerceIn(0, detail.episodes.size - 1)) }
    val ep = detail.episodes[index]
    val hist by vm.history.collectAsState()
    val land = LocalConfiguration.current.orientation == Configuration.ORIENTATION_LANDSCAPE

    var links by remember(index) { mutableStateOf<List<StreamLink>>(emptyList()) }
    var loading by remember(index) { mutableStateOf(true) }
    var error by remember(index) { mutableStateOf<String?>(null) }
    var selected by remember(index) { mutableIntStateOf(0) }
    var resolved by remember(index, selected) { mutableStateOf<StreamLink?>(null) }
    var full by remember { mutableStateOf<FullScreenReq?>(null) }
    val holder = remember(index) { PlayerHolder() }
    val tick = remember(index) { longArrayOf(SystemClock.elapsedRealtime()) }

    // Muat daftar stream untuk episode ini
    LaunchedEffect(index) {
        loading = true
        error = null
        try {
            val l = Graph.anime.streams(src, ep)
            links = l
            selected = 0
            if (l.isEmpty()) error = "Tidak ada tautan streaming pada respons API untuk episode ini."
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = e.userMessage()
        }
        loading = false
    }

    // Selesaikan tautan "lazy" (mis. server Winbu) menjadi URL embed
    LaunchedEffect(index, selected, links) {
        resolved = null
        val l = links.getOrNull(selected) ?: return@LaunchedEffect
        if (l.lazy == null) {
            resolved = l
        } else {
            try {
                resolved = Graph.anime.resolve(src, l).firstOrNull()
                if (resolved == null) error = "Server ini tidak mengembalikan tautan."
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = e.userMessage()
            }
        }
    }

    val isEmbed by rememberUpdatedState(resolved?.direct == false)

    // Heartbeat progres ke server tiap 30 dtk. XP dihitung & divalidasi server (maks. sebatas waktu nyata).
    LaunchedEffect(index) {
        vm.reportProgress(detail, ep, 0, 0, 0)
        while (isActive) {
            delay(30_000)
            val now = SystemClock.elapsedRealtime()
            val delta = ((now - tick[0]) / 1000).toInt()
            tick[0] = now
            val p = holder.player
            val playing = if (p != null) p.isPlaying else isEmbed
            if (p != null) {
                holder.lastPos = p.currentPosition / 1000
                holder.lastDur = if (p.duration > 0) p.duration / 1000 else 0
            }
            vm.reportProgress(detail, ep, holder.lastPos, holder.lastDur, if (playing) delta.coerceAtMost(40) else 0)
        }
    }
    DisposableEffect(index) {
        onDispose {
            val delta = ((SystemClock.elapsedRealtime() - tick[0]) / 1000).toInt()
            vm.reportProgress(detail, ep, holder.lastPos, holder.lastDur, delta.coerceIn(0, 40))
            Graph.appScope.launch { vm.refreshHistory() }
        }
    }

    BackHandler(enabled = full != null) {
        full?.cb?.onCustomViewHidden()
        full = null
    }

    val startSec = hist.firstOrNull { it.episodeId == "${detail.key}#${ep.id}" }?.let {
        if (it.duration > 0 && it.lastPosition > it.duration - 15) 0L else it.lastPosition
    } ?: 0L

    @Composable
    fun PlayerArea(mod: Modifier) {
        Box(mod.background(Color.Black), contentAlignment = Alignment.Center) {
            val cur = resolved
            when {
                loading -> LoadingBox()
                cur != null && cur.direct -> ExoView(cur.url, startSec * 1000, holder, Modifier.fillMaxSize())
                cur != null -> EmbedView(cur.url, Modifier.fillMaxSize()) { full = it }
                error != null -> Text(error ?: "", color = Color.White, textAlign = TextAlign.Center, modifier = Modifier.padding(20.dp))
                else -> LoadingBox()
            }
        }
    }

    Box(Modifier.fillMaxSize().background(C.Bg)) {
        if (land) {
            PlayerArea(Modifier.fillMaxSize())
        } else {
            Column(Modifier.fillMaxSize().statusBarsPadding()) {
                PlayerArea(Modifier.fillMaxWidth().aspectRatio(16f / 9f))
                Text(
                    detail.title, color = C.TextHi, fontSize = 18.sp, fontWeight = FontWeight.Bold,
                    maxLines = 2, modifier = Modifier.padding(start = 16.dp, end = 16.dp, top = 12.dp),
                )
                Text(ep.title, color = C.TextLo, fontSize = 14.sp, modifier = Modifier.padding(horizontal = 16.dp, vertical = 2.dp))

                if (links.size > 1) {
                    Text("Server", color = C.TextLo, fontSize = 12.sp, modifier = Modifier.padding(start = 16.dp, top = 12.dp, bottom = 4.dp))
                    LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        itemsIndexed(links) { i, l -> Pill(l.label.ifBlank { "Server ${i + 1}" }, i == selected) { selected = i; error = null } }
                    }
                }

                Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Button(
                        onClick = { index -= 1 }, enabled = index > 0, modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = C.SurfaceHi),
                    ) { Text("‹ Sebelumnya") }
                    Button(
                        onClick = { index += 1 }, enabled = index < detail.episodes.size - 1, modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = C.Accent),
                    ) { Text("Berikutnya ›") }
                }
                Text("Episode", color = C.TextLo, fontSize = 12.sp, modifier = Modifier.padding(start = 16.dp, bottom = 4.dp))
                LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    itemsIndexed(detail.episodes) { i, e ->
                        Pill(e.number ?: "${i + 1}", i == index) { index = i }
                    }
                }
                Spacer(Modifier.height(10.dp))
                Text(
                    "XP bertambah dari waktu menonton yang tercatat server. Progres disimpan otomatis.",
                    color = C.TextLo, fontSize = 11.sp, modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
        }

        full?.let { f ->
            Box(Modifier.fillMaxSize().background(Color.Black)) {
                AndroidView(factory = { f.view }, modifier = Modifier.fillMaxSize())
            }
        }
    }
}

@OptIn(UnstableApi::class)
@Composable
fun ExoView(url: String, startMs: Long, holder: PlayerHolder, modifier: Modifier) {
    val ctx = LocalContext.current
    val exo = remember(url) {
        ExoPlayer.Builder(ctx).build().apply {
            setMediaItem(MediaItem.fromUri(url))
            prepare()
            if (startMs > 0) seekTo(startMs)
            playWhenReady = true
        }
    }
    DisposableEffect(exo) {
        holder.player = exo
        onDispose {
            holder.lastPos = exo.currentPosition / 1000
            holder.lastDur = if (exo.duration != MediaC.TIME_UNSET && exo.duration > 0) exo.duration / 1000 else 0
            holder.player = null
            exo.release()
        }
    }
    AndroidView(
        factory = { c ->
            val pv = PlayerView(c)
            pv.player = exo
            pv.useController = true
            pv
        },
        modifier = modifier,
    )
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
fun EmbedView(url: String, modifier: Modifier, onFullscreen: (FullScreenReq?) -> Unit) {
    val host = remember(url) { Uri.parse(url).host.orEmpty() }
    val ref = remember(url) { arrayOfNulls<WebView>(1) }
    DisposableEffect(url) {
        onDispose {
            ref[0]?.destroy()
            ref[0] = null
        }
    }
    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            WebView(ctx).apply {
                setBackgroundColor(android.graphics.Color.BLACK)
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.mediaPlaybackRequiresUserGesture = false
                settings.javaScriptCanOpenWindowsAutomatically = false
                settings.setSupportMultipleWindows(false)
                settings.mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                webViewClient = object : WebViewClient() {
                    // Blokir iklan/popup: navigasi karena sentuhan ke host lain ditolak.
                    override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                        val h = request.url.host.orEmpty()
                        return request.hasGesture() && h != host && !h.endsWith(".$host")
                    }
                }
                webChromeClient = object : WebChromeClient() {
                    override fun onShowCustomView(view: View, callback: WebChromeClient.CustomViewCallback) {
                        onFullscreen(FullScreenReq(view, callback))
                    }

                    override fun onHideCustomView() {
                        onFullscreen(null)
                    }
                }
                ref[0] = this
                loadUrl(url)
            }
        },
    )
}
