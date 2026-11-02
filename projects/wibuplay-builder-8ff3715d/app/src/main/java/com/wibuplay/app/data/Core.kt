package com.wibuplay.app.data

import android.app.Application
import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.Call
import okhttp3.Callback
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

/** Konfigurasi terpusat. Jangan pernah menaruh Service Role Key di sini. */
object AppConfig {
    const val SUPABASE_URL = "https://fdbwrqmtewoymugfssjk.supabase.co"
    const val SUPABASE_KEY = "sb_publishable_bx9-9nIaMoiLLiqsgWlMVw_RR9BmkPQ"
    const val FUNCTIONS_URL = SUPABASE_URL + "/functions/v1"
    const val PREMIUM_URL = "https://wibuplay.vercel.app/premium"
    const val APP_VERSION = "1.0.0"
}

/** Singleton sederhana (tanpa DI framework agar ringan). */
object Graph {
    lateinit var app: Application
    val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    lateinit var local: LocalStore
    lateinit var auth: SupabaseAuth
    lateinit var api: SupabaseApi
    lateinit var anime: AnimeRepository

    fun init(application: Application) {
        app = application
        local = LocalStore(application)
        auth = SupabaseAuth(local)
        api = SupabaseApi(auth)
        anime = AnimeRepository()
    }
}

private val Context.wpStore: DataStore<Preferences> by preferencesDataStore(name = "wibuplay")

class LocalStore(private val ctx: Context) {
    suspend fun getString(name: String): String? = ctx.wpStore.data.first()[stringPreferencesKey(name)]

    suspend fun putString(name: String, value: String?) {
        ctx.wpStore.edit {
            if (value == null) it.remove(stringPreferencesKey(name)) else it[stringPreferencesKey(name)] = value
        }
    }

    suspend fun getBool(name: String, def: Boolean): Boolean =
        ctx.wpStore.data.first()[booleanPreferencesKey(name)] ?: def

    suspend fun putBool(name: String, value: Boolean) {
        ctx.wpStore.edit { it[booleanPreferencesKey(name)] = value }
    }
}

object Http {
    val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .callTimeout(45, TimeUnit.SECONDS)
        .build()
    val JSON = "application/json; charset=utf-8".toMediaType()
}

class ApiException(val code: Int, message: String) : Exception(message)

suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    cont.invokeOnCancellation { cancel() }
    enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {
            if (cont.isActive) cont.resumeWithException(e)
        }

        override fun onResponse(call: Call, response: Response) {
            cont.resume(response)
        }
    })
}

/** GET teks. Melempar ApiException bila status bukan 2xx. */
suspend fun httpGetText(url: String, headers: Map<String, String> = emptyMap()): String {
    val rb = Request.Builder().url(url)
        .header("User-Agent", "WibuPlay/${AppConfig.APP_VERSION} (Android)")
        .header("Accept", "application/json")
    for ((k, v) in headers) rb.header(k, v)
    val req = rb.build()
    Http.client.newCall(req).await().use { r ->
        val body = withContext(Dispatchers.IO) { r.body?.string() ?: "" }
        if (!r.isSuccessful) throw ApiException(r.code, "Server mengembalikan kode ${r.code}")
        return body
    }
}

fun Throwable.userMessage(): String = when (this) {
    is UnknownHostException, is ConnectException, is SocketTimeoutException ->
        "Tidak ada koneksi internet atau server tidak merespons"
    is ApiException -> message ?: "Terjadi kesalahan ($code)"
    else -> message ?: "Terjadi kesalahan"
}

fun nowSec(): Long = System.currentTimeMillis() / 1000

/** optString() milik org.json mengembalikan "null" untuk nilai null; helper ini mengembalikan null sungguhan. */
fun org.json.JSONObject.str(key: String): String? =
    if (isNull(key)) null else optString(key).ifEmpty { null }
