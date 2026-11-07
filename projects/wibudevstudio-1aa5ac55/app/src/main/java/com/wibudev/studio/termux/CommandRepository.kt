package com.wibudev.studio.termux

import android.content.Context
import android.content.SharedPreferences
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject

enum class CommandStatus { WAITING, SUCCESS, FAILED }

data class CommandRecord(
    val id: Int,
    val command: String,
    val workDir: String,
    val status: CommandStatus = CommandStatus.WAITING,
    val stdout: String = "",
    val stderr: String = "",
    val exitCode: Int? = null,
    val message: String? = null
)

/** Riwayat perintah yang disimpan ke SharedPreferences. Terbaru di urutan pertama. */
object CommandRepository {
    private const val PREFS = "wibudev_history"
    private const val KEY_LIST = "list"
    private const val KEY_NEXT = "next_id"
    private const val MAX_ENTRIES = 200

    private val _records = MutableStateFlow<List<CommandRecord>>(emptyList())
    val records: StateFlow<List<CommandRecord>> = _records.asStateFlow()

    private val counter = AtomicInteger(1)
    private var prefs: SharedPreferences? = null

    /** Aman dipanggil berkali-kali; dipanggil juga dari receiver karena proses bisa dimulai oleh broadcast. */
    fun ensureLoaded(context: Context) {
        if (prefs != null) return
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs = p
        counter.set(p.getInt(KEY_NEXT, 1))
        val arr = JSONArray(p.getString(KEY_LIST, "[]") ?: "[]")
        _records.value = (0 until arr.length()).map { fromJson(arr.getJSONObject(it)) }
    }

    fun submit(command: String, workDir: String): Int {
        val id = counter.getAndIncrement()
        commit(listOf(CommandRecord(id, command, workDir)) + _records.value)
        return id
    }

    fun complete(id: Int, stdout: String, stderr: String, exitCode: Int) = patch(id) {
        it.copy(
            status = if (exitCode == 0) CommandStatus.SUCCESS else CommandStatus.FAILED,
            stdout = stdout,
            stderr = stderr,
            exitCode = exitCode
        )
    }

    fun fail(id: Int, message: String) = patch(id) {
        it.copy(status = CommandStatus.FAILED, message = message)
    }

    fun requestStop(id: Int) = patch(id) { it.copy(message = "Permintaan berhenti dikirim...") }

    fun clear() = commit(emptyList())

    private fun patch(id: Int, transform: (CommandRecord) -> CommandRecord) {
        commit(_records.value.map { if (it.id == id) transform(it) else it })
    }

    private fun commit(list: List<CommandRecord>) {
        val trimmed = list.take(MAX_ENTRIES)
        _records.value = trimmed
        val arr = JSONArray()
        trimmed.forEach { arr.put(toJson(it)) }
        prefs?.edit()?.putString(KEY_LIST, arr.toString())?.putInt(KEY_NEXT, counter.get())?.apply()
    }

    private fun toJson(r: CommandRecord): JSONObject = JSONObject().apply {
        put("id", r.id)
        put("command", r.command)
        put("workDir", r.workDir)
        put("status", r.status.name)
        put("stdout", r.stdout)
        put("stderr", r.stderr)
        put("exitCode", r.exitCode ?: JSONObject.NULL)
        put("message", r.message ?: JSONObject.NULL)
    }

    private fun fromJson(o: JSONObject) = CommandRecord(
        id = o.getInt("id"),
        command = o.getString("command"),
        workDir = o.getString("workDir"),
        status = CommandStatus.valueOf(o.getString("status")),
        stdout = o.getString("stdout"),
        stderr = o.getString("stderr"),
        exitCode = if (o.isNull("exitCode")) null else o.getInt("exitCode"),
        message = if (o.isNull("message")) null else o.getString("message")
    )
}
