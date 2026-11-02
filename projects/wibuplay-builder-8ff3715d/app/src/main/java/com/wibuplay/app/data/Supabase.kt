package com.wibuplay.app.data

import android.content.Context
import android.net.Uri
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.security.MessageDigest
import java.util.UUID

data class Session(
    val accessToken: String,
    val refreshToken: String,
    val expiresAt: Long,
    val userId: String,
    val email: String,
)

/**
 * Supabase Auth (GoTrue) dengan login Google native (Credential Manager + id_token).
 * Memerlukan OAuth client Android (package + SHA-1) dan Web client ID di Google Cloud.
 */
class SupabaseAuth(private val local: LocalStore) {
    private val _session = MutableStateFlow<Session?>(null)
    val session: StateFlow<Session?> = _session
    private val mutex = Mutex()

    suspend fun restore() {
        val access = local.getString("sb_access")
        val refresh = local.getString("sb_refresh")
        val uid = local.getString("sb_uid")
        if (access == null || refresh == null || uid == null) return
        _session.value = Session(
            access, refresh,
            local.getString("sb_exp")?.toLongOrNull() ?: 0L,
            uid, local.getString("sb_email") ?: "",
        )
        // Pastikan token masih valid (refresh bila perlu). Gagal total => session dihapus.
        validToken()
    }

    @Volatile
    private var cachedClientId: String? = null

    /** Web Client ID Google disimpan sebagai secret Edge Function (app-config), bukan di APK. */
    private suspend fun googleClientId(): String {
        cachedClientId?.let { return it }
        val text = httpGetText(
            AppConfig.FUNCTIONS_URL + "/app-config",
            mapOf("apikey" to AppConfig.SUPABASE_KEY),
        )
        val id = JSONObject(text).str("google_web_client_id")
            ?: throw ApiException(0, "Edge Function app-config belum mengembalikan google_web_client_id")
        cachedClientId = id
        return id
    }

    /** Popup "Pilih akun" Google (Credential Manager) lalu tukar ID token ke sesi Supabase. */
    suspend fun signInWithGoogle(ctx: Context): Result<Unit> {
        return try {
            val clientId = googleClientId()
            val rawNonce = UUID.randomUUID().toString()
            val hashed = MessageDigest.getInstance("SHA-256").digest(rawNonce.toByteArray())
                .joinToString("") { "%02x".format(it) }
            val option = GetGoogleIdOption.Builder()
                .setFilterByAuthorizedAccounts(false)
                .setServerClientId(clientId)
                .setNonce(hashed)
                .setAutoSelectEnabled(false)
                .build()
            val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
            val result = CredentialManager.create(ctx).getCredential(ctx, request)
            val cred = result.credential
            if (cred !is CustomCredential || cred.type != GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                return Result.failure(ApiException(0, "Jenis kredensial tidak didukung"))
            }
            val idToken = GoogleIdTokenCredential.createFrom(cred.data).idToken
            val body = JSONObject().put("provider", "google").put("id_token", idToken).put("nonce", rawNonce)
            store(postJson("/auth/v1/token?grant_type=id_token", body))
            Result.success(Unit)
        } catch (e: GetCredentialCancellationException) {
            Result.failure(ApiException(0, "Login dibatalkan"))
        } catch (e: NoCredentialException) {
            Result.failure(ApiException(0, "Tidak ada akun Google yang bisa dipakai. Tambahkan akun Google di HP, atau periksa SHA-1 & Client ID."))
        } catch (e: GetCredentialException) {
            Result.failure(ApiException(0, "Login Google gagal: " + (e.message ?: e.type)))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /** Access token yang masih berlaku, atau null bila belum login / sesi kedaluwarsa. */
    suspend fun validToken(): String? = mutex.withLock {
        val s = _session.value ?: return null
        if (s.expiresAt - 60 > nowSec()) return s.accessToken
        return refresh(s)
    }

    private suspend fun refresh(s: Session): String? {
        return try {
            val json = postJson(
                "/auth/v1/token?grant_type=refresh_token",
                JSONObject().put("refresh_token", s.refreshToken),
            )
            store(json)
            _session.value?.accessToken
        } catch (e: ApiException) {
            if (e.code in listOf(400, 401, 403)) {
                clear() // refresh token ditolak => sesi kedaluwarsa
                null
            } else s.accessToken
        } catch (e: IOException) {
            s.accessToken // offline: pertahankan sesi
        }
    }

    suspend fun signOut() {
        val s = _session.value
        if (s != null) {
            try {
                val req = Request.Builder().url(AppConfig.SUPABASE_URL + "/auth/v1/logout")
                    .header("apikey", AppConfig.SUPABASE_KEY)
                    .header("Authorization", "Bearer ${s.accessToken}")
                    .post("".toRequestBody(Http.JSON)).build()
                Http.client.newCall(req).await().close()
            } catch (_: Exception) {
            }
        }
        clear()
    }

    private suspend fun clear() {
        _session.value = null
        for (k in listOf("sb_access", "sb_refresh", "sb_exp", "sb_uid", "sb_email")) local.putString(k, null)
    }

    private suspend fun store(json: JSONObject) {
        val access = json.getString("access_token")
        val refresh = json.getString("refresh_token")
        val exp = if (json.has("expires_at")) json.optLong("expires_at") else nowSec() + json.optLong("expires_in", 3600L)
        val user = json.optJSONObject("user")
        val uid = user?.str("id") ?: _session.value?.userId.orEmpty()
        val email = user?.str("email") ?: _session.value?.email.orEmpty()
        if (uid.isEmpty()) throw ApiException(0, "Respons autentikasi tidak memuat ID pengguna")
        local.putString("sb_access", access)
        local.putString("sb_refresh", refresh)
        local.putString("sb_exp", exp.toString())
        local.putString("sb_uid", uid)
        local.putString("sb_email", email)
        _session.value = Session(access, refresh, exp, uid, email)
    }

    private suspend fun postJson(path: String, body: JSONObject): JSONObject {
        val req = Request.Builder().url(AppConfig.SUPABASE_URL + path)
            .header("apikey", AppConfig.SUPABASE_KEY)
            .post(body.toString().toRequestBody(Http.JSON)).build()
        return readJson(req)
    }

    private suspend fun readJson(req: Request): JSONObject {
        Http.client.newCall(req).await().use { r ->
            val text = r.body?.string() ?: ""
            if (!r.isSuccessful) throw ApiException(r.code, errorMessage(text, r.code))
            return JSONObject(text)
        }
    }
}

fun errorMessage(text: String, code: Int): String {
    return try {
        val j = JSONObject(text)
        j.str("msg") ?: j.str("message") ?: j.str("error_description") ?: j.str("error") ?: "Kesalahan server ($code)"
    } catch (e: Exception) {
        "Kesalahan server ($code)"
    }
}

/** Akses tabel/RPC Supabase. Semua data dibatasi RLS di sisi server. */
class SupabaseApi(private val auth: SupabaseAuth) {

    private suspend fun call(method: String, path: String, body: String? = null, prefer: String? = null): String {
        val token = auth.validToken() ?: throw ApiException(401, "Sesi berakhir, silakan login lagi")
        val needsBody = method == "POST" || method == "PATCH" || method == "PUT"
        val rb = if (needsBody) (body ?: "").toRequestBody(Http.JSON) else null
        val b = Request.Builder().url(AppConfig.SUPABASE_URL + path)
            .header("apikey", AppConfig.SUPABASE_KEY)
            .header("Authorization", "Bearer $token")
            .header("Accept", "application/json")
        if (prefer != null) b.header("Prefer", prefer)
        b.method(method, rb)
        Http.client.newCall(b.build()).await().use { r ->
            val text = r.body?.string() ?: ""
            if (!r.isSuccessful) throw ApiException(r.code, errorMessage(text, r.code))
            return text
        }
    }

    private suspend fun rpc(name: String, args: String = "{}"): String = call("POST", "/rest/v1/rpc/$name", args)

    private fun enc(s: String) = Uri.encode(s)

    suspend fun ensureProfile() {
        rpc("ensure_profile")
    }

    suspend fun profile(uid: String): JSONObject? =
        JSONArray(call("GET", "/rest/v1/profiles?id=eq.${enc(uid)}&select=*")).optJSONObject(0)

    suspend fun stats(uid: String): JSONObject? =
        JSONArray(call("GET", "/rest/v1/user_stats?user_id=eq.${enc(uid)}&select=*")).optJSONObject(0)

    suspend fun setUsername(uid: String, name: String) {
        call("PATCH", "/rest/v1/profiles?id=eq.${enc(uid)}", JSONObject().put("username", name).toString(), "return=minimal")
    }

    suspend fun history(): JSONArray =
        JSONArray(call("GET", "/rest/v1/watch_history?select=*&order=watched_at.desc&limit=200"))

    suspend fun deleteHistory(id: String) {
        call("DELETE", "/rest/v1/watch_history?id=eq.${enc(id)}")
    }

    suspend fun clearHistory(uid: String) {
        call("DELETE", "/rest/v1/watch_history?user_id=eq.${enc(uid)}")
    }

    /** XP dan statistik dihitung di server (fungsi save_progress). */
    suspend fun saveProgress(args: JSONObject): JSONObject = JSONObject(rpc("save_progress", args.toString()))

    suspend fun favorites(): JSONArray =
        JSONArray(call("GET", "/rest/v1/favorites?select=*&order=created_at.desc&limit=500"))

    suspend fun addFavorite(animeId: String, title: String, cover: String?) {
        val body = JSONObject().put("anime_id", animeId).put("anime_title", title)
        if (cover != null) body.put("anime_cover", cover)
        call("POST", "/rest/v1/favorites?on_conflict=user_id,anime_id", body.toString(), "resolution=ignore-duplicates,return=minimal")
    }

    suspend fun removeFavorite(animeId: String) {
        call("DELETE", "/rest/v1/favorites?anime_id=eq.${enc(animeId)}")
    }

    suspend fun xpEvents(): JSONArray =
        JSONArray(call("GET", "/rest/v1/xp_events?select=*&order=created_at.desc&limit=30"))

    suspend fun premiumPackages(): JSONArray =
        JSONArray(call("GET", "/rest/v1/premium_packages?select=*&is_active=eq.true&order=sort_order.asc"))

    /** Token sekali pakai (2 menit) untuk dibaca backend website. Null bila fungsi belum dipasang. */
    suspend fun createWebHandoff(): String? = try {
        rpc("create_web_handoff").trim().trim('"').ifEmpty { null }
    } catch (e: ApiException) {
        null
    }

    // ── Chat global ──
    suspend fun chatMessages(channel: Int, afterId: Long?): JSONArray {
        val q = if (afterId == null) "&order=id.desc&limit=50" else "&id=gt.$afterId&order=id.asc&limit=100"
        return JSONArray(call("GET", "/rest/v1/chat_messages?select=*&channel=eq.$channel$q"))
    }

    suspend fun sendChat(channel: Int, content: String, replyTo: Long?): JSONObject {
        val args = JSONObject().put("p_channel", channel).put("p_content", content)
        if (replyTo != null) args.put("p_reply_to", replyTo)
        return JSONObject(rpc("send_chat", args.toString()))
    }
}
