package com.wibuplay.app

import android.app.Application
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.wibuplay.app.data.AnimeDetail
import com.wibuplay.app.data.AnimeItem
import com.wibuplay.app.data.ApiException
import com.wibuplay.app.data.EpisodeItem
import com.wibuplay.app.data.Graph
import com.wibuplay.app.data.Session
import com.wibuplay.app.data.str
import com.wibuplay.app.data.userMessage
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException

class WibuApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Graph.init(this)
    }
}

data class UserProfile(
    val id: String,
    val userNo: Long,
    val username: String,
    val email: String,
    val avatar: String?,
    val level: Int,
    val xp: Int,
    val watchSeconds: Long,
    val premium: Boolean,
    val premiumExpiredAt: String?,
)

data class HistoryEntry(
    val id: String,
    val animeId: String,
    val animeTitle: String,
    val animeCover: String?,
    val episodeId: String,
    val episodeTitle: String,
    val episodeNumber: String?,
    val lastPosition: Long,
    val duration: Long,
    val watchedAt: String,
)

data class FavEntry(val animeId: String, val title: String, val cover: String?) {
    fun toItem() = AnimeItem(animeId.substringBefore(':'), animeId.substringAfter(':'), title, cover)
}

data class PlayerSession(val detail: AnimeDetail, val index: Int)

/** Rumus level (identik dengan fungsi calc_level di SQL): XP kumulatif level L = 250 * L * (L-1). */
fun xpForLevel(level: Int): Int = 250 * level * (level - 1)

class AppVM : ViewModel() {
    val session = Graph.auth.session
    val ready = MutableStateFlow(false)
    val profile = MutableStateFlow<UserProfile?>(null)
    val stats = MutableStateFlow<JSONObject?>(null)
    val favorites = MutableStateFlow<List<FavEntry>>(emptyList())
    val history = MutableStateFlow<List<HistoryEntry>>(emptyList())
    val sourceId = MutableStateFlow("winbu")
    val expPopup = MutableStateFlow(true)
    val loginBusy = MutableStateFlow(false)
    val messages = MutableSharedFlow<String>(extraBufferCapacity = 8)
    var player: PlayerSession? = null

    private val pendingMutex = Mutex()

    init {
        viewModelScope.launch {
            expPopup.value = Graph.local.getBool("exp_popup", true)
            sourceId.value = Graph.local.getString("source") ?: "winbu"
            Graph.auth.restore()
            ready.value = true
            Graph.auth.session.map { it?.userId }.distinctUntilChanged().collect { uid ->
                if (uid != null) onLogin() else onLogout()
            }
        }
    }

    private fun onLogin() {
        viewModelScope.launch {
            try {
                Graph.api.ensureProfile()
            } catch (e: Exception) {
                messages.tryEmit("Profil: " + e.userMessage())
            }
            refreshUser()
            refreshFavorites()
            refreshHistory()
            flushPending()
        }
    }

    private fun onLogout() {
        profile.value = null
        stats.value = null
        favorites.value = emptyList()
        history.value = emptyList()
        player = null
    }

    // ── Login ──
    fun signInGoogle(ctx: Context) {
        if (loginBusy.value) return
        viewModelScope.launch {
            loginBusy.value = true
            val r = Graph.auth.signInWithGoogle(ctx)
            r.exceptionOrNull()?.let { messages.tryEmit(it.userMessage()) }
            loginBusy.value = false
        }
    }

    fun logout() {
        viewModelScope.launch {
            Graph.auth.signOut()
            Graph.local.putString("cache_history", null)
            Graph.local.putString("cache_fav", null)
            Graph.local.putString("pending_progress", null)
        }
    }

    // ── Pengaturan ──
    fun setExpPopup(v: Boolean) {
        expPopup.value = v
        viewModelScope.launch { Graph.local.putBool("exp_popup", v) }
    }

    fun setSource(id: String) {
        sourceId.value = id
        viewModelScope.launch { Graph.local.putString("source", id) }
    }

    // ── Profil ──
    suspend fun refreshUser() {
        val s: Session = session.value ?: return
        try {
            val p = Graph.api.profile(s.userId)
            if (p != null) {
                profile.value = UserProfile(
                    id = s.userId,
                    userNo = p.optLong("user_no", 0),
                    username = p.str("username") ?: s.email.substringBefore('@'),
                    email = p.str("email") ?: s.email,
                    avatar = p.str("avatar_url"),
                    level = p.optInt("level", 1),
                    xp = p.optInt("xp", 0),
                    watchSeconds = p.optLong("total_watch_time", 0),
                    premium = p.optBoolean("premium_status", false),
                    premiumExpiredAt = p.str("premium_expired_at"),
                )
            }
            stats.value = Graph.api.stats(s.userId)
        } catch (e: Exception) {
            messages.tryEmit(e.userMessage())
        }
    }

    fun updateUsername(name: String) {
        val s = session.value ?: return
        viewModelScope.launch {
            try {
                Graph.api.setUsername(s.userId, name.trim())
                refreshUser()
            } catch (e: Exception) {
                messages.tryEmit(e.userMessage())
            }
        }
    }

    // ── Favorit ──
    suspend fun refreshFavorites() {
        try {
            val arr = Graph.api.favorites()
            Graph.local.putString("cache_fav", arr.toString())
            favorites.value = parseFavs(arr)
        } catch (e: Exception) {
            val cached = Graph.local.getString("cache_fav")
            if (cached != null && favorites.value.isEmpty()) favorites.value = parseFavs(JSONArray(cached))
        }
    }

    private fun parseFavs(a: JSONArray): List<FavEntry> = (0 until a.length()).mapNotNull { i ->
        a.optJSONObject(i)?.let { o -> FavEntry(o.str("anime_id") ?: return@let null, o.str("anime_title") ?: "", o.str("anime_cover")) }
    }

    fun toggleFavorite(key: String, title: String, cover: String?) {
        viewModelScope.launch {
            val isFav = favorites.value.any { it.animeId == key }
            val before = favorites.value
            favorites.value = if (isFav) before.filter { it.animeId != key } else listOf(FavEntry(key, title, cover)) + before
            try {
                if (isFav) Graph.api.removeFavorite(key) else Graph.api.addFavorite(key, title, cover)
                refreshFavorites()
            } catch (e: Exception) {
                favorites.value = before
                messages.tryEmit(e.userMessage())
            }
        }
    }

    // ── Riwayat ──
    suspend fun refreshHistory() {
        try {
            val arr = Graph.api.history()
            Graph.local.putString("cache_history", arr.toString())
            history.value = parseHistory(arr)
        } catch (e: Exception) {
            val cached = Graph.local.getString("cache_history")
            if (cached != null && history.value.isEmpty()) history.value = parseHistory(JSONArray(cached))
        }
    }

    private fun parseHistory(a: JSONArray): List<HistoryEntry> = (0 until a.length()).mapNotNull { i ->
        a.optJSONObject(i)?.let { o ->
            HistoryEntry(
                id = o.str("id") ?: return@let null,
                animeId = o.str("anime_id") ?: return@let null,
                animeTitle = o.str("anime_title") ?: "",
                animeCover = o.str("anime_cover"),
                episodeId = o.str("episode_id") ?: "",
                episodeTitle = o.str("episode_title") ?: "",
                episodeNumber = o.str("episode_number"),
                lastPosition = o.optLong("last_position", 0),
                duration = o.optLong("duration", 0),
                watchedAt = o.str("watched_at") ?: "",
            )
        }
    }

    fun deleteHistory(e: HistoryEntry) {
        viewModelScope.launch {
            try {
                Graph.api.deleteHistory(e.id)
                history.value = history.value.filter { it.id != e.id }
            } catch (ex: Exception) {
                messages.tryEmit(ex.userMessage())
            }
        }
    }

    fun clearHistory() {
        val s = session.value ?: return
        viewModelScope.launch {
            try {
                Graph.api.clearHistory(s.userId)
                history.value = emptyList()
            } catch (ex: Exception) {
                messages.tryEmit(ex.userMessage())
            }
        }
    }

    // ── Progres tonton + XP (divalidasi server lewat RPC save_progress) ──
    fun reportProgress(detail: AnimeDetail, ep: EpisodeItem, positionSec: Long, durationSec: Long, deltaSec: Int) {
        if (session.value == null) return
        val args = JSONObject()
            .put("p_anime_id", detail.key)
            .put("p_anime_title", detail.title)
            .put("p_anime_cover", detail.cover ?: JSONObject.NULL)
            .put("p_episode_id", "${detail.key}#${ep.id}")
            .put("p_episode_title", ep.title)
            .put("p_episode_number", ep.number ?: JSONObject.NULL)
            .put("p_position", positionSec)
            .put("p_duration", durationSec)
            .put("p_delta", deltaSec)
        Graph.appScope.launch { sendProgress(args) }
    }

    private suspend fun sendProgress(args: JSONObject) {
        try {
            val r = Graph.api.saveProgress(args)
            val awarded = r.optInt("xp_awarded", 0)
            if (awarded > 0) {
                if (expPopup.value) messages.tryEmit("+$awarded XP!")
                refreshUser()
            }
            flushPending()
        } catch (e: IOException) {
            enqueue(args)
        } catch (e: ApiException) {
            if (e.code != 401) messages.tryEmit("Progres: " + e.userMessage())
        }
    }

    private suspend fun enqueue(args: JSONObject) = pendingMutex.withLock {
        val cur = Graph.local.getString("pending_progress")?.let { JSONObject(it) } ?: JSONObject()
        cur.put(args.getString("p_episode_id"), args)
        Graph.local.putString("pending_progress", cur.toString())
    }

    /** Kirim ulang progres yang tertunda saat offline. */
    suspend fun flushPending() = pendingMutex.withLock {
        val raw = Graph.local.getString("pending_progress") ?: return@withLock
        val cur = JSONObject(raw)
        val keys = cur.keys().asSequence().toList()
        for (k in keys) {
            try {
                Graph.api.saveProgress(cur.getJSONObject(k))
                cur.remove(k)
            } catch (e: IOException) {
                break
            } catch (e: ApiException) {
                cur.remove(k)
            }
        }
        Graph.local.putString("pending_progress", if (cur.length() == 0) null else cur.toString())
    }
}
