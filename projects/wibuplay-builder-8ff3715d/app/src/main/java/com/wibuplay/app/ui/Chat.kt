package com.wibuplay.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.wibuplay.app.AppVM
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.str
import com.wibuplay.app.data.userMessage
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.time.format.DateTimeFormatter

data class ChatMsg(
    val id: Long,
    val userId: String,
    val name: String,
    val no: Long,
    val level: Int,
    val avatar: String?,
    val text: String,
    val replyName: String?,
    val replyText: String?,
    val createdAt: String,
)

private fun parseMsg(o: JSONObject) = ChatMsg(
    id = o.optLong("id"),
    userId = o.str("user_id") ?: "",
    name = o.str("sender_name") ?: "User",
    no = o.optLong("sender_no"),
    level = o.optInt("sender_level", 1),
    avatar = o.str("sender_avatar"),
    text = o.str("content") ?: "",
    replyName = o.str("reply_name"),
    replyText = o.str("reply_text"),
    createdAt = o.str("created_at") ?: "",
)

private fun parseMsgs(a: JSONArray): List<ChatMsg> =
    (0 until a.length()).mapNotNull { a.optJSONObject(it)?.let(::parseMsg) }

private val nameColors = listOf(
    Color(0xFF7BE0B0), Color(0xFFFFD66B), Color(0xFFFF9FC2), Color(0xFF8FC7FF),
    Color(0xFFC9A6FF), Color(0xFFFFB38A),
)

private fun colorFor(userId: String) = nameColors[(userId.hashCode().toLong() and 0x7fffffff).toInt() % nameColors.size]

private val hm = DateTimeFormatter.ofPattern("HH:mm")

/** Chat global dengan Channel 1-3. Pesan diambil berkala (polling 3 detik) selama layar terbuka. */
@Composable
fun ChatScreen(vm: AppVM, onBack: () -> Unit) {
    val me = vm.session.collectAsState().value?.userId
    var channel by remember { mutableIntStateOf(1) }
    val msgs = remember(channel) { mutableStateListOf<ChatMsg>() } // terbaru di indeks 0
    var input by remember { mutableStateOf("") }
    var reply by remember(channel) { mutableStateOf<ChatMsg?>(null) }
    var sending by remember { mutableStateOf(false) }
    var loading by remember(channel) { mutableStateOf(true) }
    var loadError by remember(channel) { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(channel) {
        loading = true
        loadError = null
        try {
            msgs.addAll(parseMsgs(Graph.api.chatMessages(channel, null)))
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            loadError = e.userMessage()
        }
        loading = false
        while (isActive) {
            delay(3000)
            try {
                val last = msgs.firstOrNull()?.id ?: 0L
                for (m in parseMsgs(Graph.api.chatMessages(channel, last))) {
                    if (msgs.none { it.id == m.id }) msgs.add(0, m)
                }
                loadError = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // gangguan sementara: coba lagi pada putaran berikut
            }
        }
    }

    fun send() {
        val t = input.trim()
        if (t.isEmpty() || sending) return
        sending = true
        val ch = channel
        val target = reply
        scope.launch {
            try {
                val m = parseMsg(Graph.api.sendChat(ch, t, target?.id))
                if (ch == channel && msgs.none { it.id == m.id }) msgs.add(0, m)
                input = ""
                reply = null
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                vm.messages.tryEmit(e.userMessage())
            }
            sending = false
        }
    }

    Column(Modifier.fillMaxSize().background(C.Bg).statusBarsPadding()) {
        TopBar("Chat Global", onBack)

        // Peringatan aturan
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp)
                .clip(RoundedCornerShape(18.dp)).background(Color(0xFF3F3517)).padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Warning, null, tint = C.Gold, modifier = Modifier.size(22.dp))
            Spacer(Modifier.width(10.dp))
            Text("Dilarang berjualan premium dan harus sopan", color = C.TextHi, fontSize = 14.sp)
        }

        // Channel 1-3
        Row(Modifier.fillMaxWidth().padding(16.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            for (c in 1..3) {
                val sel = c == channel
                Row(
                    Modifier.weight(1f).clip(RoundedCornerShape(50))
                        .background(if (sel) Color(0xFF16263A) else C.Surface)
                        .border(1.5.dp, if (sel) C.Accent else C.SurfaceHi, RoundedCornerShape(50))
                        .clickable { channel = c }.padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("#", color = if (sel) C.Accent else C.TextLo, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                    Spacer(Modifier.width(6.dp))
                    Text("Channel $c", color = if (sel) C.TextHi else C.TextLo, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, maxLines = 1)
                }
            }
        }

        Box(Modifier.weight(1f).fillMaxWidth()) {
            when {
                loading -> LoadingBox()
                loadError != null && msgs.isEmpty() -> ErrorBox(loadError ?: "")
                msgs.isEmpty() -> ErrorBox("Belum ada pesan di Channel $channel. Mulai ngobrol!")
                else -> LazyColumn(
                    Modifier.fillMaxSize(),
                    reverseLayout = true,
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(msgs, key = { it.id }) { m -> MessageRow(m, m.userId == me) { reply = m } }
                }
            }
        }

        reply?.let { r ->
            Row(
                Modifier.fillMaxWidth().padding(horizontal = 12.dp).clip(RoundedCornerShape(12.dp)).background(C.Surface).padding(start = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Box(Modifier.width(3.dp).height(34.dp).background(C.Gold))
                Column(Modifier.weight(1f).padding(start = 10.dp)) {
                    Text("Membalas ${r.name}", color = C.Gold, fontSize = 12.sp, fontWeight = FontWeight.Bold)
                    Text(r.text, color = C.TextLo, fontSize = 12.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                IconButton(onClick = { reply = null }) { Icon(Icons.Filled.Close, "Batal balas", tint = C.TextLo) }
            }
        }

        Text(
            "${input.length}/255", color = C.TextLo, fontSize = 12.sp,
            modifier = Modifier.align(Alignment.End).padding(end = 80.dp, top = 6.dp),
        )
        Row(Modifier.fillMaxWidth().padding(start = 12.dp, end = 12.dp, bottom = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            TextField(
                value = input, onValueChange = { if (it.length <= 255) input = it },
                placeholder = { Text("Silakan masukkan pesan…", color = C.TextLo) },
                shape = RoundedCornerShape(28.dp),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = C.Surface, unfocusedContainerColor = C.Surface,
                    focusedIndicatorColor = Color.Transparent, unfocusedIndicatorColor = Color.Transparent,
                ),
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(10.dp))
            Box(
                Modifier.size(54.dp).clip(CircleShape).background(C.Accent).clickable(enabled = !sending) { send() },
                contentAlignment = Alignment.Center,
            ) { Icon(Icons.AutoMirrored.Filled.Send, "Kirim", tint = Color.White) }
        }
    }
}

@Composable
private fun MessageRow(m: ChatMsg, mine: Boolean, onReply: () -> Unit) {
    val time = parseLocal(m.createdAt)?.format(hm) ?: ""
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
        Avatar(m.name, m.avatar, 40.dp)
        Spacer(Modifier.width(8.dp))
        Column(
            Modifier.weight(1f, fill = false).clip(RoundedCornerShape(18.dp)).background(C.SurfaceHi)
                .clickable(onClick = onReply).padding(12.dp),
        ) {
            if (m.replyName != null) {
                Row(
                    Modifier.fillMaxWidth().padding(bottom = 8.dp).clip(RoundedCornerShape(10.dp)).background(Color(0xFF1B1D27)).padding(8.dp),
                ) {
                    Box(Modifier.width(3.dp).height(34.dp).background(C.Gold))
                    Column(Modifier.padding(start = 8.dp)) {
                        Text(m.replyName, color = C.Gold, fontSize = 13.sp, fontWeight = FontWeight.Bold, maxLines = 1)
                        Text(m.replyText ?: "", color = C.TextLo, fontSize = 13.sp, maxLines = 2, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    m.name, color = if (mine) C.Accent else colorFor(m.userId), fontWeight = FontWeight.ExtraBold, fontSize = 16.sp,
                    maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false),
                )
                Spacer(Modifier.width(8.dp))
                Text("#${m.no}", color = C.TextLo, fontSize = 12.sp, maxLines = 1)
            }
            Spacer(Modifier.height(4.dp))
            Tag("Lvl ${m.level}", Color(0xFF1F3B3A), C.Teal)
            Spacer(Modifier.height(6.dp))
            Text(m.text, color = C.TextHi, fontSize = 16.sp)
        }
        Text(time, color = C.TextLo, fontSize = 12.sp, modifier = Modifier.padding(start = 8.dp, bottom = 6.dp))
    }
}
