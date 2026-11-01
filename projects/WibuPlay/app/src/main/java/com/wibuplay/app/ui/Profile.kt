package com.wibuplay.app.ui

import android.annotation.SuppressLint
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import com.wibuplay.app.AppVM
import com.wibuplay.app.data.AppConfig
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.Sources
import com.wibuplay.app.data.str
import com.wibuplay.app.xpForLevel

@Composable
private fun Card(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable () -> Unit) {
    val m = modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.Surface)
    Box((if (onClick != null) m.clickable(onClick = onClick) else m).padding(16.dp)) { content() }
}

@Composable
private fun StatBox(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier.clip(RoundedCornerShape(14.dp)).background(C.Surface).padding(14.dp)) {
        Text(value, color = C.TextHi, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        Text(label, color = C.TextLo, fontSize = 12.sp)
    }
}

private fun hours(sec: Long): String {
    val h = sec / 3600
    val m = (sec % 3600) / 60
    return if (h > 0) "${h}j ${m}m" else "${m}m"
}

@Composable
fun ProfileScreen(vm: AppVM, a: Actions) {
    val p by vm.profile.collectAsState()
    val stats by vm.stats.collectAsState()
    var editing by remember { mutableStateOf(false) }
    var name by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp)) {
        TopBar("Profil")
        val u = p
        if (u == null) {
            LoadingBox(Modifier.fillMaxWidth().height(200.dp))
            return@Column
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(u.username, u.avatar, 72.dp)
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(u.username, color = C.TextHi, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                Text(u.email, color = C.TextLo, fontSize = 13.sp)
                Text("ID: ${u.id}", color = C.TextLo, fontSize = 10.sp, maxLines = 1)
            }
            TextButton(onClick = { name = u.username; editing = true }) { Text("Ubah", color = C.Accent) }
        }
        Spacer(Modifier.height(16.dp))
        Card(onClick = a.level) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Tag("Lv. ${u.level}", C.Accent)
                    Spacer(Modifier.width(10.dp))
                    Text("${u.xp} / ${xpForLevel(u.level + 1)} XP", color = C.TextHi, fontSize = 15.sp)
                }
                Spacer(Modifier.height(10.dp))
                val base = xpForLevel(u.level)
                ProgressBar((u.xp - base).toFloat() / (xpForLevel(u.level + 1) - base).toFloat(), Modifier.fillMaxWidth(), height = 8.dp)
            }
        }
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatBox("Anime ditonton", "${stats?.optInt("total_anime_watched", 0) ?: 0}", Modifier.weight(1f))
            StatBox("Episode ditonton", "${stats?.optInt("total_episodes_watched", 0) ?: 0}", Modifier.weight(1f))
            StatBox("Waktu nonton", hours(u.watchSeconds), Modifier.weight(1f))
        }
        Spacer(Modifier.height(12.dp))
        Card(onClick = a.premium) {
            Column {
                Text(if (u.premium) "Premium aktif" else "Belum premium", color = if (u.premium) C.Gold else C.TextHi, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                Text(
                    if (u.premium) "Berlaku sampai ${u.premiumExpiredAt?.take(10) ?: "-"}" else "Ketuk untuk melihat paket",
                    color = C.TextLo, fontSize = 13.sp,
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        Card(onClick = a.settings) { Text("Pengaturan", color = C.TextHi, fontSize = 16.sp) }
    }

    if (editing) {
        AlertDialog(
            onDismissRequest = { editing = false },
            title = { Text("Ubah username") },
            text = { TextField(value = name, onValueChange = { if (it.length <= 24) name = it }, singleLine = true) },
            confirmButton = {
                TextButton(onClick = { if (name.isNotBlank()) vm.updateUsername(name); editing = false }) { Text("Simpan") }
            },
            dismissButton = { TextButton(onClick = { editing = false }) { Text("Batal") } },
        )
    }
}

@Composable
fun LevelScreen(vm: AppVM, onBack: () -> Unit) {
    val p by vm.profile.collectAsState()
    val events = rememberAsync { Graph.api.xpEvents() }
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Level & XP", onBack)
        val u = p
        if (u != null) {
            val base = xpForLevel(u.level)
            val next = xpForLevel(u.level + 1)
            Column(Modifier.padding(16.dp)) {
                Text("Level ${u.level}", color = C.TextHi, fontSize = 34.sp, fontWeight = FontWeight.ExtraBold)
                Text("${u.xp} XP · butuh ${next - u.xp} XP lagi untuk level ${u.level + 1}", color = C.TextLo, fontSize = 14.sp)
                Spacer(Modifier.height(12.dp))
                ProgressBar((u.xp - base).toFloat() / (next - base).toFloat(), Modifier.fillMaxWidth(), height = 10.dp)
                Spacer(Modifier.height(8.dp))
                Text("XP didapat dari waktu menonton yang tercatat server (20 XP per episode setelah ≥5 menit, sekali per episode).", color = C.TextLo, fontSize = 12.sp)
            }
        }
        SectionTitle("Riwayat XP")
        AsyncContent(events) { arr ->
            if (arr.length() == 0) ErrorBox("Belum ada riwayat XP.")
            else LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                items(arr.length()) { i ->
                    val o = arr.getJSONObject(i)
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(C.Surface).padding(14.dp)) {
                        Column(Modifier.weight(1f)) {
                            Text(o.str("source") ?: "-", color = C.TextHi, fontSize = 14.sp)
                            Text((o.str("created_at") ?: "").take(16).replace('T', ' '), color = C.TextLo, fontSize = 11.sp)
                        }
                        Text("+${o.optInt("amount")} XP", color = C.Teal, fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }
}

@Composable
fun PremiumScreen(vm: AppVM, onBack: () -> Unit, onBuy: () -> Unit) {
    val p by vm.profile.collectAsState()
    val pk = rememberAsync { Graph.api.premiumPackages() }
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Premium", onBack)
        Column(Modifier.padding(16.dp)) {
            val u = p
            Text(if (u?.premium == true) "Status: Premium aktif" else "Status: Belum premium", color = if (u?.premium == true) C.Gold else C.TextHi, fontSize = 18.sp, fontWeight = FontWeight.Bold)
            if (u?.premium == true) Text("Masa berlaku sampai ${u.premiumExpiredAt?.take(10) ?: "-"}", color = C.TextLo, fontSize = 14.sp)
        }
        SectionTitle("Paket")
        AsyncContent(pk) { arr ->
            if (arr.length() == 0) ErrorBox("Belum ada paket premium yang tersedia.")
            else LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                items(arr.length()) { i ->
                    val o = arr.getJSONObject(i)
                    Card {
                        Column {
                            Text(o.str("name") ?: "Paket", color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 17.sp)
                            o.str("description")?.let { Text(it, color = C.TextLo, fontSize = 13.sp) }
                            Text(
                                "Rp ${o.optLong("price_idr")} · ${o.optInt("duration_days")} hari",
                                color = C.Gold, fontSize = 14.sp, modifier = Modifier.padding(top = 6.dp),
                            )
                        }
                    }
                }
                item {
                    Button(
                        onClick = onBuy, modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = C.Accent),
                    ) { Text("Beli Premium") }
                }
            }
        }
    }
}

/** Membuka halaman premium di WebView dengan token sesi sekali pakai yang divalidasi backend. */
@SuppressLint("SetJavaScriptEnabled")
@Composable
fun PremiumWebScreen(onBack: () -> Unit) {
    val tok = rememberAsync { Graph.api.createWebHandoff() }
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Beli Premium", onBack)
        AsyncContent(tok) { token ->
            Column(Modifier.fillMaxSize()) {
                if (token == null) {
                    Text(
                        "Verifikasi otomatis belum aktif (fungsi create_web_handoff belum dipasang di Supabase). Kamu perlu login manual di website.",
                        color = C.Gold, fontSize = 12.sp, modifier = Modifier.padding(12.dp),
                    )
                }
                val url = if (token != null) AppConfig.PREMIUM_URL + "#wp_token=" + token else AppConfig.PREMIUM_URL
                val host = remember { android.net.Uri.parse(AppConfig.PREMIUM_URL).host.orEmpty() }
                val pageUrl = url
                AndroidView(
                    modifier = Modifier.fillMaxSize(),
                    factory = { ctx ->
                        WebView(ctx).apply {
                            setBackgroundColor(android.graphics.Color.BLACK)
                            settings.javaScriptEnabled = true
                            settings.domStorageEnabled = true
                            webViewClient = object : WebViewClient() {
                                override fun shouldOverrideUrlLoading(view: WebView, request: android.webkit.WebResourceRequest): Boolean =
                                    request.url.host.orEmpty() != host
                            }
                            loadUrl(pageUrl)
                        }
                    },
                )
            }
        }
    }
}

@Composable
fun SettingsScreen(vm: AppVM, onBack: () -> Unit, onDiag: () -> Unit) {
    val exp by vm.expPopup.collectAsState()
    val src by vm.sourceId.collectAsState()
    val p by vm.profile.collectAsState()
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding().verticalScroll(rememberScrollState())) {
        TopBar("Pengaturan", onBack)
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            p?.let { Text("${it.username} · ${it.email}", color = C.TextLo, fontSize = 13.sp) }
            Text("Sumber anime bawaan", color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(Sources.all) { s -> Pill(s.label, s.id == src) { vm.setSource(s.id) } }
            }
            Card {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("Tampilkan popup XP", color = C.TextHi, modifier = Modifier.weight(1f))
                    Switch(checked = exp, onCheckedChange = { vm.setExpPopup(it) })
                }
            }
            Text("Tentang", color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 18.sp)
            Card { Text("Versi ${AppConfig.APP_VERSION}", color = C.TextHi) }
            Card(onClick = onDiag) { Text("Diagnostik API", color = C.TextHi) }
            Button(
                onClick = { vm.logout() }, modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = C.Danger),
            ) { Text("Logout", color = Color.White) }
        }
    }
}

/** Menguji tiap sumber API dan menampilkan hasilnya (untuk memeriksa format respons nyata di perangkat). */
@Composable
fun DiagScreen(onBack: () -> Unit) {
    val res = rememberAsync { Sources.all.map { it.label to Graph.anime.probe(it) } }
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Diagnostik API", onBack)
        AsyncContent(res) { list ->
            Column(Modifier.verticalScroll(rememberScrollState()).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                list.forEach { (name, text) ->
                    Column {
                        Text(name, color = C.Accent, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                        Text(text.ifBlank { "(tidak ada endpoint yang diuji)" }, color = C.TextLo, fontSize = 12.sp)
                    }
                }
            }
        }
    }
}
