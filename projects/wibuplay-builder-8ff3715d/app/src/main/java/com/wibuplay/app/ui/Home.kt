package com.wibuplay.app.ui

import androidx.compose.foundation.ExperimentalFoundationApi
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.wibuplay.app.AppVM
import com.wibuplay.app.HistoryEntry
import com.wibuplay.app.UserProfile
import com.wibuplay.app.data.AnimeItem
import com.wibuplay.app.data.Feature
import com.wibuplay.app.data.GenreItem
import com.wibuplay.app.data.Section
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.Source
import com.wibuplay.app.data.Sources
import com.wibuplay.app.xpForLevel
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

class HomeData(
    val latest: List<AnimeItem>,
    val popular: List<AnimeItem>,
    val completed: List<AnimeItem>,
    val genres: List<GenreItem>,
)

suspend fun loadHome(src: Source): HomeData = coroutineScope {
    val l = async { runCatching { Graph.anime.list(src, Feature.LATEST) } }
    val p = async { runCatching { Graph.anime.list(src, Feature.POPULAR) } }
    val c = async { runCatching { Graph.anime.list(src, Feature.COMPLETED) } }
    val g = async { runCatching { Graph.anime.genres(src) } }
    val h = async { runCatching { Graph.anime.home(src) } }
    val latest = l.await()
    val popular = p.await()
    val completed = c.await()
    val home = h.await()
    if (latest.isFailure && popular.isFailure && completed.isFailure && home.isFailure) {
        throw (home.exceptionOrNull() ?: latest.exceptionOrNull() ?: Exception("Gagal memuat"))
    }
    val sections: List<Section> = home.getOrNull() ?: emptyList()
    var latestList: List<AnimeItem> = latest.getOrNull() ?: emptyList()
    if (latestList.isEmpty() && sections.isNotEmpty()) latestList = sections.first().items
    HomeData(
        latest = latestList,
        popular = popular.getOrNull() ?: emptyList(),
        completed = completed.getOrNull() ?: emptyList(),
        genres = g.await().getOrNull() ?: emptyList(),
    )
}

@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
fun HomeScreen(vm: AppVM, a: Actions) {
    val srcId by vm.sourceId.collectAsState()
    val prof by vm.profile.collectAsState()
    val hist by vm.history.collectAsState()
    val data = rememberAsync(srcId) { loadHome(Sources.byId(srcId)) }

    LazyColumn(
        Modifier.fillMaxSize().background(C.Bg).statusBarsPadding(),
        contentPadding = PaddingValues(bottom = 16.dp),
    ) {
        item { ProfileHeader(prof, a) }
        item { PremiumBanner(prof?.premium == true, a.premium) }
        item {
            LazyRow(
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(Sources.all) { s -> Pill(s.label, s.id == srcId) { vm.setSource(s.id) } }
            }
        }
        item { SearchBar(a.search) }
        item { ChatEntry(a.chat) }

        when (val st = data.state) {
            is UiState.Loading -> item { LoadingBox(Modifier.fillMaxWidth().height(260.dp)) }
            is UiState.Error -> item { Box(Modifier.fillMaxWidth().height(260.dp)) { ErrorBox(st.msg, data.retry) } }
            is UiState.Ok -> {
                val d = st.data
                if (d.popular.isNotEmpty()) item { Hero(d.popular.take(5), a.openAnime) }

                val last = hist.distinctBy { it.animeId }.take(10)
                if (last.isNotEmpty()) {
                    item { SectionTitle("Terakhir Ditonton", "Lihat Lainnya >", a.history) }
                    item { LastWatchedRow(last, a.openAnime) }
                }

                if (d.latest.isNotEmpty()) {
                    item { SectionTitle("Update Terbaru", "Lihat Jadwal >", a.schedule) }
                    posterGrid(d.latest.take(9).map { it.copy(badge = "New") }) { a.openAnime(it.key) }
                    item { ShowMore { a.list("latest") } }
                }

                if (d.genres.isNotEmpty()) {
                    item { SectionTitle("Genre") }
                    item {
                        FlowRow(
                            Modifier.padding(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            d.genres.forEach { g -> Pill(g.name) { a.genre(g.slug, g.name) } }
                        }
                    }
                }

                if (d.popular.isNotEmpty()) {
                    item { SectionTitle("Anime Populer", "Lihat Semua >") { a.list("popular") } }
                    item {
                        LazyRow(
                            contentPadding = PaddingValues(horizontal = 16.dp),
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            items(d.popular.take(10).size) { i ->
                                val it0 = d.popular[i]
                                PosterCard(it0, Modifier.width(140.dp), rank = i + 1) { a.openAnime(it0.key) }
                            }
                        }
                    }
                }

                if (d.completed.isNotEmpty()) {
                    item { SectionTitle("Anime Tamat", "Lihat Semua >") { a.list("completed") } }
                    posterGrid(d.completed.take(6)) { a.openAnime(it.key) }
                    item { ShowMore { a.list("completed") } }
                }

                if (d.latest.isEmpty() && d.popular.isEmpty() && d.completed.isEmpty()) {
                    item {
                        Box(Modifier.fillMaxWidth().height(200.dp)) {
                            ErrorBox("Respons API dari ${Sources.byId(srcId).label} tidak berisi daftar anime yang dikenali. Buka Pengaturan > Diagnostik API.")
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProfileHeader(p: UserProfile?, a: Actions) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp).clickable(onClick = a.level),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(p?.username ?: "?", p?.avatar, 56.dp)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(p?.username ?: "…", color = C.TextHi, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                Spacer(Modifier.width(8.dp))
                Tag("Lv. ${p?.level ?: 1}", C.SurfaceHi, C.TextHi)
                Spacer(Modifier.width(8.dp))
                Text("#${p?.userNo ?: 0}", color = C.TextLo, fontSize = 12.sp)
            }
            Spacer(Modifier.height(8.dp))
            val lv = p?.level ?: 1
            val base = xpForLevel(lv)
            val next = xpForLevel(lv + 1)
            val xp = p?.xp ?: 0
            Row(verticalAlignment = Alignment.CenterVertically) {
                ProgressBar(((xp - base).toFloat() / (next - base).toFloat()), Modifier.weight(1f))
                Spacer(Modifier.width(8.dp))
                Text("$xp/$next XP", color = C.TextLo, fontSize = 12.sp)
            }
        }
        IconButton(onClick = a.settings) { Icon(Icons.Filled.Settings, "Pengaturan", tint = C.TextHi) }
    }
}

@Composable
private fun PremiumBanner(isPremium: Boolean, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF3A2F7A), Color(0xFF1F4F55))))
            .clickable(onClick = onClick).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tag("PREMIUM", C.Gold, Color.Black)
        Spacer(Modifier.width(12.dp))
        Text(
            if (isPremium) "Premium aktif. Terima kasih sudah mendukung!" else "Dukung WibuPlay dan buka fitur premium",
            color = C.TextHi, fontSize = 14.sp,
        )
    }
}

@Composable
private fun SearchBar(onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(28.dp)).background(C.Surface)
            .clickable(onClick = onClick).padding(horizontal = 18.dp, vertical = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Icons.Filled.Search, null, tint = C.TextLo)
        Spacer(Modifier.width(12.dp))
        Text("Cari anime di sini", color = C.TextLo, fontSize = 16.sp)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Hero(items: List<AnimeItem>, onOpen: (String) -> Unit) {
    val pager = rememberPagerState(pageCount = { items.size })
    Column(Modifier.padding(vertical = 8.dp)) {
        HorizontalPager(state = pager, modifier = Modifier.fillMaxWidth().height(190.dp), contentPadding = PaddingValues(horizontal = 16.dp), pageSpacing = 10.dp) { i ->
            val it0 = items[i]
            Box(
                Modifier.fillMaxSize().clip(RoundedCornerShape(20.dp)).background(C.SurfaceHi)
                    .clickable { onOpen(it0.key) },
            ) {
                AsyncImage(model = it0.cover, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xDD000000)))))
                Box(Modifier.align(Alignment.TopStart)) { Tag("#${i + 1}", C.Gold, Color.Black) }
                Text(
                    it0.title, color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold,
                    maxLines = 2, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.align(Alignment.BottomStart).padding(14.dp),
                )
            }
        }
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.Center) {
            repeat(items.size) { i ->
                Box(
                    Modifier.padding(3.dp).size(7.dp).clip(CircleShape)
                        .background(if (i == pager.currentPage) C.Accent else C.SurfaceHi),
                )
            }
        }
    }
}

@Composable
private fun LastWatchedRow(list: List<HistoryEntry>, onOpen: (String) -> Unit) {
    LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        items(list) { e ->
            Column(Modifier.width(210.dp).clickable { onOpen(e.animeId) }) {
                Box(Modifier.fillMaxWidth().height(118.dp).clip(RoundedCornerShape(14.dp)).background(C.SurfaceHi)) {
                    AsyncImage(model = e.animeCover, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color.Transparent, Color(0xCC000000)))))
                    Text(
                        "Eps " + (e.episodeNumber ?: e.episodeTitle), color = Color.White, fontWeight = FontWeight.Bold,
                        fontSize = 14.sp, maxLines = 1, modifier = Modifier.align(Alignment.BottomStart).padding(10.dp),
                    )
                    if (e.duration > 0) {
                        ProgressBar(
                            e.lastPosition.toFloat() / e.duration.toFloat(),
                            Modifier.align(Alignment.BottomCenter).fillMaxWidth(), color = C.Danger, height = 3.dp,
                        )
                    }
                }
                Text(e.animeTitle, color = C.TextHi, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 6.dp))
            }
        }
    }
}

@Composable
fun ShowMore(onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(vertical = 10.dp), contentAlignment = Alignment.Center) {
        Text("Tampilkan Lebih Banyak", color = C.Accent, fontSize = 16.sp, fontWeight = FontWeight.Bold, modifier = Modifier.clickable(onClick = onClick).padding(10.dp))
    }
}

@Composable
private fun ChatEntry(onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)
            .clip(RoundedCornerShape(16.dp)).background(C.Surface)
            .clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Tag("CHAT", C.Teal, Color.Black)
        Spacer(Modifier.width(12.dp))
        Text("Chat Global · ngobrol bareng di Channel 1, 2, 3", color = C.TextHi, fontSize = 14.sp, modifier = Modifier.weight(1f))
    }
}
