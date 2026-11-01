package com.wibuplay.app.ui

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshots.SnapshotStateList
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.wibuplay.app.AppVM
import com.wibuplay.app.data.AnimeItem
import com.wibuplay.app.data.Feature
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.Sources
import com.wibuplay.app.data.userMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** Grid poster dengan "muat lagi" (paginasi). fetch(page) mengembalikan daftar halaman tsb. */
@Composable
fun PagedGridScreen(
    title: String,
    fetchKey: Any,
    onBack: () -> Unit,
    onOpen: (AnimeItem) -> Unit,
    fetch: suspend (Int) -> List<AnimeItem>,
) {
    val shown: SnapshotStateList<AnimeItem> = remember(fetchKey) { mutableStateListOf() }
    var page by remember(fetchKey) { mutableIntStateOf(0) }
    var loading by remember(fetchKey) { mutableStateOf(false) }
    var error by remember(fetchKey) { mutableStateOf<String?>(null) }
    var ended by remember(fetchKey) { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    fun loadMore() {
        if (loading || ended) return
        loading = true
        error = null
        scope.launch {
            try {
                val next = page + 1
                val got = fetch(next)
                val known = shown.map { it.key }.toHashSet()
                val fresh = got.filter { known.add(it.key) }
                if (fresh.isEmpty()) ended = true else shown.addAll(fresh)
                page = next
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                error = e.userMessage()
                if (shown.isEmpty()) ended = true
            }
            loading = false
        }
    }

    LaunchedEffect(fetchKey) { loadMore() }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar(title, onBack)
        if (shown.isEmpty()) {
            when {
                loading -> LoadingBox()
                error != null -> ErrorBox(error ?: "", { ended = false; loadMore() })
                else -> ErrorBox("Tidak ada data untuk ditampilkan")
            }
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(shown.toList(), key = { it.key }) { a -> PosterCard(a) { onOpen(a) } }
                item(span = { GridItemSpan(maxLineSpan) }) {
                    Box(Modifier.fillMaxWidth().padding(8.dp), contentAlignment = Alignment.Center) {
                        when {
                            loading -> LoadingBox(Modifier.height(48.dp))
                            error != null -> Text("$error · ketuk untuk ulang", color = C.Danger, modifier = Modifier.clickable { loadMore() }.padding(10.dp))
                            !ended -> ShowMore { loadMore() }
                            else -> Text("— sudah semua —", color = C.TextLo, fontSize = 12.sp)
                        }
                    }
                }
            }
        }
    }
}

@Composable
fun SearchScreen(vm: AppVM, onBack: () -> Unit, onSubmit: (String) -> Unit) {
    var q by remember { mutableStateOf("") }
    val srcId by vm.sourceId.collectAsState()
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { focus.requestFocus() } }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Cari Anime", onBack)
        TextField(
            value = q, onValueChange = { q = it },
            placeholder = { Text("Judul anime…", color = C.TextLo) },
            leadingIcon = { Icon(Icons.Filled.Search, null, tint = C.TextLo) },
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(onSearch = { if (q.isNotBlank()) onSubmit(q.trim()) }),
            shape = RoundedCornerShape(28.dp),
            colors = TextFieldDefaults.colors(
                focusedContainerColor = C.Surface, unfocusedContainerColor = C.Surface,
                focusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
                unfocusedIndicatorColor = androidx.compose.ui.graphics.Color.Transparent,
            ),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).focusRequester(focus),
        )
        Text("Cari di sumber:", color = C.TextLo, fontSize = 13.sp, modifier = Modifier.padding(start = 16.dp, top = 14.dp, bottom = 6.dp))
        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(Sources.all) { s -> Pill(s.label, s.id == srcId) { vm.setSource(s.id) } }
        }
    }
}

@Composable
fun ResultsScreen(vm: AppVM, q: String, onBack: () -> Unit, onOpen: (String) -> Unit) {
    val srcId by vm.sourceId.collectAsState()
    val src = Sources.byId(srcId)
    PagedGridScreen("Hasil: $q", listOf("search", srcId, q), onBack, { onOpen(it.key) }) { page ->
        Graph.anime.list(src, Feature.SEARCH, page = page, q = q)
    }
}

@Composable
fun GenreScreen(vm: AppVM, slug: String, name: String, onBack: () -> Unit, onOpen: (String) -> Unit) {
    val srcId by vm.sourceId.collectAsState()
    val src = Sources.byId(srcId)
    PagedGridScreen("Genre: $name", listOf("genre", srcId, slug), onBack, { onOpen(it.key) }) { page ->
        Graph.anime.list(src, Feature.GENRE, page = page, slug = slug)
    }
}

/** kind: latest, popular, ongoing, completed, movie, donghua, live */
@Composable
fun ListScreen(vm: AppVM, kind: String, onBack: () -> Unit, onOpen: (String) -> Unit) {
    val srcId by vm.sourceId.collectAsState()
    val src = Sources.byId(srcId)
    val (title, feature) = when (kind) {
        "latest" -> "Update Terbaru" to Feature.LATEST
        "popular" -> "Anime Populer" to Feature.POPULAR
        "ongoing" -> "Sedang Tayang" to Feature.ONGOING
        "completed" -> "Anime Tamat" to Feature.COMPLETED
        "movie" -> "Movie" to Feature.MOVIE
        "donghua" -> "Donghua" to Feature.DONGHUA
        "live" -> "Live Action" to Feature.LIVE
        "az" -> "Daftar A-Z" to Feature.AZ
        else -> kind to Feature.LATEST
    }
    PagedGridScreen("$title · ${src.label}", listOf("list", srcId, kind), onBack, { onOpen(it.key) }) { page ->
        Graph.anime.list(src, feature, page = page)
    }
}

@Composable
fun ScheduleScreen(vm: AppVM, onOpen: (String) -> Unit) {
    val srcId by vm.sourceId.collectAsState()
    val st = rememberAsync(srcId) { Graph.anime.schedule(Sources.byId(srcId)) }
    var selected by remember(srcId) { mutableIntStateOf(0) }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Jadwal Tayang")
        LazyRow(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(Sources.all) { s -> Pill(s.label, s.id == srcId) { vm.setSource(s.id) } }
        }
        AsyncContent(st) { days ->
            if (days.isEmpty()) {
                ErrorBox("Jadwal tidak tersedia dari ${Sources.byId(srcId).label} atau formatnya belum dikenali.")
            } else {
                val idx = selected.coerceIn(0, days.size - 1)
                LazyRow(contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(days.size) { i -> Pill(days[i].day, i == idx) { selected = i } }
                }
                val entries = days[idx].entries
                LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(entries.size) { i ->
                        val e = entries[i]
                        Row(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.Surface)
                                .clickable { onOpen(e.item.key) }.padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            AsyncImage(
                                model = e.item.cover, contentDescription = null, contentScale = ContentScale.Crop,
                                modifier = Modifier.width(64.dp).height(92.dp).clip(RoundedCornerShape(10.dp)).background(C.SurfaceHi),
                            )
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text(e.item.title, color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                                e.item.episodeLabel?.let { Text(it, color = C.TextLo, fontSize = 13.sp, modifier = Modifier.padding(top = 2.dp)) }
                                e.time?.let { Text(it, color = C.Gold, fontSize = 13.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 2.dp)) }
                            }
                        }
                    }
                }
            }
        }
    }
}
