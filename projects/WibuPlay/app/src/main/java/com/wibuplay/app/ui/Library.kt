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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.wibuplay.app.HistoryEntry
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale

private val dateFmt = DateTimeFormatter.ofPattern("dd MMM yyyy", Locale("id", "ID"))
private val timeFmt = DateTimeFormatter.ofPattern("HH:mm")

private fun parseLocal(iso: String): java.time.ZonedDateTime? = try {
    OffsetDateTime.parse(iso).atZoneSameInstant(ZoneId.systemDefault())
} catch (e: Exception) {
    null
}

@Composable
fun HistoryScreen(vm: AppVM, onOpen: (String) -> Unit) {
    val list by vm.history.collectAsState()
    var confirmClear by remember { mutableStateOf(false) }
    val grouped = remember(list) {
        list.groupBy { parseLocal(it.watchedAt)?.format(dateFmt) ?: "Tanggal tidak diketahui" }.toList()
    }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Riwayat Menonton") {
            if (list.isNotEmpty()) {
                IconButton(onClick = { confirmClear = true }) { Icon(Icons.Filled.Delete, "Hapus semua", tint = C.TextHi) }
            }
        }
        if (list.isEmpty()) {
            ErrorBox("Belum ada riwayat. Tonton episode dan riwayatmu akan tersimpan di akun.")
        } else {
            LazyColumn(contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                grouped.forEach { (date, entries) ->
                    item { Tag(date, C.Accent) }
                    items(entries.size) { i -> HistoryRow(entries[i], onOpen) { vm.deleteHistory(entries[i]) } }
                }
            }
        }
    }

    if (confirmClear) {
        AlertDialog(
            onDismissRequest = { confirmClear = false },
            title = { Text("Hapus semua riwayat?") },
            text = { Text("Riwayat di semua perangkat akan terhapus.") },
            confirmButton = { TextButton(onClick = { vm.clearHistory(); confirmClear = false }) { Text("Hapus", color = C.Danger) } },
            dismissButton = { TextButton(onClick = { confirmClear = false }) { Text("Batal") } },
        )
    }
}

@Composable
private fun HistoryRow(e: HistoryEntry, onOpen: (String) -> Unit, onDelete: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(C.Surface)
            .clickable { onOpen(e.animeId) }.padding(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AsyncImage(
            model = e.animeCover, contentDescription = null, contentScale = ContentScale.Crop,
            modifier = Modifier.width(64.dp).height(92.dp).clip(RoundedCornerShape(10.dp)).background(C.SurfaceHi),
        )
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row {
                Text(e.animeTitle, color = C.TextHi, fontWeight = FontWeight.Bold, fontSize = 15.sp, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                Text(parseLocal(e.watchedAt)?.format(timeFmt) ?: "", color = C.TextLo, fontSize = 12.sp, modifier = Modifier.padding(start = 8.dp))
            }
            Text(e.episodeTitle.ifEmpty { "Episode ${e.episodeNumber ?: ""}" }, color = C.TextLo, fontSize = 13.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Spacer(Modifier.height(8.dp))
            if (e.duration > 0) {
                ProgressBar(e.lastPosition.toFloat() / e.duration.toFloat(), Modifier.fillMaxWidth(), color = C.Danger, height = 4.dp)
                Text("${fmtTime(e.lastPosition)} / ${fmtTime(e.duration)}", color = C.TextLo, fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp))
            } else {
                Text("Ditonton ${fmtTime(e.lastPosition)}", color = C.TextLo, fontSize = 11.sp)
            }
        }
        IconButton(onClick = onDelete) { Icon(Icons.Filled.Delete, "Hapus", tint = C.TextLo) }
    }
}

@Composable
fun FavoritesScreen(vm: AppVM, onOpen: (String) -> Unit) {
    val favs by vm.favorites.collectAsState()
    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Favorit")
        if (favs.isEmpty()) {
            ErrorBox("Belum ada favorit. Ketuk ikon hati di halaman detail anime.")
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3), modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(12.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(favs, key = { it.animeId }) { f -> PosterCard(f.toItem()) { onOpen(f.animeId) } }
            }
        }
    }
}
