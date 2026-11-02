package com.wibuplay.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.wibuplay.app.AppVM
import com.wibuplay.app.PlayerSession
import com.wibuplay.app.data.AnimeDetail
import com.wibuplay.app.data.Graph

@Composable
fun DetailScreen(vm: AppVM, key: String, onBack: () -> Unit, onPlay: () -> Unit) {
    val st = rememberAsync(key) { Graph.anime.detail(key) }
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Detail Anime", onBack)
        AsyncContent(st) { d -> DetailBody(vm, d, onPlay) }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailBody(vm: AppVM, d: AnimeDetail, onPlay: () -> Unit) {
    val favs by vm.favorites.collectAsState()
    val hist by vm.history.collectAsState()
    val isFav = favs.any { it.animeId == d.key }
    var expanded by remember(d.key) { mutableStateOf(false) }

    val myHist = hist.filter { it.animeId == d.key }
    val last = myHist.maxByOrNull { it.watchedAt }
    val lastIndex = if (last == null) -1 else d.episodes.indexOfFirst { "${d.key}#${it.id}" == last.episodeId }

    fun play(i: Int) {
        vm.player = PlayerSession(d, i)
        onPlay()
    }

    LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 24.dp)) {
        item {
            Row(Modifier.fillMaxWidth().padding(16.dp)) {
                AsyncImage(
                    model = d.cover, contentDescription = d.title, contentScale = ContentScale.Crop,
                    modifier = Modifier.width(120.dp).height(172.dp).clip(RoundedCornerShape(14.dp)).background(C.SurfaceHi),
                )
                Spacer(Modifier.width(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(d.title, color = C.TextHi, fontSize = 20.sp, fontWeight = FontWeight.Bold, maxLines = 4, overflow = TextOverflow.Ellipsis)
                    d.status?.let { Text(it, color = C.Teal, fontSize = 13.sp, modifier = Modifier.padding(top = 4.dp)) }
                    d.meta.forEach { (k, v) ->
                        Text("$k: $v", color = C.TextLo, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 2.dp))
                    }
                    Spacer(Modifier.height(10.dp))
                    IconButton(onClick = { vm.toggleFavorite(d.key, d.title, d.cover) }) {
                        Icon(
                            if (isFav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            "Favorit", tint = if (isFav) C.Danger else C.TextHi, modifier = Modifier.size(28.dp),
                        )
                    }
                }
            }
        }
        if (d.genres.isNotEmpty()) {
            item {
                FlowRow(
                    Modifier.padding(horizontal = 16.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
                ) { d.genres.forEach { Pill(it) } }
            }
        }
        if (!d.synopsis.isNullOrBlank()) {
            item {
                Column(Modifier.padding(16.dp).clickable { expanded = !expanded }) {
                    Text("Sinopsis", color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 18.sp)
                    Text(
                        d.synopsis, color = C.TextLo, fontSize = 14.sp, lineHeight = 21.sp,
                        maxLines = if (expanded) Int.MAX_VALUE else 4, overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
            }
        }
        if (d.episodes.isNotEmpty()) {
            item {
                Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (lastIndex >= 0) {
                        Button(
                            onClick = { play(lastIndex) }, modifier = Modifier.weight(1f),
                            colors = ButtonDefaults.buttonColors(containerColor = C.Accent),
                        ) {
                            Icon(Icons.Filled.PlayArrow, null)
                            Text("Lanjutkan ${d.episodes[lastIndex].number?.let { "Eps $it" } ?: ""}".trim())
                        }
                    }
                    Button(
                        onClick = { play(0) }, modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(containerColor = if (lastIndex >= 0) C.SurfaceHi else C.Accent),
                    ) {
                        Icon(Icons.Filled.PlayArrow, null)
                        Text("Mulai dari awal")
                    }
                }
            }
            item { SectionTitle("Episode (${d.episodes.size})") }
            items(d.episodes.size) { i ->
                val ep = d.episodes[i]
                val h = myHist.firstOrNull { it.episodeId == "${d.key}#${ep.id}" }
                Column(
                    Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)
                        .clip(RoundedCornerShape(14.dp)).background(C.Surface)
                        .clickable { play(i) }.padding(14.dp),
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Filled.PlayArrow, null, tint = C.Accent)
                        Spacer(Modifier.width(8.dp))
                        Text(ep.title, color = C.TextHi, fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                    }
                    if (h != null && h.duration > 0) {
                        ProgressBar(h.lastPosition.toFloat() / h.duration.toFloat(), Modifier.fillMaxWidth().padding(top = 8.dp), color = C.Danger, height = 3.dp)
                    }
                }
            }
        } else {
            item {
                Text(
                    "Daftar episode tidak ditemukan pada respons API untuk anime ini.",
                    color = C.TextLo, modifier = Modifier.padding(16.dp),
                )
            }
        }
    }
}
