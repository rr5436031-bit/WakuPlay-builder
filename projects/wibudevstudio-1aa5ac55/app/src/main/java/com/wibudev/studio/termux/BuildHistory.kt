package com.wibudev.studio.termux

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

data class BuildEntry(
    val execId: Int,
    val project: String,
    val type: String,
    val logPath: String,
    val startedAt: Long
)

/** Riwayat build. Status diambil dari CommandRepository berdasarkan execId. */
object BuildHistory {
    private const val PREFS = "wibudev_builds"
    private const val MAX = 100

    private val _entries = MutableStateFlow<List<BuildEntry>>(emptyList())
    val entries: StateFlow<List<BuildEntry>> = _entries.asStateFlow()
    private var prefs: SharedPreferences? = null

    fun ensureLoaded(context: Context) {
        if (prefs != null) return
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs = p
        val arr = JSONArray(p.getString("list", "[]") ?: "[]")
        _entries.value = (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            BuildEntry(
                o.getInt("execId"), o.getString("project"), o.getString("type"),
                o.getString("logPath"), o.getLong("startedAt")
            )
        }
    }

    fun add(entry: BuildEntry) = commit(listOf(entry) + _entries.value)

    fun clear() = commit(emptyList())

    private fun commit(list: List<BuildEntry>) {
        val trimmed = list.take(MAX)
        _entries.value = trimmed
        val arr = JSONArray()
        trimmed.forEach { e ->
            arr.put(
                JSONObject()
                    .put("execId", e.execId)
                    .put("project", e.project)
                    .put("type", e.type)
                    .put("logPath", e.logPath)
                    .put("startedAt", e.startedAt)
            )
        }
        prefs?.edit()?.putString("list", arr.toString())?.apply()
    }
}
