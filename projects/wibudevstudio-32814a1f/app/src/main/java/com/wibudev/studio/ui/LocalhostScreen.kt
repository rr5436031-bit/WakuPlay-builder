package com.wibudev.studio.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
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
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.wibudev.studio.termux.CommandRepository
import com.wibudev.studio.termux.CommandRunner
import com.wibudev.studio.termux.CommandStatus

/**
 * Mengelola server dev (npm run dev) di 127.0.0.1. Proses berjalan di Termux dengan nohup,
 * jadi tetap hidup walau aplikasi ditutup. PID dan log disimpan di ~/.wibudev/logs.
 */
@Composable
fun LocalhostScreen(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val records by CommandRepository.records.collectAsState()
    var project by remember { mutableStateOf("") }
    var portText by remember { mutableStateOf("5173") }
    var lastId by remember { mutableStateOf<Int?>(null) }
    var lastLabel by remember { mutableStateOf("") }

    val segments = Shell.validSegments(project)
    val port = portText.toIntOrNull()?.takeIf { it in 1024..65535 }
    val ready = segments != null && segments.isNotEmpty() && port != null
    val p = port ?: 5173
    val dir = Shell.pathOf(segments ?: emptyList())
    val pidFile = "\$HOME/.wibudev/logs/$p.pid"
    val logFile = "\$HOME/.wibudev/logs/$p.log"

    val startCmd = "mkdir -p \$HOME/.wibudev/logs; cd $dir || exit 1; " +
        "nohup npm run dev -- --host 127.0.0.1 --port $p >$logFile 2>&1 & " +
        "echo \$! > $pidFile; echo started $p"
    val stopCmd = "if [ -f $pidFile ]; then kill -TERM \$(cat $pidFile) 2>/dev/null; " +
        "rm -f $pidFile; echo stopped; else echo tidak_berjalan; fi"
    val statusCmd = "if [ -f $pidFile ] && kill -0 \$(cat $pidFile) 2>/dev/null; then echo running; " +
        "curl -s -o /dev/null -w 'HTTP %{http_code}' http://127.0.0.1:$p 2>/dev/null; echo; " +
        "else echo stopped; fi"
    val logCmd = "tail -n 80 $logFile 2>/dev/null || echo 'belum ada log'"

    fun run(label: String, cmd: String) {
        lastLabel = label
        lastId = CommandRunner.execute(context, cmd)
    }

    val rec = records.firstOrNull { it.id == lastId }

    Column(
        modifier = modifier.fillMaxSize().padding(12.dp).verticalScroll(rememberScrollState()),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        OutlinedTextField(
            value = project,
            onValueChange = { project = it },
            label = { Text("Folder proyek di ~/projects, mis. my-vite-app") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = portText,
            onValueChange = { portText = it.filter { c -> c.isDigit() }.take(5) },
            label = { Text("Port (1024–65535)") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth()
        )

        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Button(enabled = ready, onClick = { run("Install dependencies", "cd $dir && npm install") }) {
                Text("Install deps")
            }
            OutlinedButton(enabled = ready, onClick = { run("Start", startCmd) }) { Text("Start") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton(enabled = ready, onClick = { run("Restart", "$stopCmd; sleep 1; $startCmd") }) {
                Text("Restart")
            }
            OutlinedButton(enabled = ready, onClick = { run("Stop", stopCmd) }) { Text("Stop") }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            OutlinedButton(enabled = ready, onClick = { run("Status", statusCmd) }) { Text("Cek status") }
            OutlinedButton(enabled = ready, onClick = { run("Log", logCmd) }) { Text("Log") }
        }
        OutlinedButton(
            enabled = ready,
            onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("http://127.0.0.1:$p")))
            }
        ) { Text("Buka preview di browser") }

        rec?.let { r ->
            Text(lastLabel, style = MaterialTheme.typography.titleSmall)
            when (r.status) {
                CommandStatus.WAITING -> Text("Menunggu hasil...")
                CommandStatus.SUCCESS -> Text(
                    r.stdout.ifBlank { "(kosong)" },
                    fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodySmall
                )
                CommandStatus.FAILED -> Text(
                    (r.message ?: r.stderr).ifBlank { "Gagal" },
                    color = MaterialTheme.colorScheme.error
                )
            }
        }
    }
}
