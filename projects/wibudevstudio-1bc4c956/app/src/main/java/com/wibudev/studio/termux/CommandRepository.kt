package com.wibudev.studio.termux

import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

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

/** Riwayat perintah. Status hanya berubah ke SUCCESS/FAILED setelah Termux mengirim hasil. */
object CommandRepository {
    private val _records = MutableStateFlow<List<CommandRecord>>(emptyList())
    val records: StateFlow<List<CommandRecord>> = _records.asStateFlow()

    private val counter = AtomicInteger(1)

    /** Terbaru di urutan pertama. */
    fun submit(command: String, workDir: String): Int {
        val id = counter.getAndIncrement()
        _records.update { listOf(CommandRecord(id, command, workDir)) + it }
        return id
    }

    fun complete(id: Int, stdout: String, stderr: String, exitCode: Int) {
        patch(id) {
            it.copy(
                status = if (exitCode == 0) CommandStatus.SUCCESS else CommandStatus.FAILED,
                stdout = stdout,
                stderr = stderr,
                exitCode = exitCode
            )
        }
    }

    fun fail(id: Int, message: String) {
        patch(id) { it.copy(status = CommandStatus.FAILED, message = message) }
    }

    fun clear() {
        _records.value = emptyList()
    }

    private fun patch(id: Int, transform: (CommandRecord) -> CommandRecord) {
        _records.update { list -> list.map { if (it.id == id) transform(it) else it } }
    }
}
