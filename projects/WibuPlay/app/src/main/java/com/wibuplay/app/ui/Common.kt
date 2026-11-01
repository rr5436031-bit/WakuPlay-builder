package com.wibuplay.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.wibuplay.app.data.AnimeItem
import com.wibuplay.app.data.userMessage
import kotlinx.coroutines.CancellationException

object C {
    val Bg = Color(0xFF0D0E13)
    val Surface = Color(0xFF171923)
    val SurfaceHi = Color(0xFF222533)
    val Accent = Color(0xFF8B7CFF)
    val Teal = Color(0xFF35D0BA)
    val Gold = Color(0xFFFFC53D)
    val Danger = Color(0xFFFF5C6C)
    val TextHi = Color(0xFFF2F3F8)
    val TextLo = Color(0xFF9AA0B4)
}

@Composable
fun WibuTheme(content: @Composable () -> Unit) {
    val scheme = darkColorScheme(
        primary = C.Accent, onPrimary = Color.White,
        secondary = C.Teal, background = C.Bg, onBackground = C.TextHi,
        surface = C.Surface, onSurface = C.TextHi,
        surfaceVariant = C.SurfaceHi, onSurfaceVariant = C.TextLo,
        error = C.Danger,
    )
    MaterialTheme(colorScheme = scheme, content = content)
}

// ───────── State async sederhana ─────────

sealed interface UiState<out T> {
    data object Loading : UiState<Nothing>
    data class Error(val msg: String) : UiState<Nothing>
    data class Ok<T>(val data: T) : UiState<T>
}

class AsyncState<T>(val state: UiState<T>, val retry: () -> Unit)

@Composable
fun <T> rememberAsync(vararg keys: Any?, block: suspend () -> T): AsyncState<T> {
    var attempt by remember { mutableIntStateOf(0) }
    val holder = remember(*keys, attempt) { mutableStateOf<UiState<T>>(UiState.Loading) }
    LaunchedEffect(*keys, attempt) {
        holder.value = UiState.Loading
        holder.value = try {
            UiState.Ok(block())
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            UiState.Error(e.userMessage())
        }
    }
    return AsyncState(holder.value) { attempt++ }
}

@Composable
fun <T> AsyncContent(a: AsyncState<T>, content: @Composable (T) -> Unit) {
    when (val s = a.state) {
        is UiState.Loading -> LoadingBox()
        is UiState.Error -> ErrorBox(s.msg, a.retry)
        is UiState.Ok -> content(s.data)
    }
}

@Composable
fun LoadingBox(modifier: Modifier = Modifier.fillMaxSize()) {
    Box(modifier, contentAlignment = Alignment.Center) {
        CircularProgressIndicator(color = C.Accent, modifier = Modifier.size(36.dp))
    }
}

@Composable
fun ErrorBox(msg: String, retry: (() -> Unit)? = null) {
    Column(
        Modifier.fillMaxSize().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(msg, color = C.TextLo, textAlign = TextAlign.Center)
        if (retry != null) {
            Spacer(Modifier.height(14.dp))
            Button(onClick = retry, colors = ButtonDefaults.buttonColors(containerColor = C.Accent)) { Text("Coba lagi") }
        }
    }
}

// ───────── Komponen visual ─────────

@Composable
fun LogoMark(markSize: Dp = 28.dp) {
    Canvas(Modifier.size(markSize)) {
        val w = this.size.width
        val h = this.size.height
        drawRoundRect(
            brush = Brush.linearGradient(listOf(C.Accent, C.Teal)),
            cornerRadius = CornerRadius(w * 0.28f, w * 0.28f),
        )
        val p = Path().apply {
            moveTo(w * 0.38f, h * 0.27f)
            lineTo(w * 0.78f, h * 0.5f)
            lineTo(w * 0.38f, h * 0.73f)
            close()
        }
        drawPath(p, Color.White)
    }
}

@Composable
fun LogoRow() {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        LogoMark(30.dp)
        Text("WibuPlay", color = C.TextHi, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
    }
}

@Composable
fun Pill(text: String, selected: Boolean = false, onClick: () -> Unit = {}) {
    Box(
        Modifier.clip(RoundedCornerShape(50))
            .background(if (selected) C.Accent else C.SurfaceHi)
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 9.dp),
    ) {
        Text(text, color = if (selected) Color.White else C.TextHi, fontSize = 14.sp, maxLines = 1)
    }
}

@Composable
fun SectionTitle(title: String, action: String? = null, onAction: () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, color = C.TextHi, fontSize = 22.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
        if (action != null) {
            Text(action, color = C.Accent, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.clickable(onClick = onAction))
        }
    }
}

@Composable
fun TopBar(title: String, onBack: (() -> Unit)? = null, actions: @Composable () -> Unit = {}) {
    Row(
        Modifier.fillMaxWidth().height(56.dp).padding(horizontal = 4.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Kembali", tint = C.TextHi)
            }
        } else Spacer(Modifier.width(12.dp))
        Text(
            title, color = C.TextHi, fontSize = 20.sp, fontWeight = FontWeight.Bold,
            maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f),
        )
        actions()
    }
}

@Composable
fun ProgressBar(progress: Float, modifier: Modifier = Modifier, color: Color = C.Teal, height: Dp = 6.dp) {
    Box(modifier.height(height).clip(RoundedCornerShape(50)).background(C.SurfaceHi)) {
        Box(
            Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).height(height)
                .clip(RoundedCornerShape(50)).background(color),
        )
    }
}

@Composable
fun Avatar(name: String, url: String?, size: Dp = 56.dp) {
    Box(
        Modifier.size(size).clip(CircleShape).background(Brush.linearGradient(listOf(C.Accent, C.Teal))),
        contentAlignment = Alignment.Center,
    ) {
        if (url != null) {
            AsyncImage(model = url, contentDescription = null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
        } else {
            Text(
                name.take(1).uppercase().ifEmpty { "?" }, color = Color.White,
                fontWeight = FontWeight.Bold, fontSize = (size.value * 0.42f).sp,
            )
        }
    }
}

@Composable
fun Tag(text: String, bg: Color, fg: Color = Color.White) {
    Box(
        Modifier.clip(RoundedCornerShape(topStart = 12.dp, bottomEnd = 12.dp)).background(bg)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    ) { Text(text, color = fg, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1) }
}

@Composable
fun PosterCard(item: AnimeItem, modifier: Modifier = Modifier, rank: Int? = null, onClick: () -> Unit) {
    Column(modifier.clickable(onClick = onClick)) {
        Box(Modifier.fillMaxWidth().aspectRatio(0.68f).clip(RoundedCornerShape(14.dp)).background(C.SurfaceHi)) {
            AsyncImage(model = item.cover, contentDescription = item.title, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
            Box(
                Modifier.fillMaxSize().background(
                    Brush.verticalGradient(listOf(Color.Transparent, Color(0xCC000000)), startY = 200f),
                ),
            )
            if (rank != null) {
                Box(Modifier.align(Alignment.TopStart)) { Tag("#$rank", C.Gold, Color.Black) }
            } else if (item.badge != null) {
                Box(Modifier.align(Alignment.TopStart)) { Tag(item.badge, C.Accent) }
            }
            if (item.score != null) {
                Row(
                    Modifier.align(Alignment.TopEnd).padding(6.dp).clip(RoundedCornerShape(8.dp))
                        .background(Color(0xAA000000)).padding(horizontal = 6.dp, vertical = 2.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Star, null, tint = C.Gold, modifier = Modifier.size(12.dp))
                    Spacer(Modifier.width(2.dp))
                    Text(item.score, color = Color.White, fontSize = 11.sp)
                }
            }
            if (item.episodeLabel != null) {
                Text(
                    item.episodeLabel, color = Color.White, fontWeight = FontWeight.Bold, fontSize = 14.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.align(Alignment.BottomStart).padding(8.dp),
                )
            }
        }
        if (item.views != null) {
            Text(item.views + " views", color = C.TextLo, fontSize = 11.sp, modifier = Modifier.padding(top = 4.dp), maxLines = 1)
        }
        Text(
            item.title, color = C.TextHi, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
            maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 3.dp),
        )
    }
}

/** Grid poster di dalam LazyColumn (tanpa nested scroll). */
fun LazyListScope.posterGrid(list: List<AnimeItem>, cols: Int = 3, onClick: (AnimeItem) -> Unit) {
    val rows = list.chunked(cols)
    items(rows.size) { i ->
        val r = rows[i]
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            r.forEach { a -> PosterCard(a, Modifier.weight(1f)) { onClick(a) } }
            repeat(cols - r.size) { Spacer(Modifier.weight(1f)) }
        }
    }
}

fun fmtTime(sec: Long): String {
    val s = if (sec < 0) 0 else sec
    val h = s / 3600
    val m = (s % 3600) / 60
    val ss = s % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, ss) else "%02d:%02d".format(m, ss)
}
