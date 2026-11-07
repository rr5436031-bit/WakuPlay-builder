package com.wibudev.studio.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.BuildEntry
import com.wibudev.studio.termux.BuildHistory
import com.wibudev.studio.termux.CommandRecord
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.CommandStatus

/**
 * Build Gradle lewat Termux. Log ditulis dengan tee sehingga "Lihat log" menampilkan
 * progres terkini selama build masih berjalan. APK disalin ke ~/storage/downloads.
 */
@Composable
fun BuildScreen(modifier: Modifier = Modifier, historyOnly: Boolean = false) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    val entries by BuildHistory.entries.collectAsState()
    var project by remember { mutableStateOf("") }
    var release by remember { mutableStateOf(false) }
    var logId by remember { mutableStateOf<Int?>(null) }

    val segments = Shell.validSegments(project)
    val ready = segments != null && segments.isNotEmpty()
    val dir = Shell.pathOf(segments ?: emptyList())

    fun startBuild() {
        val ts = System.currentTimeMillis()
        val logPath = "\$HOME/.wibudev/builds/$ts.log"
        val task = if (release) "assembleRelease" else "assembleDebug"
        val filter = if (release) "release" else "debug"
        val id = CommandRunner.execute(context, buildCommand(dir, task, filter, logPath))
        BuildHistory.add(
            BuildEntry(id, project.trim(), if (release) "Release" else "Debug", logPath, ts)
        )
    }

    Column(
        modifier = modifier.fillMaxSize().padding(12.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (!historyOnly) {
            Text(
                "Build proyek Gradle/Android di ~/projects. Termux harus memiliki JDK dan Android SDK.",
                style = MaterialTheme.typography.bodySmall
            )
            OutlinedTextField(
                value = project,
                onValueChange = { project = it },
                label = { Text("Folder proyek, mis. my-android-app") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = !release, onClick = { release = false }, label = { Text("Debug") })
                FilterChip(selected = release, onClick = { release = true }, label = { Text("Release") })
            }
            if (release) {
                Text(
                    "Release dibangun tanpa signing. Keystore dan password tidak disimpan di aplikasi.",
                    style = MaterialTheme.typography.bodySmall
                )
            }
            Button(enabled = ready, onClick = { startBuild() }) { Text("Build APK") }
        }

        Text("Riwayat build", style = MaterialTheme.typography.titleMedium)
        OutlinedButton(onClick = { BuildHistory.clear() }, enabled = entries.isNotEmpty()) {
            Text("Hapus riwayat")
        }

        entries.forEach { e ->
            val rec = records.firstOrNull { it.id == e.execId }
            val apk = rec?.stdout?.lines()?.firstOrNull { it.startsWith("APK=") }?.removePrefix("APK=")
            Column(modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                Text("${e.project} · ${e.type}", style = MaterialTheme.typography.titleSmall)
                Text(statusLine(rec))
                apk?.let { Text(it, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall) }
                OutlinedButton(onClick = {
                    logId = CommandRunner.execute(
                        context, "tail -n 80 ${e.logPath} 2>/dev/null || echo 'log tidak ditemukan'"
                    )
                }) { Text("Lihat log") }
            }
        }

        logId?.let { id ->
            records.firstOrNull { it.id == id }?.let { r ->
                val text = when (r.status) {
                    CommandStatus.WAITING -> "Menunggu..."
                    else -> r.stdout.ifBlank { r.message ?: r.stderr }.ifBlank { "(kosong)" }
                }
                Text(text, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

private fun statusLine(rec: CommandRecord?): String = when {
    rec == null -> "Tidak ditemukan di riwayat perintah"
    rec.status == CommandStatus.WAITING -> "Berjalan..."
    rec.status == CommandStatus.SUCCESS -> "Berhasil"
    else -> "Gagal" + (rec.exitCode?.let { " (exit $it)" } ?: "") + (rec.message?.let { ": $it" } ?: "")
}

/**
 * Perintah build: gunakan ./gradlew jika ada, jika tidak gunakan gradle.
 * Exit 0 hanya jika APK ditemukan dan berhasil disalin, sehingga tidak ada klaim palsu.
 */
private fun buildCommand(dir: String, task: String, apkFilter: String, logPath: String): String =
    "mkdir -p \$HOME/.wibudev/builds; cd $dir || exit 1; " +
        "if [ -x ./gradlew ]; then G=./gradlew; " +
        "elif command -v gradle >/dev/null 2>&1; then G=gradle; " +
        "else echo 'gradle tidak ditemukan' | tee $logPath; exit 1; fi; " +
        "set -o pipefail; \$G $task --stacktrace 2>&1 | tee $logPath || exit 1; " +
        "APK=\$(find app/build/outputs/apk -name '*.apk' 2>/dev/null | grep $apkFilter | head -n 1); " +
        "if [ -z \"\$APK\" ]; then echo 'APK tidak ditemukan' | tee -a $logPath; exit 1; fi; " +
        "mkdir -p \$HOME/storage/downloads 2>/dev/null; " +
        "cp \"\$APK\" \$HOME/storage/downloads/ || { echo 'Gagal menyalin ke Downloads. Jalankan termux-setup-storage.'; exit 1; }; " +
        "echo \"APK=\$APK\""
