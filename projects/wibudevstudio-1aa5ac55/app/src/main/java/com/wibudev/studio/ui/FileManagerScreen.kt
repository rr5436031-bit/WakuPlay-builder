package com.wibudev.studio.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.CommandStatus

private enum class FileDialog { NEW_FOLDER, NEW_FILE, RENAME, COPY, IMPORT, DELETE }

private fun dialogTitle(kind: FileDialog, sel: String): String = when (kind) {
    FileDialog.NEW_FOLDER -> "Folder baru"
    FileDialog.NEW_FILE -> "File baru"
    FileDialog.RENAME -> "Ganti nama $sel"
    FileDialog.COPY -> "Salin $sel ke (relatif dari ~/projects)"
    FileDialog.IMPORT -> "Nama ZIP di ~/storage/downloads"
    FileDialog.DELETE -> "Hapus?"
}

/** Setiap operasi dijalankan lewat Termux. Daftar folder diambil dari hasil perintah ls. */
@Composable
fun FileManagerScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    var path by remember { mutableStateOf(emptyList<String>()) }
    var listId by remember { mutableStateOf<Int?>(null) }
    var opId by remember { mutableStateOf<Int?>(null) }
    var selected by remember { mutableStateOf<String?>(null) }
    var dialog by remember { mutableStateOf<FileDialog?>(null) }
    var input by remember { mutableStateOf("") }
    var notice by remember { mutableStateOf("") }

    fun reload() {
        listId = CommandRunner.execute(
            context, "mkdir -p ${Shell.ROOT} && cd ${Shell.pathOf(path)} && ls -1Ap"
        )
        selected = null
    }

    fun commandFor(kind: FileDialog): String? {
        val sel = selected.orEmpty()
        val name = input.trim()
        val here = path
        return when (kind) {
            FileDialog.NEW_FOLDER ->
                if (Shell.validName(name)) "mkdir -p -- ${Shell.pathOf(here + name)}" else null
            FileDialog.NEW_FILE ->
                if (Shell.validName(name)) "touch -- ${Shell.pathOf(here + name)}" else null
            FileDialog.RENAME ->
                if (Shell.validName(name)) "mv -- ${Shell.pathOf(here + sel)} ${Shell.pathOf(here + name)}" else null
            FileDialog.COPY ->
                Shell.validSegments(name)?.let { "cp -r -- ${Shell.pathOf(here + sel)} ${Shell.pathOf(it)}" }
            FileDialog.IMPORT ->
                if (Shell.validName(name))
                    "unzip -o -q \"\$HOME/storage/downloads/\"${Shell.quote(name)} -d ${Shell.pathOf(here)}"
                else null
            FileDialog.DELETE -> "rm -rf -- ${Shell.pathOf(here + sel)}"
        }
    }

    LaunchedEffect(path) { reload() }

    val opRec = records.firstOrNull { it.id == opId }
    LaunchedEffect(opRec?.status) {
        if (opRec != null && opRec.status != CommandStatus.WAITING) reload()
    }

    val listRec = records.firstOrNull { it.id == listId }
    val entries: List<String> = listRec?.takeIf { it.status == CommandStatus.SUCCESS }
        ?.stdout?.lines()?.filter { it.isNotBlank() } ?: emptyList()
    val listError = listRec?.takeIf { it.status == CommandStatus.FAILED }?.let { it.message ?: it.stderr }
    val opMessage = opRec?.let { r ->
        when (r.status) {
            CommandStatus.WAITING -> "Berjalan..."
            CommandStatus.SUCCESS -> "Berhasil."
            CommandStatus.FAILED -> "Gagal: " + (r.message ?: r.stderr)
        }
    }

    Column(
        modifier = modifier.fillMaxSize().padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text("~/projects" + path.joinToString("") { "/$it" }, fontFamily = FontFamily.Monospace)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton(onClick = { path = path.dropLast(1) }, enabled = path.isNotEmpty()) { Text("Atas") }
            OutlinedButton(onClick = { dialog = FileDialog.NEW_FOLDER; input = "" }) { Text("Folder baru") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton(onClick = { dialog = FileDialog.NEW_FILE; input = "" }) { Text("File baru") }
            OutlinedButton(onClick = { dialog = FileDialog.IMPORT; input = "" }) { Text("Import ZIP") }
        }

        listError?.let { Text(it, color = MaterialTheme.colorScheme.error) }
        opMessage?.let { Text(it, color = MaterialTheme.colorScheme.onSurfaceVariant) }
        if (notice.isNotEmpty()) Text(notice, color = MaterialTheme.colorScheme.error)

        LazyColumn(modifier = Modifier.fillMaxWidth().weight(1f)) {
            items(entries) { name ->
                val isDir = name.endsWith("/")
                val label = name.removeSuffix("/")
                Text(
                    (if (isDir) "📁 " else "📄 ") + label,
                    fontFamily = FontFamily.Monospace,
                    color = if (selected == label) MaterialTheme.colorScheme.primary
                    else MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.fillMaxWidth().clickable { selected = label }.padding(vertical = 10.dp)
                )
            }
        }

        selected?.let { sel ->
            val isDir = entries.any { it == "$sel/" }
            Text("Dipilih: $sel", fontFamily = FontFamily.Monospace)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                if (isDir) OutlinedButton(onClick = { path = path + sel }) { Text("Buka") }
                OutlinedButton(onClick = { dialog = FileDialog.RENAME; input = sel }) { Text("Ganti nama") }
                OutlinedButton(onClick = { dialog = FileDialog.COPY; input = "" }) { Text("Salin") }
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                OutlinedButton(onClick = { dialog = FileDialog.DELETE }) { Text("Hapus") }
                if (isDir) {
                    OutlinedButton(onClick = {
                        opId = CommandRunner.execute(
                            context,
                            "cd ${Shell.pathOf(path)} && zip -r -q \"\$HOME/storage/downloads/\"" +
                                "${Shell.quote("$sel.zip")} ${Shell.quote(sel)}"
                        )
                    }) { Text("Export ZIP") }
                }
            }
        }
    }

    dialog?.let { kind ->
        AlertDialog(
            onDismissRequest = { dialog = null },
            title = { Text(dialogTitle(kind, selected.orEmpty())) },
            text = {
                if (kind == FileDialog.DELETE) {
                    Text("Hapus ${selected.orEmpty()} secara permanen?")
                } else {
                    OutlinedTextField(value = input, onValueChange = { input = it }, singleLine = true)
                }
            },
            confirmButton = {
                Button(onClick = {
                    val cmd = commandFor(kind)
                    if (cmd == null) {
                        notice = "Nama atau path tidak valid."
                    } else {
                        notice = ""
                        opId = CommandRunner.execute(context, cmd)
                    }
                    if (cmd != null) dialog = null
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { dialog = null }) { Text("Batal") } }
        )
    }
}
